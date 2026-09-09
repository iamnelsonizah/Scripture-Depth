from typing import List, Optional
from pydantic import BaseModel, ConfigDict


class OriginalWordOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    word_position: int
    surface_form: str
    lemma: str
    transliteration: Optional[str] = None
    strongs_number: Optional[str] = None
    morph_code: Optional[str] = None
    language: str
    english_gloss: Optional[str] = None
    morph_description: Optional[str] = None


class VerseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    verse: int
    text: str
    strongs_text: Optional[str] = None
    original_words: List[OriginalWordOut] = []


class ChapterOut(BaseModel):
    book: str
    book_code: str
    chapter: int
    translation_id: str
    translation_name: str
    verses: List[VerseOut]


class TranslationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    abbreviation: str
    language: str
    license: str
