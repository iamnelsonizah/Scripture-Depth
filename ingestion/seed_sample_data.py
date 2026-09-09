import asyncio
import sys
import os

# Add backend directory to sys.path so we can import models and database config
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))

from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import AsyncSessionLocal, engine
from app.models.base import Base
from app.models.scripture import Translation, Verse, OriginalWord, MorphCode
from app.models.lexicon import LexiconEntry
from app.models.reference import CrossReference, CommentaryEntry
from app.models.user_data import ReadingPlan, MemorizationItem, Note


async def seed_database():
    print("Initializing database tables...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        # Check if already seeded
        from sqlalchemy import select
        res = await session.execute(select(Translation).where(Translation.id == "web"))
        if res.scalar_one_or_none() is not None:
            print("Database already seeded with 'web' translation. Skipping seed.")
            return

        print("Seeding translations...")
        web = Translation(
            id="web",
            name="World English Bible",
            abbreviation="WEB",
            language="en",
            license="Public Domain",
            source_url="https://worldenglish.bible/",
        )
        session.add(web)
        await session.flush()

        print("Seeding morphology codes...")
        morphs = [
            MorphCode(
                code="V-AAI-3S",
                language="greek",
                description="Verb, Aorist Active Indicative, 3rd Person Singular",
                part_of_speech="Verb",
                tense="Aorist",
                voice="Active",
                mood="Indicative",
                person="3rd",
                number="Singular",
            ),
            MorphCode(
                code="N-NSM",
                language="greek",
                description="Noun, Nominative Singular Masculine",
                part_of_speech="Noun",
                case="Nominative",
                number="Singular",
                gender="Masculine",
            ),
            MorphCode(
                code="N-ASM",
                language="greek",
                description="Noun, Accusative Singular Masculine",
                part_of_speech="Noun",
                case="Accusative",
                number="Singular",
                gender="Masculine",
            ),
            MorphCode(
                code="N-ASF",
                language="greek",
                description="Noun, Accusative Singular Feminine",
                part_of_speech="Noun",
                case="Accusative",
                number="Singular",
                gender="Feminine",
            ),
            MorphCode(
                code="N-NSF",
                language="greek",
                description="Noun, Nominative Singular Feminine",
                part_of_speech="Noun",
                case="Nominative",
                number="Singular",
                gender="Feminine",
            ),
        ]
        session.add_all(morphs)

        print("Seeding Strong's lexicon entries...")
        lexicon = [
            LexiconEntry(
                strongs_number="G25",
                language="greek",
                lemma="ἀγαπάω",
                transliteration="agapaō",
                pronunciation="ag-ap-ah'-o",
                short_definition="to love, cherish, have affection for; self-giving, deliberate committed love.",
                long_definition="To love with deep personal commitment and goodwill. Used especially in Christian thought of God's unconditional love towards humanity, and the reciprocal love believers show to God and others.",
                source="strongs",
                occurrences_count=143,
            ),
            LexiconEntry(
                strongs_number="G26",
                language="greek",
                lemma="ἀγάπη",
                transliteration="agapē",
                pronunciation="ag-ah'-pay",
                short_definition="love, benevolence, goodwill; self-giving, willed love.",
                long_definition="Brotherly love, affection, goodwill, love feasts. Distinct from mere emotional affection (philia) or physical passion (eros).",
                source="strongs",
                occurrences_count=116,
            ),
            LexiconEntry(
                strongs_number="G2316",
                language="greek",
                lemma="θεός",
                transliteration="theos",
                pronunciation="theh'-os",
                short_definition="God, the supreme Divinity, the one true God.",
                long_definition="The deity, especially the supreme Divinity; spoken of the only true God of the scriptures.",
                source="strongs",
                occurrences_count=1317,
            ),
            LexiconEntry(
                strongs_number="G5207",
                language="greek",
                lemma="υἱός",
                transliteration="huios",
                pronunciation="hwee-os'",
                short_definition="a son, descendant; the unique divine Son.",
                long_definition="A son (by birth or adoption, figuratively or literally); used uniquely of Jesus as the Son of God sharing the Father's character and authority.",
                source="strongs",
                occurrences_count=382,
            ),
            LexiconEntry(
                strongs_number="G2222",
                language="greek",
                lemma="ζωή",
                transliteration="zōē",
                pronunciation="dzo-ay'",
                short_definition="life; both of physical life and spiritual/eternal life in God.",
                long_definition="Life, whether physical or transcendent and eternal. In John's writings, zōē refers essentially to divine, incorruptible life communicating fellowship with God.",
                source="strongs",
                occurrences_count=135,
            ),
            LexiconEntry(
                strongs_number="G5485",
                language="greek",
                lemma="χάρις",
                transliteration="charis",
                pronunciation="khar'-ece",
                short_definition="grace, divine favor, goodwill, unmerited gift.",
                long_definition="Grace, favor, kindness. Specifically the unmerited favor of God in conferring salvation and spiritual blessing upon undeserving sinners through Jesus Christ.",
                source="strongs",
                occurrences_count=155,
            ),
        ]
        session.add_all(lexicon)

        print("Seeding verses...")
        verses = [
            Verse(
                translation_id="web",
                book="John",
                book_code="JHN",
                chapter=3,
                verse=14,
                text="As Moses lifted up the serpent in the wilderness, even so must the Son of Man be lifted up,",
            ),
            Verse(
                translation_id="web",
                book="John",
                book_code="JHN",
                chapter=3,
                verse=15,
                text="that whoever believes in him should not perish, but have eternal life.",
            ),
            Verse(
                translation_id="web",
                book="John",
                book_code="JHN",
                chapter=3,
                verse=16,
                text="For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life.",
            ),
            Verse(
                translation_id="web",
                book="John",
                book_code="JHN",
                chapter=3,
                verse=17,
                text="For God didn't send his Son into the world to judge the world, but that the world should be saved through him.",
            ),
            # Key thematic verses for search
            Verse(
                translation_id="web",
                book="Ephesians",
                book_code="EPH",
                chapter=2,
                verse=8,
                text="For by grace you have been saved through faith, and that not of yourselves; it is the gift of God,",
            ),
            Verse(
                translation_id="web",
                book="Titus",
                book_code="TIT",
                chapter=2,
                verse=11,
                text="For the grace of God has appeared, bringing salvation to all people,",
            ),
            Verse(
                translation_id="web",
                book="Romans",
                book_code="ROM",
                chapter=3,
                verse=24,
                text="being justified freely by his grace through the redemption that is in Christ Jesus,",
            ),
            Verse(
                translation_id="web",
                book="2 Corinthians",
                book_code="2CO",
                chapter=12,
                verse=9,
                text="He has said to me, 'My grace is sufficient for you, for my power is made perfect in weakness.'",
            ),
            Verse(
                translation_id="web",
                book="James",
                book_code="JAS",
                chapter=4,
                verse=6,
                text="But he gives more grace. Therefore it says, 'God resists the proud, but gives grace to the humble.'",
            ),
        ]
        session.add_all(verses)

        print("Seeding original Greek words for John 3:16...")
        orig_words = [
            OriginalWord(
                book_code="JHN",
                chapter=3,
                verse=16,
                word_position=1,
                surface_form="οὕτως",
                lemma="οὕτω",
                transliteration="houtōs",
                strongs_number="G3779",
                morph_code="ADV",
                language="greek",
                english_gloss="so",
            ),
            OriginalWord(
                book_code="JHN",
                chapter=3,
                verse=16,
                word_position=2,
                surface_form="γὰρ",
                lemma="γάρ",
                transliteration="gar",
                strongs_number="G1063",
                morph_code="CONJ",
                language="greek",
                english_gloss="for",
            ),
            OriginalWord(
                book_code="JHN",
                chapter=3,
                verse=16,
                word_position=3,
                surface_form="ἠγάπησεν",
                lemma="ἀγαπάω",
                transliteration="ēgápēsen",
                strongs_number="G25",
                morph_code="V-AAI-3S",
                language="greek",
                english_gloss="loved",
            ),
            OriginalWord(
                book_code="JHN",
                chapter=3,
                verse=16,
                word_position=4,
                surface_form="ὁ",
                lemma="ὁ",
                transliteration="ho",
                strongs_number="G3588",
                morph_code="T-NSM",
                language="greek",
                english_gloss="the",
            ),
            OriginalWord(
                book_code="JHN",
                chapter=3,
                verse=16,
                word_position=5,
                surface_form="θεὸς",
                lemma="θεός",
                transliteration="theós",
                strongs_number="G2316",
                morph_code="N-NSM",
                language="greek",
                english_gloss="God",
            ),
            OriginalWord(
                book_code="JHN",
                chapter=3,
                verse=16,
                word_position=6,
                surface_form="τὸν",
                lemma="ὁ",
                transliteration="ton",
                strongs_number="G3588",
                morph_code="T-ASM",
                language="greek",
                english_gloss="the",
            ),
            OriginalWord(
                book_code="JHN",
                chapter=3,
                verse=16,
                word_position=7,
                surface_form="κόσμον",
                lemma="κόσμος",
                transliteration="kosmon",
                strongs_number="G2889",
                morph_code="N-ASM",
                language="greek",
                english_gloss="world",
            ),
            OriginalWord(
                book_code="JHN",
                chapter=3,
                verse=16,
                word_position=8,
                surface_form="υἱὸν",
                lemma="υἱός",
                transliteration="huiós",
                strongs_number="G5207",
                morph_code="N-ASM",
                language="greek",
                english_gloss="Son",
            ),
            OriginalWord(
                book_code="JHN",
                chapter=3,
                verse=16,
                word_position=9,
                surface_form="ζωὴν",
                lemma="ζωή",
                transliteration="zōḗn",
                strongs_number="G2222",
                morph_code="N-ASF",
                language="greek",
                english_gloss="life",
            ),
        ]
        session.add_all(orig_words)

        print("Seeding cross references...")
        cross_refs = [
            CrossReference(
                from_book_code="JHN",
                from_chapter=3,
                from_verse=16,
                to_book_code="ROM",
                to_chapter=5,
                to_verse=8,
                ref_type="thematic",
                weight=98.5,
            ),
            CrossReference(
                from_book_code="JHN",
                from_chapter=3,
                from_verse=16,
                to_book_code="1JN",
                to_chapter=4,
                to_verse=9,
                ref_type="thematic",
                weight=96.2,
            ),
            CrossReference(
                from_book_code="JHN",
                from_chapter=3,
                from_verse=16,
                to_book_code="EPH",
                to_chapter=2,
                to_verse=8,
                ref_type="thematic",
                weight=88.4,
            ),
        ]
        session.add_all(cross_refs)

        print("Seeding reading plan & sample memory items...")
        plan = ReadingPlan(
            id="gospel_of_john_30d",
            title="The Gospel of John",
            description="30-day journey exploring the signs, 'I Am' statements, and original Greek depth of John's gospel.",
            duration_days=30,
            structure_json='{"day": 12, "reading": "John 3", "description": "Nicodemus and the New Birth"}',
        )
        session.add(plan)

        # Sample memorization item
        item = MemorizationItem(
            user_id="dev-user-1",
            book_code="JHN",
            chapter=3,
            verse=16,
            verse_text="For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life.",
            interval_days=3,
            repetitions=2,
        )
        session.add(item)

        await session.commit()
        print("Database seeded successfully!")


if __name__ == "__main__":
    asyncio.run(seed_database())
