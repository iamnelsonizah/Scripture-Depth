import os
import re
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from fastapi.responses import StreamingResponse, JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.scripture import Verse
from app.core.book_names import BOOK_MAP
import httpx

router = APIRouter(prefix="/audio", tags=["Audio Narration"])

BOOK_NUMBER_MAP = {
    'GEN': (1, 'Genesis', 50),
    'EXO': (2, 'Exodus', 40),
    'LEV': (3, 'Leviticus', 27),
    'NUM': (4, 'Numbers', 36),
    'DEU': (5, 'Deuteronomy', 34),
    'JOS': (6, 'Joshua', 24),
    'JDG': (7, 'Judges', 21),
    'RUT': (8, 'Ruth', 4),
    '1SA': (9, '1 Samuel', 31),
    '2SA': (10, '2 Samuel', 24),
    '1KI': (11, '1 Kings', 22),
    '2KI': (12, '2 Kings', 25),
    '1CH': (13, '1 Chronicles', 29),
    '2CH': (14, '2 Chronicles', 36),
    'EZR': (15, 'Ezra', 10),
    'NEH': (16, 'Nehemiah', 13),
    'EST': (17, 'Esther', 10),
    'JOB': (18, 'Job', 42),
    'PSA': (19, 'Psalms', 150),
    'PRO': (20, 'Proverbs', 31),
    'ECC': (21, 'Ecclesiastes', 12),
    'SNG': (22, 'Song of Solomon', 8),
    'ISA': (23, 'Isaiah', 66),
    'JER': (24, 'Jeremiah', 52),
    'LAM': (25, 'Lamentations', 5),
    'EZK': (26, 'Ezekiel', 48),
    'DAN': (27, 'Daniel', 12),
    'HOS': (28, 'Hosea', 14),
    'JOL': (29, 'Joel', 3),
    'AMO': (30, 'Amos', 9),
    'OBA': (31, 'Obadiah', 1),
    'JON': (32, 'Jonah', 4),
    'MIC': (33, 'Micah', 7),
    'NAM': (34, 'Nahum', 3),
    'HAB': (35, 'Habakkuk', 3),
    'ZEP': (36, 'Zephaniah', 3),
    'HAG': (37, 'Haggai', 2),
    'ZEC': (38, 'Zechariah', 14),
    'MAL': (39, 'Malachi', 4),
    'MAT': (40, 'Matthew', 28),
    'MRK': (41, 'Mark', 16),
    'LUK': (42, 'Luke', 24),
    'JHN': (43, 'John', 21),
    'ACT': (44, 'Acts', 28),
    'ROM': (45, 'Romans', 16),
    '1CO': (46, '1 Corinthians', 16),
    '2CO': (47, '2 Corinthians', 13),
    'GAL': (48, 'Galatians', 6),
    'EPH': (49, 'Ephesians', 6),
    'PHP': (50, 'Philippians', 4),
    'COL': (51, 'Colossians', 4),
    '1TH': (52, '1 Thessalonians', 5),
    '2TH': (53, '2 Thessalonians', 3),
    '1TI': (54, '1 Timothy', 6),
    '2TI': (55, '2 Timothy', 4),
    'TIT': (56, 'Titus', 3),
    'PHM': (57, 'Philemon', 1),
    'HEB': (58, 'Hebrews', 13),
    'JAS': (59, 'James', 5),
    '1PE': (60, '1 Peter', 5),
    '2PE': (61, '2 Peter', 3),
    '1JN': (62, '1 John', 5),
    '2JN': (63, '2 John', 1),
    '3JN': (64, '3 John', 1),
    'JUD': (65, 'Jude', 1),
    'REV': (66, 'Revelation', 22),
}

AUDIO_CACHE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data", "audio_cache")
os.makedirs(AUDIO_CACHE_DIR, exist_ok=True)


def get_cdn_audio_url(translation_id: str, book_code: str, chapter: int) -> str:
    """Returns the primary high-fidelity human studio audio URL for a given book and chapter."""
    tid = translation_id.lower()
    binfo = BOOK_NUMBER_MAP.get(book_code.upper())
    if not binfo:
        return ""
    bnum, bname, _ = binfo
    bnum_str = f"{bnum:02d}"
    ch_str = f"{chapter:02d}"

    # Public domain human narration CDN mirror (Stephen Johnston / Alexander Scourby)
    # Hosted reliably on AudioTreasure / Internet Archive KJV collections
    formatted_name = bname.replace(" ", "")
    return f"https://www.audiotreasure.com/mp3/{formatted_name}/{ch_str}_{formatted_name}.mp3"


@router.get("/chapter/{translation_id}/{book_code}/{chapter}")
async def get_chapter_audio_info(
    translation_id: str,
    book_code: str,
    chapter: int,
    db: AsyncSession = Depends(get_db),
):
    """
    Returns audio metadata, human narrator details, and verse-synced timestamps for a chapter.
    """
    code = book_code.upper()
    tid = translation_id.lower()
    binfo = BOOK_NUMBER_MAP.get(code)
    if not binfo:
        raise HTTPException(status_code=404, detail=f"Book '{book_code}' not found.")

    bnum, bname, total_chapters = binfo
    if chapter < 1 or chapter > total_chapters:
        raise HTTPException(status_code=404, detail=f"Chapter {chapter} out of range for {bname}.")

    # Fetch verses to compute proportional timing boundaries
    stmt = (
        select(Verse)
        .where(
            Verse.translation_id == tid,
            Verse.book_code == code,
            Verse.chapter == chapter,
        )
        .order_by(Verse.verse)
    )
    result = await db.execute(stmt)
    verses = list(result.scalars().all())

    # Fallback to KJV if specific translation verses not found
    if not verses and tid != 'kjv':
        stmt_kjv = (
            select(Verse)
            .where(
                Verse.translation_id == 'kjv',
                Verse.book_code == code,
                Verse.chapter == chapter,
            )
            .order_by(Verse.verse)
        )
        res_kjv = await db.execute(stmt_kjv)
        verses = list(res_kjv.scalars().all())

    # Calculate verse boundaries
    # Average human Bible narration speed: ~135-150 words per minute (~2.3 words per second)
    verse_markers = []
    total_words = 0
    word_counts = []

    for v in verses:
        w_count = len(re.findall(r'\b\w+\b', v.text)) if v.text else 10
        w_count = max(w_count, 4)
        word_counts.append(w_count)
        total_words += w_count

    if total_words == 0:
        total_words = 200
        word_counts = [20] * 10

    # Estimated total duration in milliseconds
    # 138 words per minute = ~434ms per word + 700ms pause per verse
    per_word_ms = 434
    pause_per_verse_ms = 700

    current_ms = 0
    for idx, count in enumerate(word_counts):
        v_num = verses[idx].verse if idx < len(verses) else (idx + 1)
        v_duration = (count * per_word_ms) + pause_per_verse_ms
        start_ms = current_ms
        end_ms = current_ms + v_duration
        verse_markers.append({
            "verse": v_num,
            "start_ms": start_ms,
            "end_ms": end_ms,
        })
        current_ms = end_ms

    total_duration_sec = round(current_ms / 1000.0, 1)

    cdn_stream = get_cdn_audio_url(tid, code, chapter)
    proxy_stream = f"/api/v1/audio/stream/{tid}/{code}/{chapter}"

    narrator_name = "Alexander Scourby" if tid == "kjv" else "Human Studio Narration"

    return {
        "translation_id": tid,
        "book_code": code,
        "book_name": bname,
        "chapter": chapter,
        "narrator": narrator_name,
        "fidelity": "high_fidelity_human",
        "fidelity_label": f"{narrator_name} · Human Studio",
        "stream_url": proxy_stream,
        "direct_cdn_url": cdn_stream,
        "total_duration_seconds": total_duration_sec,
        "verse_count": len(verse_markers),
        "verses": verse_markers,
    }


@router.get("/stream/{translation_id}/{book_code}/{chapter}")
async def stream_chapter_audio(
    translation_id: str,
    book_code: str,
    chapter: int,
):
    """
    Streams the chapter MP3 audio file. Serves from local cache if present,
    otherwise fetches and caches from the high-fidelity CDN mirror.
    """
    code = book_code.upper()
    tid = translation_id.lower()
    cache_filename = f"{tid}_{code}_{chapter}.mp3"
    cache_filepath = os.path.join(AUDIO_CACHE_DIR, cache_filename)

    # 1. Serve from local server disk cache if already downloaded
    if os.path.isfile(cache_filepath) and os.path.getsize(cache_filepath) > 1024:
        def iter_cached():
            with open(cache_filepath, "rb") as f:
                while chunk := f.read(65536):
                    yield chunk
        return StreamingResponse(
            iter_cached(),
            media_type="audio/mpeg",
            headers={
                "Content-Disposition": f'inline; filename="{cache_filename}"',
                "Accept-Ranges": "bytes",
                "X-Audio-Source": "local_server_cache",
            },
        )

    # 2. Fetch from CDN stream
    cdn_url = get_cdn_audio_url(tid, code, chapter)
    if not cdn_url:
        raise HTTPException(status_code=404, detail="Audio stream not found.")

    try:
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True) as client:
            resp = await client.get(cdn_url)
            if resp.status_code == 200 and len(resp.content) > 1024:
                # Save to local server cache
                try:
                    with open(cache_filepath, "wb") as f:
                        f.write(resp.content)
                except Exception:
                    pass

                return Response(
                    content=resp.content,
                    media_type="audio/mpeg",
                    headers={
                        "Content-Disposition": f'inline; filename="{cache_filename}"',
                        "Accept-Ranges": "bytes",
                        "X-Audio-Source": "high_fidelity_cdn",
                    },
                )
    except Exception:
        pass

    # If external CDN is temporarily unreachable, return 404 so client uses device-native fallback
    raise HTTPException(
        status_code=503,
        detail="High-fidelity audio stream currently unavailable; client should use local offline voice.",
    )
