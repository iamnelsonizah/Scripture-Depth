from sqlalchemy import Column, Integer, String, Text, Float, Index
from app.models.base import Base


class CrossReference(Base):
    __tablename__ = "cross_references"

    id = Column(Integer, primary_key=True, autoincrement=True)
    from_book_code = Column(String(10), nullable=False)
    from_chapter = Column(Integer, nullable=False)
    from_verse = Column(Integer, nullable=False)

    to_book_code = Column(String(10), nullable=False)
    to_chapter = Column(Integer, nullable=False)
    to_verse = Column(Integer, nullable=False)

    ref_type = Column(String(30), default="thematic")  # 'thematic', 'quotation', 'prophecy'
    weight = Column(Float, default=1.0)               # Community votes / relevance score
    source = Column(String(50), default="openbible")

    __table_args__ = (
        Index("ix_cross_ref_from", "from_book_code", "from_chapter", "from_verse"),
        Index("ix_cross_ref_to", "to_book_code", "to_chapter", "to_verse"),
    )


class CommentaryEntry(Base):
    __tablename__ = "commentary_entries"

    id = Column(Integer, primary_key=True, autoincrement=True)
    book_code = Column(String(10), nullable=False)
    chapter_start = Column(Integer, nullable=False)
    verse_start = Column(Integer, nullable=False)
    chapter_end = Column(Integer, nullable=False)
    verse_end = Column(Integer, nullable=False)

    author = Column(String(100), nullable=False)      # e.g., 'Matthew Henry', 'John Calvin'
    title = Column(String(200), nullable=True)
    text = Column(Text, nullable=False)
    source = Column(String(50), default="sword")

    __table_args__ = (
        Index("ix_commentary_span", "book_code", "chapter_start", "verse_start"),
    )
