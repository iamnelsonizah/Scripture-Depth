from typing import Optional, List
from pydantic import BaseModel, ConfigDict


class LexiconEntryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    strongs_number: str
    language: str
    lemma: str
    transliteration: Optional[str] = None
    pronunciation: Optional[str] = None
    short_definition: str
    long_definition: Optional[str] = None
    source: str
    occurrences_count: int = 0
    derivation: Optional[str] = None
    outline_usage: Optional[str] = None
    kjv_definition: Optional[str] = None


class WordOccurrenceOut(BaseModel):
    book_code: str
    chapter: int
    verse: int
    surface_form: str
    verse_text: Optional[str] = None


class LexiconDetailOut(BaseModel):
    entry: LexiconEntryOut
    occurrences: List[WordOccurrenceOut] = []
