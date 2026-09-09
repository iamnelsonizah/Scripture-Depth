from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Index, Float, Boolean
from app.models.base import Base


class Note(Base):
    __tablename__ = "notes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(100), nullable=False, index=True)  # Supabase auth.users ID
    book_code = Column(String(10), nullable=False)
    chapter = Column(Integer, nullable=False)
    verse = Column(Integer, nullable=False)
    text = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index("ix_user_notes_verse", "user_id", "book_code", "chapter", "verse"),
    )


class Bookmark(Base):
    __tablename__ = "bookmarks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(100), nullable=False, index=True)
    book_code = Column(String(10), nullable=False)
    chapter = Column(Integer, nullable=False)
    verse = Column(Integer, nullable=False)
    label = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("ix_user_bookmarks", "user_id", "book_code", "chapter", "verse"),
    )


class ReadingPlan(Base):
    __tablename__ = "reading_plans"

    id = Column(String(50), primary_key=True)  # e.g., 'gospel_of_john_30d'
    title = Column(String(150), nullable=False)
    description = Column(Text, nullable=True)
    duration_days = Column(Integer, nullable=False)
    structure_json = Column(Text, nullable=False)  # JSON list of days with readings


class ReadingPlanProgress(Base):
    __tablename__ = "reading_plan_progress"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(100), nullable=False, index=True)
    plan_id = Column(String(50), ForeignKey("reading_plans.id", ondelete="CASCADE"), nullable=False)
    current_day = Column(Integer, default=1)
    is_completed = Column(Boolean, default=False)
    started_at = Column(DateTime, default=datetime.utcnow)
    last_read_at = Column(DateTime, default=datetime.utcnow)


class MemorizationItem(Base):
    __tablename__ = "memorization_items"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(100), nullable=False, index=True)
    book_code = Column(String(10), nullable=False)
    chapter = Column(Integer, nullable=False)
    verse = Column(Integer, nullable=False)
    verse_text = Column(Text, nullable=False)
    next_review_at = Column(DateTime, default=datetime.utcnow)
    interval_days = Column(Integer, default=1)
    repetitions = Column(Integer, default=0)
    ease_factor = Column(Float, default=2.5)  # SuperMemo SM-2 algorithm standard


class UserStudyActivity(Base):
    __tablename__ = "user_study_activities"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(100), nullable=False, index=True)
    activity_date = Column(String(10), nullable=False)  # YYYY-MM-DD
    chapters_read = Column(Integer, default=0)
    cards_reviewed = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index("ix_user_activity_date", "user_id", "activity_date", unique=True),
    )

