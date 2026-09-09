import re
import httpx
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.scripture import Translation, Verse, OriginalWord, MorphCode
from app.schemas.scripture import ChapterOut, VerseOut, OriginalWordOut, TranslationOut
from app.core.book_names import BOOK_MAP

router = APIRouter(prefix="", tags=["Reader"])

BOOK_CODE_TO_BOLLS_NUM = {
    'GEN': 1, 'EXO': 2, 'LEV': 3, 'NUM': 4, 'DEU': 5,
    'JOS': 6, 'JDG': 7, 'RUT': 8, '1SA': 9, '2SA': 10,
    '1KI': 11, '2KI': 12, '1CH': 13, '2CH': 14, 'EZR': 15,
    'NEH': 16, 'EST': 17, 'JOB': 18, 'PSA': 19, 'PRO': 20,
    'ECC': 21, 'SNG': 22, 'ISA': 23, 'JER': 24, 'LAM': 25,
    'EZK': 26, 'DAN': 27, 'HOS': 28, 'JOL': 29, 'AMO': 30,
    'OBA': 31, 'JON': 32, 'MIC': 33, 'NAM': 34, 'HAB': 35,
    'ZEP': 36, 'HAG': 37, 'ZEC': 38, 'MAL': 39,
    'MAT': 40, 'MRK': 41, 'LUK': 42, 'JHN': 43, 'ACT': 44,
    'ROM': 45, '1CO': 46, '2CO': 47, 'GAL': 48, 'EPH': 49,
    'PHP': 50, 'COL': 51, '1TH': 52, '2TH': 53, '1TI': 54,
    '2TI': 55, 'TIT': 56, 'PHM': 57, 'HEB': 58, 'JAS': 59,
    '1PE': 60, '2PE': 61, '1JN': 62, '2JN': 63, '3JN': 64,
    'JUD': 65, 'REV': 66,
}

MODERN_TRANSLATION_MAP = {
    'esv': ('ESV', 'English Standard Version', 'ESV'),
    'niv': ('NIV', 'New International Version', 'NIV'),
    'nlt': ('NLT', 'New Living Translation', 'NLT'),
    'nkjv': ('NKJV', 'New King James Version', 'NKJV'),
    'amp': ('AMP', 'Amplified Bible', 'AMP'),
    'msg': ('MSG', 'The Message', 'MSG'),
    'gnt': ('GNT', 'Good News Translation', 'GNT'),
    'cev': ('CEVD', 'Contemporary English Version', 'CEV'),
    'nasb': ('NASB', 'New American Standard Bible', 'NASB'),
    'bsb': ('BSB', 'Berean Standard Bible', 'BSB'),
}


@router.get("/translations", response_model=List[TranslationOut])
async def list_translations(db: AsyncSession = Depends(get_db)):
    """List all available Bible translations."""
    stmt = select(Translation).order_by(Translation.abbreviation)
    result = await db.execute(stmt)
    translations = list(result.scalars().all())

    # Include modern translations in listing
    existing_ids = {t.id.lower() for t in translations}
    for tid, (bolls_id, name, abbr) in MODERN_TRANSLATION_MAP.items():
        if tid not in existing_ids:
            translations.append(TranslationOut(
                id=tid,
                name=name,
                abbreviation=abbr,
                language="en",
                license="Fair Use / Developer API",
            ))

    return translations


@router.get("/reader/{translation_id}/{book_code}/{chapter}", response_model=ChapterOut)
async def get_chapter(
    translation_id: str,
    book_code: str,
    chapter: int,
    db: AsyncSession = Depends(get_db),
):
    """
    Get full chapter text with aligned original-language tokens (Hebrew/Greek),
    Strong's numbers, transliterations, and grammatical morphology.
    """
    translation_id = translation_id.lower()
    book_code = book_code.upper()

    # 1. Fetch translation from DB
    trans_stmt = select(Translation).where(Translation.id == translation_id)
    trans_res = await db.execute(trans_stmt)
    translation = trans_res.scalar_one_or_none()

    # If translation is a modern translation not yet in DB, fetch dynamically
    if not translation:
        mod_info = MODERN_TRANSLATION_MAP.get(translation_id)
        if mod_info:
            bolls_abbr, mod_name, mod_abbr = mod_info
            book_num = BOOK_CODE_TO_BOLLS_NUM.get(book_code, 1)
            url = f"https://bolls.life/get-chapter/{bolls_abbr}/{book_num}/{chapter}/"
            try:
                async with httpx.AsyncClient(timeout=8.0) as client:
                    resp = await client.get(url)
                    if resp.status_code == 200:
                        data = resp.json()
                        verse_outs = []
                        for item in data:
                            v_num = item.get("verse", 1)
                            raw_txt = item.get("text", "")
                            clean_txt = re.sub(r'<[^>]+>', '', raw_txt).strip()
                            clean_txt = re.sub(r'\s+', ' ', clean_txt)
                            verse_outs.append(VerseOut(
                                verse=v_num,
                                text=clean_txt,
                                strongs_text=None,
                                original_words=[],
                            ))
                        b_entry = [v for k, v in BOOK_MAP.items() if v[1] == book_code]
                        b_name = b_entry[0][0] if b_entry else book_code
                        return ChapterOut(
                            book=b_name,
                            book_code=book_code,
                            chapter=chapter,
                            translation_id=translation_id,
                            translation_name=mod_name,
                            verses=verse_outs,
                        )
            except Exception:
                pass

        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Translation '{translation_id}' not found",
        )

    # 2. Fetch verses for chapter
    v_stmt = (
        select(Verse)
        .where(
            Verse.translation_id == translation_id,
            Verse.book_code == book_code,
            Verse.chapter == chapter,
        )
        .order_by(Verse.verse)
    )
    v_res = await db.execute(v_stmt)
    verses = v_res.scalars().all()
    if not verses:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No verses found for {book_code} chapter {chapter}",
        )

    book_name = verses[0].book

    # 3. Fetch original words for this chapter
    ow_stmt = (
        select(OriginalWord, MorphCode.description.label("morph_description"))
        .outerjoin(MorphCode, OriginalWord.morph_code == MorphCode.code)
        .where(
            OriginalWord.book_code == book_code,
            OriginalWord.chapter == chapter,
        )
        .order_by(OriginalWord.verse, OriginalWord.word_position)
    )
    ow_res = await db.execute(ow_stmt)
    orig_rows = ow_res.all()

    # Group original words by verse number
    words_by_verse = {}
    for word, morph_desc in orig_rows:
        w_dict = OriginalWordOut(
            word_position=word.word_position,
            surface_form=word.surface_form,
            lemma=word.lemma,
            transliteration=word.transliteration,
            strongs_number=word.strongs_number,
            morph_code=word.morph_code,
            language=word.language,
            english_gloss=word.english_gloss,
            morph_description=morph_desc,
        )
        words_by_verse.setdefault(word.verse, []).append(w_dict)

    # 4. Assemble response
    verse_outs = []
    for v in verses:
        verse_outs.append(
            VerseOut(
                verse=v.verse,
                text=v.text,
                strongs_text=v.strongs_text,
                original_words=words_by_verse.get(v.verse, []),
            )
        )

    return ChapterOut(
        book=book_name,
        book_code=book_code,
        chapter=chapter,
        translation_id=translation.id,
        translation_name=translation.name,
        verses=verse_outs,
    )
