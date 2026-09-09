from typing import List, Optional
from pydantic import BaseModel


class SearchResultItem(BaseModel):
    book: str
    book_code: str
    chapter: int
    verse: int
    text: str
    highlighted_text: Optional[str] = None
    translation_id: str


class SearchResponse(BaseModel):
    query: str
    total_results: int
    results: List[SearchResultItem]
    related_cross_references: List[str] = []
