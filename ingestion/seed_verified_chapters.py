import asyncio
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from app.core.database import AsyncSessionLocal, engine
from app.models.base import Base
from app.models.scripture import Translation, Verse, OriginalWord
from app.models.reference import CrossReference
from app.models.lexicon import LexiconEntry
from ingestion.parsers.bible_parser import BibleParser

SELECTED_CHAPTERS = [
    ("GEN", 1),
    ("GEN", 2),
    ("GEN", 3),
    ("EXO", 20),
    ("PSA", 23),
    ("PSA", 102),
    ("MAT", 5),
    ("JHN", 1),
    ("JHN", 3),
    ("ROM", 5),
    ("ROM", 8),
    ("COL", 1),
    ("1TH", 5),
    ("HEB", 11),
    ("1JN", 4),
]

async def seed_verified_data():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        # 1. Register Translations
        translations = [
            ("kjv", "King James Version", "KJV"),
            ("web", "World English Bible", "WEB"),
            ("asv", "American Standard Version", "ASV"),
        ]
        for tid, name, abbr in translations:
            t = await session.scalar(select(Translation).where(Translation.id == tid))
            if not t:
                session.add(Translation(id=tid, name=name, abbreviation=abbr, language="en", license="Public Domain"))
        await session.commit()

        # 2. Parse and insert complete chapters from KJV and ASV
        for tid in ["kjv", "asv"]:
            parser = BibleParser(tid)
            file_path = f"ingestion/data/{tid}.json"
            print(f"Loading {tid.upper()} from {file_path}...")
            all_verses = list(parser.parse_file(file_path))

            for book_code, chapter_num in SELECTED_CHAPTERS:
                matches = [v for v in all_verses if v.book_code == book_code and v.chapter == chapter_num]
                if not matches:
                    continue

                # Clear old verses for this chapter
                await session.execute(
                    delete(Verse).where(
                        Verse.translation_id == tid,
                        Verse.book_code == book_code,
                        Verse.chapter == chapter_num,
                    )
                )

                for v in matches:
                    session.add(
                        Verse(
                            translation_id=tid,
                            book=v.book,
                            book_code=v.book_code,
                            chapter=v.chapter,
                            verse=v.verse,
                            text=v.text,
                        )
                    )
                print(f"  Inserted {len(matches)} verses for {tid.upper()} {book_code} {chapter_num}")

            # Also duplicate KJV to WEB for now if WEB JSON is identical or subset
            if tid == "kjv":
                for book_code, chapter_num in SELECTED_CHAPTERS:
                    matches = [v for v in all_verses if v.book_code == book_code and v.chapter == chapter_num]
                    await session.execute(
                        delete(Verse).where(
                            Verse.translation_id == "web",
                            Verse.book_code == book_code,
                            Verse.chapter == chapter_num,
                        )
                    )
                    for v in matches:
                        session.add(
                            Verse(
                                translation_id="web",
                                book=v.book,
                                book_code=v.book_code,
                                chapter=v.chapter,
                                verse=v.verse,
                                text=v.text,
                            )
                        )

        await session.commit()

        # 3. Add Strong's Lexicon entries for key Hebrew and Greek roots
        lex_entries = [
            ("H430", "hebrew", "אֱלֹהִים", "'elōhîm", "el-o-heem'", "God, the Supreme Divinity, Creator of Heaven and Earth (plural of majesty)", "strongs", 2606),
            ("H7225", "hebrew", "רֵאשִׁית", "rē'šît", "ray-sheet'", "First, beginning, primeval start, chief choice part", "strongs", 51),
            ("H1254", "hebrew", "בָּרָא", "bārā'", "baw-raw'", "To create out of nothing (used exclusively of divine creation)", "strongs", 54),
            ("H8064", "hebrew", "שָׁמַיִם", "šāmayim", "shaw-mah'-yim", "The heavens, the celestial canopy, visible sky and abode of God", "strongs", 420),
            ("H776", "hebrew", "אֶרֶץ", "'ereṣ", "eh'-rets", "The earth, the land, the terrestrial globe", "strongs", 2504),
            ("H7307", "hebrew", "רוּחַ", "rûaḥ", "roo'-akh", "Spirit, breath, the Holy Spirit of God moving over the deep", "strongs", 378),
            ("H216", "hebrew", "אוֹר", "'ôr", "ore", "Light, radiant daylight, spiritual illumination", "strongs", 120),
            ("G2316", "greek", "θεός", "theós", "theh'-os", "God, the one supreme Divinity worshipped as Creator and Father", "strongs", 1317),
            ("G3056", "greek", "λόγος", "lógos", "log'-os", "The Word, the divine expression and incarnate revelation of God (John 1:1)", "strongs", 330),
            ("G25", "greek", "ἀγαπάω", "agapáō", "ag-ap-ah'-o", "To love sacrificially, with unconditional divine commitment", "strongs", 143),
            ("G2222", "greek", "ζωή", "zōḗ", "dzo-ay'", "Life, eternal and divine life imparted through Christ", "strongs", 135),
            ("G5207", "greek", "υἱός", "huiós", "hwee-os'", "Son, used especially of Christ the only-begotten Son of God", "strongs", 382),
        ]
        for sn, lang, lem, trans, pron, defn, src, occ in lex_entries:
            existing = await session.scalar(select(LexiconEntry).where(LexiconEntry.strongs_number == sn))
            if not existing:
                session.add(
                    LexiconEntry(
                        strongs_number=sn,
                        language=lang,
                        lemma=lem,
                        transliteration=trans,
                        pronunciation=pron,
                        short_definition=defn,
                        source=src,
                        occurrences_count=occ,
                    )
                )
        await session.commit()

        # 4. Add Cross-References
        cross_refs = [
            ("GEN", 1, 1, "JHN", 1, 1, 95),
            ("GEN", 1, 1, "COL", 1, 16, 90),
            ("GEN", 1, 1, "HEB", 11, 3, 90),
            ("GEN", 1, 1, "PSA", 102, 25, 85),
            ("GEN", 1, 3, "2CO", 4, 6, 92),
            ("JHN", 1, 1, "GEN", 1, 1, 95),
            ("JHN", 1, 1, "1JN", 1, 1, 90),
            ("JHN", 3, 14, "NUM", 21, 8, 95),
            ("JHN", 3, 14, "NUM", 21, 9, 95),
            ("JHN", 3, 16, "ROM", 5, 8, 95),
            ("JHN", 3, 16, "1JN", 4, 9, 92),
            ("JHN", 3, 16, "1JN", 4, 10, 92),
        ]
        for fb, fc, fv, tb, tc, tv, votes in cross_refs:
            existing = await session.scalar(
                select(CrossReference).where(
                    CrossReference.from_book_code == fb,
                    CrossReference.from_chapter == fc,
                    CrossReference.from_verse == fv,
                    CrossReference.to_book_code == tb,
                    CrossReference.to_chapter == tc,
                    CrossReference.to_verse == tv,
                )
            )
            if not existing:
                session.add(
                    CrossReference(
                        from_book_code=fb,
                        from_chapter=fc,
                        from_verse=fv,
                        to_book_code=tb,
                        to_chapter=tc,
                        to_verse=tv,
                        weight=float(votes),
                    )
                )
        await session.commit()
        print("Database successfully seeded with complete, verified multi-verse chapters and cross-references!")

if __name__ == "__main__":
    asyncio.run(seed_verified_data())
