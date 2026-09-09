import argparse
import asyncio
import os
import sys
import time

# Add root and backend directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete

from app.core.database import AsyncSessionLocal, engine
from app.models.base import Base
from app.models.scripture import Translation, Verse, OriginalWord
from app.models.lexicon import LexiconEntry
from app.models.reference import CrossReference

from ingestion.parsers.bible_parser import BibleParser
from ingestion.parsers.lexicon_parser import LexiconParser
from ingestion.parsers.cross_ref_parser import CrossRefParser


TRANSLATION_METADATA = {
    "web": {
        "name": "World English Bible",
        "abbreviation": "WEB",
        "language": "en",
        "license": "Public Domain",
        "source_url": "https://worldenglish.bible/",
    },
    "kjv": {
        "name": "King James Version",
        "abbreviation": "KJV",
        "language": "en",
        "license": "Public Domain",
        "source_url": "https://en.wikipedia.org/wiki/King_James_Version",
    },
}


async def ingest_translation(session: AsyncSession, translation_id: str, limit: int = None):
    print(f"\n==========================================")
    print(f"Ingesting Translation: {translation_id.upper()}")
    print(f"==========================================")

    meta = TRANSLATION_METADATA.get(translation_id, {
        "name": translation_id.upper(),
        "abbreviation": translation_id.upper(),
        "language": "en",
        "license": "Public Domain",
        "source_url": "",
    })

    # Upsert translation row
    stmt = select(Translation).where(Translation.id == translation_id)
    res = await session.execute(stmt)
    trans = res.scalar_one_or_none()
    if not trans:
        trans = Translation(
            id=translation_id,
            name=meta["name"],
            abbreviation=meta["abbreviation"],
            language=meta["language"],
            license=meta["license"],
            source_url=meta["source_url"],
        )
        session.add(trans)
        await session.commit()
        print(f"Registered translation: {trans.name}")

    parser = BibleParser(translation_id=translation_id)
    try:
        file_path = parser.download_translation()
    except Exception as e:
        print(f"Error downloading {translation_id}: {e}. Skipping translation ingestion.")
        return

    print("Parsing verses and loading into database...")
    batch = []
    total = 0
    start_time = time.time()

    for p_verse in parser.parse_file(file_path):
        if limit and total >= limit:
            break

        verse_obj = Verse(
            translation_id=p_verse.translation_id,
            book=p_verse.book,
            book_code=p_verse.book_code,
            chapter=p_verse.chapter,
            verse=p_verse.verse,
            text=p_verse.text,
        )
        batch.append(verse_obj)
        total += 1

        if len(batch) >= 1000:
            session.add_all(batch)
            await session.commit()
            batch.clear()
            print(f"  Ingested {total} verses... ({time.time() - start_time:.1f}s)")

    if batch:
        session.add_all(batch)
        await session.commit()
        batch.clear()

    print(f"Done! Ingested {total} verses for {translation_id.upper()} in {time.time() - start_time:.1f}s.")


async def ingest_lexicon(session: AsyncSession, language: str, limit: int = None):
    print(f"\n==========================================")
    print(f"Ingesting Strong's {language.title()} Lexicon")
    print(f"==========================================")

    parser = LexiconParser(language=language)
    try:
        file_path = parser.download_lexicon()
    except Exception as e:
        print(f"Error downloading {language} lexicon: {e}. Skipping.")
        return

    batch = []
    total = 0
    start_time = time.time()

    for entry in parser.parse_file(file_path):
        if limit and total >= limit:
            break

        lex_obj = LexiconEntry(
            strongs_number=entry.strongs_number,
            language=entry.language,
            lemma=entry.lemma,
            transliteration=entry.transliteration,
            pronunciation=entry.pronunciation,
            short_definition=entry.short_definition,
            long_definition=entry.long_definition,
            source=entry.source,
            occurrences_count=entry.occurrences_count,
        )
        batch.append(lex_obj)
        total += 1

        if len(batch) >= 500:
            session.add_all(batch)
            await session.commit()
            batch.clear()
            print(f"  Ingested {total} {language} Strong's entries...")

    if batch:
        session.add_all(batch)
        await session.commit()
        batch.clear()

    print(f"Done! Ingested {total} {language.title()} entries in {time.time() - start_time:.1f}s.")


async def ingest_cross_refs(session: AsyncSession, limit: int = 5000):
    print(f"\n==========================================")
    print(f"Ingesting Cross-References")
    print(f"==========================================")

    parser = CrossRefParser()
    file_path = parser.download_data()

    if not os.path.exists(file_path):
        print("Cross-references file not available. Skipping.")
        return

    batch = []
    total = 0
    start_time = time.time()

    for cr in parser.parse_file(file_path, max_items=limit):
        cr_obj = CrossReference(
            from_book_code=cr.from_book_code,
            from_chapter=cr.from_chapter,
            from_verse=cr.from_verse,
            to_book_code=cr.to_book_code,
            to_chapter=cr.to_chapter,
            to_verse=cr.to_verse,
            ref_type=cr.ref_type,
            weight=cr.weight,
            source=cr.source,
        )
        batch.append(cr_obj)
        total += 1

        if len(batch) >= 1000:
            session.add_all(batch)
            await session.commit()
            batch.clear()
            print(f"  Ingested {total} cross-references...")

    if batch:
        session.add_all(batch)
        await session.commit()
        batch.clear()

    print(f"Done! Ingested {total} cross-references in {time.time() - start_time:.1f}s.")


async def main():
    parser = argparse.ArgumentParser(description="ScriptureDepth Dataset Ingestion Pipeline")
    parser.add_argument("--translation", choices=["web", "kjv", "all", "none"], default="web", help="Translation to ingest")
    parser.add_argument("--lexicon", choices=["greek", "hebrew", "both", "none"], default="both", help="Lexicon to ingest")
    parser.add_argument("--cross-refs", action="store_true", help="Ingest cross-references")
    parser.add_argument("--limit", type=int, default=None, help="Limit number of items for test/dry run")
    args = parser.parse_args()

    print("Initializing database tables...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        # Ingest Translations
        if args.translation in ("web", "all"):
            await ingest_translation(session, "web", limit=args.limit)
        if args.translation in ("kjv", "all"):
            await ingest_translation(session, "kjv", limit=args.limit)

        # Ingest Lexicons
        if args.lexicon in ("greek", "both"):
            await ingest_lexicon(session, "greek", limit=args.limit)
        if args.lexicon in ("hebrew", "both"):
            await ingest_lexicon(session, "hebrew", limit=args.limit)

        # Ingest Cross References
        if args.cross_refs:
            await ingest_cross_refs(session, limit=args.limit or 5000)

    print("\nAll requested datasets ingested successfully!")


if __name__ == "__main__":
    asyncio.run(main())
