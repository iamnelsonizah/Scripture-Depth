from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, func
from app.core.database import get_db
from app.core.security import get_current_user, get_optional_user, AuthUser
from app.models.user_data import Note, Bookmark, ReadingPlan, ReadingPlanProgress, MemorizationItem
from app.schemas.user import (
    NoteCreate,
    NoteOut,
    BookmarkCreate,
    BookmarkOut,
    ReadingPlanOut,
    ReadingPlanProgressOut,
    MemorizationItemOut,
    MemorizationItemCreate,
)

router = APIRouter(prefix="", tags=["User Data"])


# --- Notes ---
@router.get("/notes", response_model=List[NoteOut])
async def list_notes(
    book_code: str = None,
    current_user: AuthUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Note).where(Note.user_id == current_user.user_id)
    if book_code:
        stmt = stmt.where(Note.book_code == book_code.upper())
    stmt = stmt.order_by(Note.created_at.desc())
    res = await db.execute(stmt)
    return res.scalars().all()


@router.post("/notes", response_model=NoteOut, status_code=status.HTTP_201_CREATED)
async def create_note(
    note_in: NoteCreate,
    current_user: AuthUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    note = Note(
        user_id=current_user.user_id,
        book_code=note_in.book_code.upper(),
        chapter=note_in.chapter,
        verse=note_in.verse,
        text=note_in.text,
    )
    db.add(note)
    await db.commit()
    await db.refresh(note)
    return note


@router.delete("/notes/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_note(
    note_id: int,
    current_user: AuthUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = delete(Note).where(Note.id == note_id, Note.user_id == current_user.user_id)
    res = await db.execute(stmt)
    if res.rowcount == 0:
        raise HTTPException(status_code=404, detail="Note not found")
    await db.commit()


# --- Bookmarks ---
@router.get("/bookmarks", response_model=List[BookmarkOut])
async def list_bookmarks(
    current_user: AuthUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Bookmark).where(Bookmark.user_id == current_user.user_id).order_by(Bookmark.created_at.desc())
    res = await db.execute(stmt)
    return res.scalars().all()


@router.post("/bookmarks", response_model=BookmarkOut, status_code=status.HTTP_201_CREATED)
async def create_bookmark(
    bm_in: BookmarkCreate,
    current_user: AuthUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    bm = Bookmark(
        user_id=current_user.user_id,
        book_code=bm_in.book_code.upper(),
        chapter=bm_in.chapter,
        verse=bm_in.verse,
        label=bm_in.label,
    )
    db.add(bm)
    await db.commit()
    await db.refresh(bm)
    return bm


# --- Reading Plans ---
@router.get("/reading-plans", response_model=List[ReadingPlanOut])
async def list_reading_plans(db: AsyncSession = Depends(get_db)):
    stmt = select(ReadingPlan)
    res = await db.execute(stmt)
    return res.scalars().all()


@router.get("/reading-plans/active", response_model=List[ReadingPlanProgressOut])
async def get_active_plans(
    current_user: AuthUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(ReadingPlanProgress).where(
        ReadingPlanProgress.user_id == current_user.user_id,
        ReadingPlanProgress.is_completed == False,
    )
    res = await db.execute(stmt)
    return res.scalars().all()


# --- Memorization (Spaced Repetition) ---
@router.get("/memorization/due", response_model=List[MemorizationItemOut])
async def get_due_memorization_items(
    current_user: Optional[AuthUser] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.utcnow()
    user_id = current_user.user_id if current_user else "system"

    # If user is authenticated, check if they have personal items; if not, clone system items
    if current_user:
        count_stmt = select(func.count(MemorizationItem.id)).where(MemorizationItem.user_id == user_id)
        cnt = (await db.scalar(count_stmt)) or 0
        if cnt == 0:
            sys_stmt = select(MemorizationItem).where(MemorizationItem.user_id == "system")
            sys_items = (await db.execute(sys_stmt)).scalars().all()
            for si in sys_items:
                clone = MemorizationItem(
                    user_id=user_id,
                    book_code=si.book_code,
                    chapter=si.chapter,
                    verse=si.verse,
                    verse_text=si.verse_text,
                    interval_days=si.interval_days,
                    repetitions=si.repetitions,
                    ease_factor=si.ease_factor,
                    next_review_at=si.next_review_at,
                )
                db.add(clone)
            await db.commit()

    stmt = select(MemorizationItem).where(
        MemorizationItem.user_id == user_id,
        MemorizationItem.next_review_at <= now,
    ).order_by(MemorizationItem.next_review_at.asc())
    res = await db.execute(stmt)
    items = res.scalars().all()

    # Fallback if none due today: return up to 10 active items for study practice
    if not items:
        stmt_all = select(MemorizationItem).where(
            MemorizationItem.user_id == user_id,
        ).limit(10)
        items = (await db.execute(stmt_all)).scalars().all()

    return items


@router.post("/memorization", response_model=MemorizationItemOut, status_code=status.HTTP_201_CREATED)
async def add_memorization_item(
    item_in: MemorizationItemCreate,
    current_user: Optional[AuthUser] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    user_id = current_user.user_id if current_user else "system"
    item = MemorizationItem(
        user_id=user_id,
        book_code=item_in.book_code.upper(),
        chapter=item_in.chapter,
        verse=item_in.verse,
        verse_text=item_in.verse_text,
        next_review_at=datetime.utcnow(),
        interval_days=1,
        repetitions=0,
        ease_factor=2.5,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


@router.post("/memorization/{item_id}/review", response_model=MemorizationItemOut)
async def review_memorization_item(
    item_id: int,
    rating: int,  # 1 (failed) to 5 (perfect)
    current_user: Optional[AuthUser] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(MemorizationItem).where(MemorizationItem.id == item_id)
    if current_user:
        stmt = stmt.where(MemorizationItem.user_id.in_([current_user.user_id, "system"]))
    res = await db.execute(stmt)
    item = res.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Memorization item not found")

    # SuperMemo SM-2 Interval Calculation
    if rating >= 3:
        if item.repetitions == 0:
            item.interval_days = 1
        elif item.repetitions == 1:
            item.interval_days = 6
        else:
            item.interval_days = int(item.interval_days * item.ease_factor)
        item.repetitions += 1
    else:
        item.repetitions = 0
        item.interval_days = 1

    item.ease_factor = max(1.3, item.ease_factor + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02)))
    item.next_review_at = datetime.utcnow() + timedelta(days=item.interval_days)

    await db.commit()
    await db.refresh(item)
    return item


@router.get("/memorization/stats")
async def get_memorization_stats(
    current_user: Optional[AuthUser] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    user_id = current_user.user_id if current_user else "system"
    stmt_memorized = select(func.count(MemorizationItem.id)).where(
        MemorizationItem.user_id.in_([user_id, "system"]),
        MemorizationItem.repetitions > 0,
    )
    memorized_res = await db.execute(stmt_memorized)
    memorized_count = memorized_res.scalar() or 0

    stmt_total = select(func.count(MemorizationItem.id)).where(
        MemorizationItem.user_id.in_([user_id, "system"]),
    )
    total_res = await db.execute(stmt_total)
    total_count = total_res.scalar() or 0

    return {
        "memorized_count": memorized_count,
        "total_cards": total_count,
    }


