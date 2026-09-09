from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.reference import CrossReference, CommentaryEntry
from app.models.scripture import Verse
from app.schemas.reference import CrossReferenceOut, CommentaryEntryOut

router = APIRouter(prefix="", tags=["Cross References & Commentary"])


@router.get("/cross-references/{book_code}/{chapter}/{verse}", response_model=List[CrossReferenceOut])
async def get_cross_references(
    book_code: str,
    chapter: int,
    verse: int,
    translation_id: str = "web",
    db: AsyncSession = Depends(get_db),
):
    """Fetch cross-references linked to a specific verse, ranked by weight."""
    book_code = book_code.upper()
    stmt = (
        select(CrossReference)
        .where(
            CrossReference.from_book_code == book_code,
            CrossReference.from_chapter == chapter,
            CrossReference.from_verse == verse,
        )
        .order_by(CrossReference.weight.desc())
        .limit(20)
    )
    res = await db.execute(stmt)
    refs = res.scalars().all()

    output = []
    for r in refs:
        v_stmt = (
            select(Verse.text)
            .where(
                Verse.translation_id == translation_id,
                Verse.book_code == r.to_book_code,
                Verse.chapter == r.to_chapter,
                Verse.verse == r.to_verse,
            )
            .limit(1)
        )
        v_res = await db.execute(v_stmt)
        v_text = v_res.scalar_one_or_none()

        output.append(
            CrossReferenceOut(
                to_book_code=r.to_book_code,
                to_chapter=r.to_chapter,
                to_verse=r.to_verse,
                ref_type=r.ref_type,
                weight=r.weight,
                verse_text=v_text,
            )
        )

    return output


@router.get("/commentary/{book_code}/{chapter}/{verse}", response_model=List[CommentaryEntryOut])
async def get_commentaries(
    book_code: str,
    chapter: int,
    verse: int,
    db: AsyncSession = Depends(get_db),
):
    """Fetch commentary entries covering this verse."""
    book_code = book_code.upper()
    stmt = (
        select(CommentaryEntry)
        .where(
            CommentaryEntry.book_code == book_code,
            CommentaryEntry.chapter_start <= chapter,
            CommentaryEntry.chapter_end >= chapter,
            CommentaryEntry.verse_start <= verse,
            CommentaryEntry.verse_end >= verse,
        )
        .limit(10)
    )
    res = await db.execute(stmt)
    return res.scalars().all()
