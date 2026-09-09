from typing import Optional
from pydantic import BaseModel, ConfigDict


class CrossReferenceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    to_book_code: str
    to_chapter: int
    to_verse: int
    ref_type: str
    weight: float
    verse_text: Optional[str] = None


class CommentaryEntryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    author: str
    title: Optional[str] = None
    text: str
    source: str
