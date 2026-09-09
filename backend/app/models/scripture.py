from sqlalchemy import Column, Integer, String, Text, ForeignKey, Index
from sqlalchemy.orm import relationship
from app.models.base import Base


class Translation(Base):
    __tablename__ = "translations"

    id = Column(String(50), primary_key=True)  # e.g., 'web', 'kjv', 'esv'
    name = Column(String(150), nullable=False)
    abbreviation = Column(String(20), nullable=False, unique=True)
    language = Column(String(20), default="en")
    license = Column(String(100), default="Public Domain")
    source_url = Column(String(255), nullable=True)

    verses = relationship("Verse", back_populates="translation", cascade="all, delete-orphan")


class Verse(Base):
    __tablename__ = "verses"

    id = Column(Integer, primary_key=True, autoincrement=True)
    translation_id = Column(String(50), ForeignKey("translations.id", ondelete="CASCADE"), nullable=False)
    book = Column(String(50), nullable=False)  # e.g., 'John', 'Genesis'
    book_code = Column(String(10), nullable=False)  # e.g., 'JHN', 'GEN'
    chapter = Column(Integer, nullable=False)
    verse = Column(Integer, nullable=False)
    text = Column(Text, nullable=False)
    strongs_text = Column(Text, nullable=True)  # Original text with Strong's tags, e.g. 'God[H430]'

    translation = relationship("Translation", back_populates="verses")

    __table_args__ = (
        Index("ix_verses_lookup", "translation_id", "book_code", "chapter", "verse"),
        Index("ix_verses_chapter", "translation_id", "book_code", "chapter"),
    )


class OriginalWord(Base):
    __tablename__ = "original_words"

    id = Column(Integer, primary_key=True, autoincrement=True)
    book_code = Column(String(10), nullable=False)  # e.g., 'JHN'
    chapter = Column(Integer, nullable=False)
    verse = Column(Integer, nullable=False)
    word_position = Column(Integer, nullable=False)  # 1-indexed word order in verse

    surface_form = Column(String(100), nullable=False)  # e.g., 'ἠγάπησεν'
    lemma = Column(String(100), nullable=False)         # e.g., 'ἀγαπάω'
    transliteration = Column(String(100), nullable=True) # e.g., 'ēgápēsen'
    strongs_number = Column(String(20), nullable=True, index=True) # e.g., 'G25'
    morph_code = Column(String(50), nullable=True)       # e.g., 'V-AAI-3S'
    language = Column(String(10), nullable=False)       # 'greek' or 'hebrew'
    english_gloss = Column(String(100), nullable=True)  # e.g., 'loved'

    __table_args__ = (
        Index("ix_orig_verse", "book_code", "chapter", "verse", "word_position"),
    )


class MorphCode(Base):
    __tablename__ = "morph_codes"

    code = Column(String(50), primary_key=True)  # e.g., 'V-AAI-3S'
    language = Column(String(10), nullable=False)  # 'greek' or 'hebrew'
    description = Column(String(255), nullable=False)  # 'Verb, Aorist Active Indicative, 3rd Person Singular'
    part_of_speech = Column(String(50), nullable=True) # 'Verb'
    tense = Column(String(50), nullable=True)          # 'Aorist'
    voice = Column(String(50), nullable=True)          # 'Active'
    mood = Column(String(50), nullable=True)           # 'Indicative'
    person = Column(String(50), nullable=True)         # '3rd'
    number = Column(String(50), nullable=True)         # 'Singular'
    gender = Column(String(50), nullable=True)
    case = Column(String(50), nullable=True)
