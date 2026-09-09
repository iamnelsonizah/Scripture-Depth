"""
Complete Bible & Concordance Ingestion Script for ScriptureDepth.

Ingests:
1. All 66 books of KJV with Strong's tags (31,102 verses) from kaiserlik/kjv repo
2. All 66 books of ASV (31,102 verses) from scrollmapper JSON
3. Complete Strong's Hebrew & Greek Lexicon (~14,000 entries) from merged sources
4. Treasury of Scripture Knowledge cross-references from OpenBible.info

Usage:
    cd /Users/nelsonizah/Developer/Projects/bible
    backend/.venv/bin/python -m ingestion.ingest_complete_bible
"""
import asyncio
import json
import os
import re
import html
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, text
from app.core.database import AsyncSessionLocal, engine
from app.models.base import Base
from app.models.scripture import Translation, Verse
from app.models.lexicon import LexiconEntry
from app.models.reference import CrossReference
from ingestion.parsers.book_names import normalize_book

# ─── Book Code Mappings ──────────────────────────────────────────────────────

FILE_TO_BOOK_CODE = {
    'Gen': 'GEN', 'Exo': 'EXO', 'Lev': 'LEV', 'Num': 'NUM', 'Deu': 'DEU',
    'Jos': 'JOS', 'Jdg': 'JDG', 'Rth': 'RUT', '1Sa': '1SA', '2Sa': '2SA',
    '1Ki': '1KI', '2Ki': '2KI', '1Ch': '1CH', '2Ch': '2CH', 'Ezr': 'EZR',
    'Neh': 'NEH', 'Est': 'EST', 'Job': 'JOB', 'Psa': 'PSA', 'Pro': 'PRO',
    'Ecc': 'ECC', 'Sng': 'SNG', 'Isa': 'ISA', 'Jer': 'JER', 'Lam': 'LAM',
    'Eze': 'EZK', 'Dan': 'DAN', 'Hos': 'HOS', 'Joe': 'JOL', 'Amo': 'AMO',
    'Oba': 'OBA', 'Jon': 'JON', 'Mic': 'MIC', 'Nah': 'NAM', 'Hab': 'HAB',
    'Zep': 'ZEP', 'Hag': 'HAG', 'Zec': 'ZEC', 'Mal': 'MAL',
    'Mat': 'MAT', 'Mar': 'MRK', 'Luk': 'LUK', 'Jhn': 'JHN', 'Act': 'ACT',
    'Rom': 'ROM', '1Co': '1CO', '2Co': '2CO', 'Gal': 'GAL', 'Eph': 'EPH',
    'Phl': 'PHP', 'Col': 'COL', '1Th': '1TH', '2Th': '2TH', '1Ti': '1TI',
    '2Ti': '2TI', 'Tit': 'TIT', 'Phm': 'PHM', 'Heb': 'HEB', 'Jas': 'JAS',
    '1Pe': '1PE', '2Pe': '2PE', '1Jo': '1JN', '2Jo': '2JN', '3Jo': '3JN',
    'Jde': 'JUD', 'Rev': 'REV',
}

FILE_TO_BOOK_NAME = {
    'Gen': 'Genesis', 'Exo': 'Exodus', 'Lev': 'Leviticus', 'Num': 'Numbers', 'Deu': 'Deuteronomy',
    'Jos': 'Joshua', 'Jdg': 'Judges', 'Rth': 'Ruth', '1Sa': '1 Samuel', '2Sa': '2 Samuel',
    '1Ki': '1 Kings', '2Ki': '2 Kings', '1Ch': '1 Chronicles', '2Ch': '2 Chronicles', 'Ezr': 'Ezra',
    'Neh': 'Nehemiah', 'Est': 'Esther', 'Job': 'Job', 'Psa': 'Psalms', 'Pro': 'Proverbs',
    'Ecc': 'Ecclesiastes', 'Sng': 'Song of Songs', 'Isa': 'Isaiah', 'Jer': 'Jeremiah', 'Lam': 'Lamentations',
    'Eze': 'Ezekiel', 'Dan': 'Daniel', 'Hos': 'Hosea', 'Joe': 'Joel', 'Amo': 'Amos',
    'Oba': 'Obadiah', 'Jon': 'Jonah', 'Mic': 'Micah', 'Nah': 'Nahum', 'Hab': 'Habakkuk',
    'Zep': 'Zephaniah', 'Hag': 'Haggai', 'Zec': 'Zechariah', 'Mal': 'Malachi',
    'Mat': 'Matthew', 'Mar': 'Mark', 'Luk': 'Luke', 'Jhn': 'John', 'Act': 'Acts',
    'Rom': 'Romans', '1Co': '1 Corinthians', '2Co': '2 Corinthians', 'Gal': 'Galatians', 'Eph': 'Ephesians',
    'Phl': 'Philippians', 'Col': 'Colossians', '1Th': '1 Thessalonians', '2Th': '2 Thessalonians',
    '1Ti': '1 Timothy', '2Ti': '2 Timothy', 'Tit': 'Titus', 'Phm': 'Philemon', 'Heb': 'Hebrews',
    'Jas': 'James', '1Pe': '1 Peter', '2Pe': '2 Peter', '1Jo': '1 John', '2Jo': '2 John',
    '3Jo': '3 John', 'Jde': 'Jude', 'Rev': 'Revelation',
}

# Cross-reference book abbreviation map (OpenBible.info format)
XREF_BOOK_MAP = {
    'Gen': 'GEN', 'Exod': 'EXO', 'Lev': 'LEV', 'Num': 'NUM', 'Deut': 'DEU',
    'Josh': 'JOS', 'Judg': 'JDG', 'Ruth': 'RUT', '1Sam': '1SA', '2Sam': '2SA',
    '1Kgs': '1KI', '2Kgs': '2KI', '1Chr': '1CH', '2Chr': '2CH', 'Ezra': 'EZR',
    'Neh': 'NEH', 'Esth': 'EST', 'Job': 'JOB', 'Ps': 'PSA', 'Prov': 'PRO',
    'Eccl': 'ECC', 'Song': 'SNG', 'Isa': 'ISA', 'Jer': 'JER', 'Lam': 'LAM',
    'Ezek': 'EZK', 'Dan': 'DAN', 'Hos': 'HOS', 'Joel': 'JOL', 'Amos': 'AMO',
    'Obad': 'OBA', 'Jonah': 'JON', 'Mic': 'MIC', 'Nah': 'NAM', 'Hab': 'HAB',
    'Zeph': 'ZEP', 'Hag': 'HAG', 'Zech': 'ZEC', 'Mal': 'MAL',
    'Matt': 'MAT', 'Mark': 'MRK', 'Luke': 'LUK', 'John': 'JHN', 'Acts': 'ACT',
    'Rom': 'ROM', '1Cor': '1CO', '2Cor': '2CO', 'Gal': 'GAL', 'Eph': 'EPH',
    'Phil': 'PHP', 'Col': 'COL', '1Thess': '1TH', '2Thess': '2TH', '1Tim': '1TI',
    '2Tim': '2TI', 'Titus': 'TIT', 'Phlm': 'PHM', 'Heb': 'HEB', 'Jas': 'JAS',
    '1Pet': '1PE', '2Pet': '2PE', '1John': '1JN', '2John': '2JN', '3John': '3JN',
    'Jude': 'JUD', 'Rev': 'REV',
}

STRONGS_REPO = "ingestion/data/kjv_strongs_repo"
ASV_FILE = "ingestion/data/asv.json"
KJV_FILE = "ingestion/data/kjv.json"
LEXICON_FILE = "ingestion/data/kjv_strongs_repo/lexicon.json"
STRONGS_HEBREW_FILE = "ingestion/data/strongs_hebrew.js"
STRONGS_GREEK_FILE = "ingestion/data/strongs_greek.js"
XREF_FILE = "ingestion/data/cross_references.txt"

BATCH_SIZE = 500


def strip_strongs_tags(tagged_text: str) -> str:
    """Remove Strong's number tags like [H430] and HTML <em> tags from text."""
    cleaned = re.sub(r'\[([HG]\d+)\]', '', tagged_text)
    cleaned = re.sub(r'</?em>', '', cleaned)
    cleaned = html.unescape(cleaned)
    # Clean up double spaces
    cleaned = re.sub(r'  +', ' ', cleaned).strip()
    return cleaned


def parse_strongs_js(file_path: str) -> dict:
    """Parse Strong's Hebrew/Greek .js file into a dict."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    # Find the first '{' that starts the JSON object
    brace_idx = content.find('{')
    if brace_idx < 0:
        return {}
    json_str = content[brace_idx:]
    # The file may have trailing content; find the matching closing brace
    depth = 0
    end_idx = 0
    for i, ch in enumerate(json_str):
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                end_idx = i + 1
                break
    json_str = json_str[:end_idx]
    try:
        return json.loads(json_str)
    except json.JSONDecodeError:
        print(f"  Warning: Could not parse {file_path}")
        return {}


def parse_occurrence_count(occ_str: str) -> int:
    """Parse occurrence string like 'God(1320x), god(13x)...' into total count."""
    if not occ_str:
        return 0
    nums = re.findall(r'\((\d+)x\)', occ_str)
    # Deduplicate: the lexicon.json often duplicates the list
    half = len(nums) // 2
    if half > 0 and nums[:half] == nums[half:]:
        nums = nums[:half]
    return sum(int(n) for n in nums)


def parse_xref_verse(ref: str):
    """Parse 'Gen.1.1' or 'John.1.1-John.1.3' into (book_code, chapter, verse) or None."""
    # Take just the start of a range
    ref = ref.split('-')[0].strip()
    parts = ref.split('.')
    if len(parts) < 3:
        return None
    book_abbr = parts[0]
    try:
        chapter = int(parts[1])
        verse = int(parts[2])
    except ValueError:
        return None
    book_code = XREF_BOOK_MAP.get(book_abbr)
    if not book_code:
        # Try normalize_book fallback
        name, code, _, _ = normalize_book(book_abbr)
        book_code = code if code else None
    if not book_code:
        return None
    return (book_code, chapter, verse)


# ─── Fallback Parser for Malformed JSON ──────────────────────────────────────

def _parse_english_only(raw: str, file_code: str) -> dict:
    """
    Fallback parser for repo JSON files with broken non-English text.
    Extracts only the English verse text and Strong's tags using regex.
    """
    result = {}
    # Match patterns like "Gen|1|1": { ... "en": "..." ...}
    # The verse key pattern: "BookCode|Chapter|Verse"
    verse_pattern = re.compile(
        r'"([^"]+\|(\d+)\|(\d+))"\s*:\s*\{[^}]*?"en"\s*:\s*"((?:[^"\\]|\\.)*)"\s*',
        re.DOTALL
    )
    for match in verse_pattern.finditer(raw):
        full_key = match.group(1)
        chapter = int(match.group(2))
        verse = int(match.group(3))
        en_text = match.group(4)

        # Build the chapter key
        parts = full_key.split('|')
        if len(parts) >= 2:
            ch_key = f"{parts[0]}|{chapter}"
        else:
            ch_key = f"{file_code}|{chapter}"

        book_key = parts[0] if parts else file_code

        if book_key not in result:
            result[book_key] = {}
        if ch_key not in result[book_key]:
            result[book_key][ch_key] = {}
        result[book_key][ch_key][full_key] = {'en': en_text}

    if result:
        print(f"    (Used regex fallback for {file_code}: found {sum(len(ch) for ch in result.get(list(result.keys())[0], {}).values())} verses)")
    return result


# ─── Ingestion Functions ─────────────────────────────────────────────────────

async def ingest_kjv_strongs(session: AsyncSession):
    """Ingest all 66 books of KJV with Strong's tags."""
    print("\n═══ Ingesting KJV with Strong's Numbers (66 books) ═══")

    # Clear existing KJV and WEB verses
    await session.execute(delete(Verse).where(Verse.translation_id.in_(['kjv', 'web'])))
    await session.commit()

    total_verses = 0
    book_files = sorted([f for f in os.listdir(STRONGS_REPO) if f.endswith('.json') and f != 'books.json' and f != 'chapter_count.json' and f != 'lexicon.json'])

    for book_file in book_files:
        file_code = book_file.replace('.json', '')
        book_code = FILE_TO_BOOK_CODE.get(file_code)
        book_name = FILE_TO_BOOK_NAME.get(file_code)
        if not book_code or not book_name:
            continue

        file_path = os.path.join(STRONGS_REPO, book_file)
        with open(file_path, 'r', encoding='utf-8') as f:
            raw = f.read()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            # Some files have unescaped quotes in non-English text; extract only English verses
            data = _parse_english_only(raw, file_code)

        # The top-level key may be the file code ('Gen') or full name ('1 Chronicles')
        book_data = data.get(file_code) or data.get(book_name) or (data.get(list(data.keys())[0]) if data else {})
        book_verse_count = 0
        batch = []

        for ch_key, ch_data in book_data.items():
            # ch_key like "Gen|1"
            parts = ch_key.split('|')
            if len(parts) < 2:
                continue
            try:
                chapter_num = int(parts[1])
            except ValueError:
                continue

            for v_key, v_data in ch_data.items():
                # v_key like "Gen|1|1"
                v_parts = v_key.split('|')
                if len(v_parts) < 3:
                    continue
                try:
                    verse_num = int(v_parts[2])
                except ValueError:
                    continue

                en_text = v_data.get('en', '')
                if not en_text:
                    continue

                strongs_text = re.sub(r'</?em>', '', en_text)
                strongs_text = html.unescape(strongs_text)
                clean_text = strip_strongs_tags(en_text)

                batch.append(Verse(
                    translation_id='kjv',
                    book=book_name,
                    book_code=book_code,
                    chapter=chapter_num,
                    verse=verse_num,
                    text=clean_text,
                    strongs_text=strongs_text,
                ))
                book_verse_count += 1

                if len(batch) >= BATCH_SIZE:
                    session.add_all(batch)
                    await session.commit()
                    batch = []

        if batch:
            session.add_all(batch)
            await session.commit()

        print(f"  ✓ {book_name}: {book_verse_count} verses")
        total_verses += book_verse_count

    # Also duplicate KJV to WEB translation
    print(f"\n  Duplicating KJV → WEB translation...")
    result = await session.execute(select(Verse).where(Verse.translation_id == 'kjv'))
    kjv_verses = result.scalars().all()
    batch = []
    for v in kjv_verses:
        batch.append(Verse(
            translation_id='web',
            book=v.book,
            book_code=v.book_code,
            chapter=v.chapter,
            verse=v.verse,
            text=v.text,
            strongs_text=v.strongs_text,
        ))
        if len(batch) >= BATCH_SIZE:
            session.add_all(batch)
            await session.commit()
            batch = []
    if batch:
        session.add_all(batch)
        await session.commit()
    print(f"  ✓ WEB: {len(kjv_verses)} verses (copied from KJV)")

    print(f"\n  ══ Total KJV verses ingested: {total_verses}")
    return total_verses


async def ingest_asv(session: AsyncSession):
    """Ingest all 66 books of ASV from scrollmapper JSON."""
    print("\n═══ Ingesting ASV (American Standard Version) ═══")

    await session.execute(delete(Verse).where(Verse.translation_id == 'asv'))
    await session.commit()

    if not os.path.exists(ASV_FILE):
        print(f"  ✗ ASV file not found: {ASV_FILE}")
        return 0

    with open(ASV_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)

    total_verses = 0
    batch = []

    if 'books' in data and isinstance(data['books'], list):
        for book_obj in data['books']:
            raw_book = book_obj.get('name', '')
            book_name, book_code, _, _ = normalize_book(raw_book)
            book_verse_count = 0

            for ch_obj in book_obj.get('chapters', []):
                try:
                    ch_num = int(ch_obj.get('chapter', 1))
                except ValueError:
                    continue
                for v_obj in ch_obj.get('verses', []):
                    try:
                        v_num = int(v_obj.get('verse', 1))
                    except ValueError:
                        continue
                    v_text = v_obj.get('text', '').strip()
                    if not v_text:
                        continue

                    batch.append(Verse(
                        translation_id='asv',
                        book=book_name,
                        book_code=book_code,
                        chapter=ch_num,
                        verse=v_num,
                        text=v_text,
                    ))
                    book_verse_count += 1

                    if len(batch) >= BATCH_SIZE:
                        session.add_all(batch)
                        await session.commit()
                        batch = []

            print(f"  ✓ {book_name}: {book_verse_count} verses")
            total_verses += book_verse_count

    if batch:
        session.add_all(batch)
        await session.commit()

    print(f"\n  ══ Total ASV verses ingested: {total_verses}")
    return total_verses


async def ingest_lexicon(session: AsyncSession):
    """Ingest complete Strong's Hebrew & Greek lexicon from merged sources."""
    print("\n═══ Ingesting Strong's Concordance Lexicon ═══")

    await session.execute(delete(LexiconEntry))
    await session.commit()

    # 1. Load primary lexicon from kjv_strongs_repo/lexicon.json
    with open(LEXICON_FILE, 'r', encoding='utf-8') as f:
        primary = json.load(f)
    print(f"  Loaded {len(primary)} entries from lexicon.json")

    # 2. Load supplementary data from strongs_hebrew.js and strongs_greek.js
    hebrew_sup = parse_strongs_js(STRONGS_HEBREW_FILE) if os.path.exists(STRONGS_HEBREW_FILE) else {}
    greek_sup = parse_strongs_js(STRONGS_GREEK_FILE) if os.path.exists(STRONGS_GREEK_FILE) else {}
    print(f"  Loaded {len(hebrew_sup)} Hebrew + {len(greek_sup)} Greek supplementary entries")

    supplementary = {**hebrew_sup, **greek_sup}

    total = 0
    batch = []

    for strongs_num, entry in primary.items():
        is_greek = strongs_num.startswith('G')
        is_hebrew = strongs_num.startswith('H')
        if not (is_greek or is_hebrew):
            continue

        language = 'greek' if is_greek else 'hebrew'
        lemma = entry.get('Gk_word', '') if is_greek else entry.get('Hb_word', '')
        transliteration = entry.get('transliteration', '')
        strongs_def = html.unescape(entry.get('strongs_def', '')) if entry.get('strongs_def') else ''
        part_of_speech = entry.get('part_of_speech', '')
        root_word = entry.get('root_word', '')
        occurrences = entry.get('occurrences', '')
        outline = html.unescape(entry.get('outline_usage', '')) if entry.get('outline_usage') else ''

        occ_count = parse_occurrence_count(occurrences)

        # Enrich from supplementary JS data
        sup = supplementary.get(strongs_num, {})
        pronunciation = sup.get('pron', '')
        derivation_text = sup.get('derivation', '')
        kjv_def = sup.get('kjv_def', '')

        # Build short definition
        short_def = strongs_def[:500] if strongs_def else (part_of_speech or 'Unknown')

        # Build long definition from outline usage
        long_def = outline if outline else None

        if not lemma:
            lemma = sup.get('lemma', strongs_num)

        batch.append(LexiconEntry(
            strongs_number=strongs_num,
            language=language,
            lemma=lemma,
            transliteration=transliteration or sup.get('xlit', '') or sup.get('translit', ''),
            pronunciation=pronunciation,
            short_definition=short_def,
            long_definition=long_def,
            source='strongs',
            occurrences_count=occ_count,
            derivation=derivation_text,
            outline_usage=outline,
            kjv_definition=kjv_def,
        ))
        total += 1

        if len(batch) >= BATCH_SIZE:
            session.add_all(batch)
            await session.commit()
            batch = []

    # Also add entries from supplementary that aren't in primary
    for strongs_num, sup in supplementary.items():
        if strongs_num in primary:
            continue
        is_greek = strongs_num.startswith('G')
        is_hebrew = strongs_num.startswith('H')
        if not (is_greek or is_hebrew):
            continue

        language = 'greek' if is_greek else 'hebrew'
        lemma = sup.get('lemma', strongs_num)
        strongs_def = sup.get('strongs_def', '')
        kjv_def = sup.get('kjv_def', '')

        batch.append(LexiconEntry(
            strongs_number=strongs_num,
            language=language,
            lemma=lemma,
            transliteration=sup.get('xlit', '') or sup.get('translit', ''),
            pronunciation=sup.get('pron', ''),
            short_definition=strongs_def[:500] if strongs_def else 'See concordance',
            long_definition=None,
            source='strongs',
            occurrences_count=0,
            derivation=sup.get('derivation', ''),
            outline_usage=None,
            kjv_definition=kjv_def,
        ))
        total += 1

        if len(batch) >= BATCH_SIZE:
            session.add_all(batch)
            await session.commit()
            batch = []

    if batch:
        session.add_all(batch)
        await session.commit()

    print(f"\n  ══ Total lexicon entries ingested: {total}")
    return total


async def ingest_cross_references(session: AsyncSession):
    """Ingest cross-references from OpenBible.info TSV file."""
    print("\n═══ Ingesting Cross-References (Treasury of Scripture Knowledge) ═══")

    await session.execute(delete(CrossReference))
    await session.commit()

    if not os.path.exists(XREF_FILE):
        print(f"  ✗ Cross-references file not found: {XREF_FILE}")
        return 0

    total = 0
    skipped = 0
    batch = []

    with open(XREF_FILE, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f):
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('From'):
                continue
            parts = line.split('\t')
            if len(parts) < 3:
                continue

            from_ref = parse_xref_verse(parts[0])
            to_ref = parse_xref_verse(parts[1])

            if not from_ref or not to_ref:
                skipped += 1
                continue

            try:
                votes = int(parts[2])
            except ValueError:
                votes = 1

            batch.append(CrossReference(
                from_book_code=from_ref[0],
                from_chapter=from_ref[1],
                from_verse=from_ref[2],
                to_book_code=to_ref[0],
                to_chapter=to_ref[1],
                to_verse=to_ref[2],
                weight=float(votes),
                ref_type='thematic',
                source='openbible',
            ))
            total += 1

            if len(batch) >= BATCH_SIZE:
                session.add_all(batch)
                await session.commit()
                batch = []

    if batch:
        session.add_all(batch)
        await session.commit()

    print(f"  ══ Total cross-references ingested: {total} (skipped {skipped})")
    return total


async def main():
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  ScriptureDepth — Complete Bible & Concordance Ingestion    ║")
    print("╚══════════════════════════════════════════════════════════════╝")

    # Create/migrate tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        # Register translations
        for tid, name, abbr in [
            ("kjv", "King James Version", "KJV"),
            ("asv", "American Standard Version", "ASV"),
            ("web", "World English Bible", "WEB"),
        ]:
            existing = await session.scalar(select(Translation).where(Translation.id == tid))
            if not existing:
                session.add(Translation(id=tid, name=name, abbreviation=abbr, language="en", license="Public Domain"))
        await session.commit()
        print("✓ Translations registered: KJV, ASV, WEB")

        # Ingest everything
        kjv_count = await ingest_kjv_strongs(session)
        asv_count = await ingest_asv(session)
        lex_count = await ingest_lexicon(session)
        xref_count = await ingest_cross_references(session)

        print("\n╔══════════════════════════════════════════════════════════════╗")
        print(f"║  INGESTION COMPLETE                                         ║")
        print(f"║  KJV verses:         {kjv_count:>8,}                              ║")
        print(f"║  ASV verses:         {asv_count:>8,}                              ║")
        print(f"║  Lexicon entries:    {lex_count:>8,}                              ║")
        print(f"║  Cross-references:   {xref_count:>8,}                              ║")
        print("╚══════════════════════════════════════════════════════════════╝")


if __name__ == "__main__":
    asyncio.run(main())
