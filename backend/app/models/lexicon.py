from sqlalchemy import Column, Integer, String, Text, Index
from app.models.base import Base


class LexiconEntry(Base):
    __tablename__ = "lexicon_entries"

    id = Column(Integer, primary_key=True, autoincrement=True)
    strongs_number = Column(String(20), nullable=False, index=True)  # e.g., 'G25', 'H7225'
    language = Column(String(10), nullable=False)                    # 'greek' or 'hebrew'
    lemma = Column(String(100), nullable=False)                      # 'ἀγαπάω'
    transliteration = Column(String(100), nullable=True)             # 'agapaō'
    pronunciation = Column(String(100), nullable=True)               # 'ag-ap-ah'-o'
    short_definition = Column(Text, nullable=False)                  # Definition text
    long_definition = Column(Text, nullable=True)                    # Exhaustive definition
    source = Column(String(50), default="strongs")                   # 'strongs', 'thayer', 'bdb', 'stepbible'
    occurrences_count = Column(Integer, default=0)
    derivation = Column(Text, nullable=True)        # e.g., 'from H1961; the self-Existent or Eternal'
    outline_usage = Column(Text, nullable=True)      # Full outline of biblical usage
    kjv_definition = Column(Text, nullable=True)     # KJV definition text

    __table_args__ = (
        Index("ix_lexicon_strongs_source", "strongs_number", "source"),
    )
