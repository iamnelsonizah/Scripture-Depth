from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import func, select
from app.core.database import get_db
from app.models.lexicon import LexiconEntry
from app.models.scripture import OriginalWord, Verse
from app.schemas.lexicon import LexiconDetailOut, LexiconEntryOut, WordOccurrenceOut

router = APIRouter(prefix="/lexicon", tags=["Lexicon"])


@router.get("/{strongs_number}", response_model=LexiconDetailOut)
async def get_lexicon_entry(
    strongs_number: str,
    limit_occurrences: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
):
    """
    Look up a Strong's number (e.g. 'G25', 'G2316', 'H7225') with definitions and occurrences.
    """
    strongs_number = strongs_number.upper().strip()

    stmt = select(LexiconEntry).where(LexiconEntry.strongs_number == strongs_number)
    res = await db.execute(stmt)
    entry = res.scalars().first()

    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Strong's entry '{strongs_number}' not found",
        )

    # Fetch sample occurrences
    occ_stmt = (
        select(OriginalWord.book_code, OriginalWord.chapter, OriginalWord.verse, OriginalWord.surface_form)
        .where(OriginalWord.strongs_number == strongs_number)
        .limit(limit_occurrences)
    )
    occ_res = await db.execute(occ_stmt)
    occ_rows = occ_res.all()

    occurrences = []
    for row in occ_rows:
        # Optionally find verse text from default translation
        v_stmt = (
            select(Verse.text)
            .where(
                Verse.book_code == row.book_code,
                Verse.chapter == row.chapter,
                Verse.verse == row.verse,
            )
            .limit(1)
        )
        v_res = await db.execute(v_stmt)
        v_text = v_res.scalar_one_or_none()

        occurrences.append(
            WordOccurrenceOut(
                book_code=row.book_code,
                chapter=row.chapter,
                verse=row.verse,
                surface_form=row.surface_form,
                verse_text=v_text,
            )
        )

    # If no occurrences in original_words table, query tagged KJV verses!
    if not occurrences:
        v_occ_stmt = (
            select(Verse.book_code, Verse.chapter, Verse.verse, Verse.text)
            .where(
                Verse.translation_id == "kjv",
                Verse.strongs_text.like(f"%[{strongs_number}]%"),
            )
            .order_by(Verse.id)
            .limit(limit_occurrences)
        )
        v_occ_res = await db.execute(v_occ_stmt)
        for row in v_occ_res.all():
            occurrences.append(
                WordOccurrenceOut(
                    book_code=row.book_code,
                    chapter=row.chapter,
                    verse=row.verse,
                    surface_form=entry.lemma,
                    verse_text=row.text,
                )
            )

    return LexiconDetailOut(
        entry=LexiconEntryOut.model_validate(entry),
        occurrences=occurrences,
    )
