"""
ScriptureDepth — Modern Translations Ingestion Script.

Ingests:
- ESV (English Standard Version)
- AMP (Amplified Bible)
- NKJV (New King James Version)
- NLT (New Living Translation)
- NIV (New International Version)
- MSG (The Message)
- GNT (Good News Translation)
- CEV (Contemporary English Version)
- NASB (New American Standard Bible)

All 66 books for each translation are ingested directly into Supabase 'verses' table.
"""
import asyncio
import json
import os
import re
import html
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from app.core.database import AsyncSessionLocal, engine
from app.models.scripture import Translation, Verse

CANONICAL_BOOKS = [
    None,  # 1-indexed
    ("Genesis", "GEN"),
    ("Exodus", "EXO"),
    ("Leviticus", "LEV"),
    ("Numbers", "NUM"),
    ("Deuteronomy", "DEU"),
    ("Joshua", "JOS"),
    ("Judges", "JDG"),
    ("Ruth", "RUT"),
    ("1 Samuel", "1SA"),
    ("2 Samuel", "2SA"),
    ("1 Kings", "1KI"),
    ("2 Kings", "2KI"),
    ("1 Chronicles", "1CH"),
    ("2 Chronicles", "2CH"),
    ("Ezra", "EZR"),
    ("Nehemiah", "NEH"),
    ("Esther", "EST"),
    ("Job", "JOB"),
    ("Psalms", "PSA"),
    ("Proverbs", "PRO"),
    ("Ecclesiastes", "ECC"),
    ("Song of Songs", "SNG"),
    ("Isaiah", "ISA"),
    ("Jeremiah", "JER"),
    ("Lamentations", "LAM"),
    ("Ezekiel", "EZK"),
    ("Daniel", "DAN"),
    ("Hosea", "HOS"),
    ("Joel", "JOL"),
    ("Amos", "AMO"),
    ("Obadiah", "OBA"),
    ("Jonah", "JON"),
    ("Micah", "MIC"),
    ("Nahum", "NAM"),
    ("Habakkuk", "HAB"),
    ("Zephaniah", "ZEP"),
    ("Haggai", "HAG"),
    ("Zechariah", "ZEC"),
    ("Malachi", "MAL"),
    ("Matthew", "MAT"),
    ("Mark", "MRK"),
    ("Luke", "LUK"),
    ("John", "JHN"),
    ("Acts", "ACT"),
    ("Romans", "ROM"),
    ("1 Corinthians", "1CO"),
    ("2 Corinthians", "2CO"),
    ("Galatians", "GAL"),
    ("Ephesians", "EPH"),
    ("Philippians", "PHP"),
    ("Colossians", "COL"),
    ("1 Thessalonians", "1TH"),
    ("2 Thessalonians", "2TH"),
    ("1 Timothy", "1TI"),
    ("2 Timothy", "2TI"),
    ("Titus", "TIT"),
    ("Philemon", "PHM"),
    ("Hebrews", "HEB"),
    ("James", "JAS"),
    ("1 Peter", "1PE"),
    ("2 Peter", "2PE"),
    ("1 John", "1JN"),
    ("2 John", "2JN"),
    ("3 John", "3JN"),
    ("Jude", "JUD"),
    ("Revelation", "REV"),
]

TRANSLATIONS_CONFIG = [
    ("esv", "English Standard Version", "ESV", "ESV.json"),
    ("amp", "Amplified Bible", "AMP", "AMP.json"),
    ("nkjv", "New King James Version", "NKJV", "NKJV.json"),
    ("nlt", "New Living Translation", "NLT", "NLT.json"),
    ("niv", "New International Version", "NIV", "NIV.json"),
    ("msg", "The Message", "MSG", "MSG.json"),
    ("gnt", "Good News Translation", "GNT", "GNT.json"),
    ("cev", "Contemporary English Version", "CEV", "CEVD.json"),
    ("nasb", "New American Standard Bible", "NASB", "NASB.json"),
]

DATA_DIR = "ingestion/data/modern_translations"
BATCH_SIZE = 1000


def clean_verse_text(raw: str) -> str:
    """Strip HTML markup, line breaks, and unescape HTML entities."""
    # Replace <br/> or <br> with space
    t = re.sub(r'<br\s*/?>', ' ', raw)
    # Remove all HTML tags
    t = re.sub(r'<[^>]+>', '', t)
    # Unescape HTML entities (&quot;, &#39;, &amp;)
    t = html.unescape(t)
    # Collapse multiple whitespaces
    t = re.sub(r'\s+', ' ', t).strip()
    return t


async def ingest_translation(session: AsyncSession, tid: str, name: str, abbr: str, filename: str):
    filepath = os.path.join(DATA_DIR, filename)
    if not os.path.exists(filepath):
        print(f"  ✗ File not found: {filepath}")
        return 0

    print(f"\n─── Ingesting {abbr} ({name}) ───")

    # 1. Register translation in translations table
    existing_trans = await session.scalar(select(Translation).where(Translation.id == tid))
    if not existing_trans:
        session.add(Translation(
            id=tid,
            name=name,
            abbreviation=abbr,
            language="en",
            license="Commercial / Fair Use Study Text",
        ))
        await session.commit()
        print(f"  ✓ Registered translation: {abbr}")

    # 2. Clear existing verses for this translation
    await session.execute(delete(Verse).where(Verse.translation_id == tid))
    await session.commit()

    # 3. Load JSON data
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    print(f"  Loaded {len(data):,} raw records from {filename}")

    batch = []
    count = 0

    for item in data:
        book_num = item.get("book")
        if not book_num or book_num < 1 or book_num > 66:
            # Skip apocrypha / non-canonical books
            continue

        book_info = CANONICAL_BOOKS[book_num]
        if not book_info:
            continue

        book_name, book_code = book_info
        chapter = item.get("chapter", 1)
        verse = item.get("verse", 1)
        raw_text = item.get("text", "")

        if not raw_text:
            continue

        text = clean_verse_text(raw_text)

        batch.append(Verse(
            translation_id=tid,
            book=book_name,
            book_code=book_code,
            chapter=chapter,
            verse=verse,
            text=text,
            strongs_text=None,
        ))
        count += 1

        if len(batch) >= BATCH_SIZE:
            session.add_all(batch)
            await session.commit()
            batch = []

    if batch:
        session.add_all(batch)
        await session.commit()

    print(f"  ✓ Finished {abbr}: {count:,} verses inserted into Supabase")
    return count


async def main():
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║ ScriptureDepth — Ingesting Modern Translations into Supabase║")
    print("╚══════════════════════════════════════════════════════════════╝")

    async with AsyncSessionLocal() as session:
        grand_total = 0
        for tid, name, abbr, fname in TRANSLATIONS_CONFIG:
            c = await ingest_translation(session, tid, name, abbr, fname)
            grand_total += c

        print("\n╔══════════════════════════════════════════════════════════════╗")
        print(f"║ ALL MODERN TRANSLATIONS SEEDED SUCCESSFULLY                 ║")
        print(f"║ Total verses added: {grand_total:>10,}                            ║")
        print("╚══════════════════════════════════════════════════════════════╝")


if __name__ == "__main__":
    asyncio.run(main())
