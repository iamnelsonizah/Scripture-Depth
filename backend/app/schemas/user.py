from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict


class NoteCreate(BaseModel):
    book_code: str
    chapter: int
    verse: int
    text: str


class NoteUpdate(BaseModel):
    text: str


class NoteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: str
    book_code: str
    chapter: int
    verse: int
    text: str
    created_at: datetime
    updated_at: datetime


class BookmarkCreate(BaseModel):
    book_code: str
    chapter: int
    verse: int
    label: Optional[str] = None


class BookmarkOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: str
    book_code: str
    chapter: int
    verse: int
    label: Optional[str] = None
    created_at: datetime


class ReadingPlanOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    description: Optional[str] = None
    duration_days: int
    structure_json: str


class ReadingPlanProgressOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: str
    plan_id: str
    current_day: int
    is_completed: bool
    started_at: datetime


class MemorizationItemCreate(BaseModel):
    book_code: str
    chapter: int
    verse: int
    verse_text: str


class MemorizationItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: str
    book_code: str
    chapter: int
    verse: int
    verse_text: str
    next_review_at: datetime
    interval_days: int
    repetitions: int
