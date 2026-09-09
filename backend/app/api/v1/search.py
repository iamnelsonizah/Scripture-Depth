import re
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.scripture import Verse
from app.models.reference import CrossReference
from app.schemas.search import SearchResponse, SearchResultItem

router = APIRouter(prefix="/search", tags=["Search"])


@router.get("", response_model=SearchResponse)
async def search_verses(
    q: str = Query(..., min_length=2, description="Search keyword, phrase, or Strong's number like H430/G25"),
    translation_id: str = Query("kjv", description="Translation ID"),
    testament: str = Query(None, description="Optional testament filter: 'OT' or 'NT'"),
    limit: int = Query(40, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """
    Search verse text across the selected translation.
    Supports keywords, phrases, Strong's numbers (e.g. H430, G25),
    inline highlighting, and related cross-references.
    """
    clean_q = q.strip()
    is_strongs = bool(re.match(r'^[HG]\d+$', clean_q, re.IGNORECASE))
    pattern = re.compile(re.escape(clean_q), re.IGNORECASE)

    conditions = [Verse.translation_id == translation_id.lower()]

    if is_strongs:
        # Search by Strong's concordance tag (e.g. H430, G25)
        conditions.append(Verse.strongs_text.ilike(f"%{clean_q.upper()}%"))
    else:
        conditions.append(Verse.text.ilike(f"%{clean_q}%"))

    if testament and testament.upper() in ('OT', 'NT'):
        from app.core.book_names import BOOK_MAP
        t_upper = testament.upper()
        allowed_codes = list({v[1] for k, v in BOOK_MAP.items() if v[2] == t_upper})
        if allowed_codes:
            conditions.append(Verse.book_code.in_(allowed_codes))

    stmt = select(Verse).where(*conditions).order_by(Verse.id).limit(limit)
    res = await db.execute(stmt)
    verses = res.scalars().all()

    results = []
    first_hit = None
    for v in verses:
        if not first_hit:
            first_hit = v

        # Add <mark> tags around matching query in text
        highlighted = pattern.sub(lambda m: f"<mark>{m.group(0)}</mark>", v.text)
        results.append(
            SearchResultItem(
                book=v.book,
                book_code=v.book_code,
                chapter=v.chapter,
                verse=v.verse,
                text=v.text,
                highlighted_text=highlighted,
                translation_id=v.translation_id,
            )
        )

    # Collect related themes from cross-references if we found matches
    related_refs = []
    if first_hit:
        cr_stmt = (
            select(CrossReference)
            .where(
                CrossReference.from_book_code == first_hit.book_code,
                CrossReference.from_chapter == first_hit.chapter,
                CrossReference.from_verse == first_hit.verse,
            )
            .limit(5)
        )
        cr_res = await db.execute(cr_stmt)
        related_refs = [
            f"{r.to_book_code} {r.to_chapter}:{r.to_verse}" for r in cr_res.scalars().all()
        ]

    return SearchResponse(
        query=clean_q,
        total_results=len(results),
        results=results,
        related_cross_references=related_refs,
    )
