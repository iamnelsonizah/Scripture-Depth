import asyncio
import json
import os
import sys

# Ensure backend is in python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

from sqlalchemy import select
from app.core.database import AsyncSessionLocal
from app.models.lexicon import LexiconEntry


def load_js_dict(filepath: str) -> dict:
    with open(filepath, "r", encoding="utf-8") as f:
        text = f.read()
    start_idx = text.find("{")
    end_idx = text.rfind("}")
    if start_idx != -1 and end_idx != -1:
        return json.loads(text[start_idx : end_idx + 1])
    return {}


async def main():
    print("Loading Greek and Hebrew Strong's dictionaries...")
    base_dir = os.path.dirname(__file__)
    greek_dict = load_js_dict(os.path.join(base_dir, "data", "strongs_greek.js"))
    hebrew_dict = load_js_dict(os.path.join(base_dir, "data", "strongs_hebrew.js"))
    print(f"Loaded {len(greek_dict)} Greek entries and {len(hebrew_dict)} Hebrew entries.")

    async with AsyncSessionLocal() as session:
        result = await session.execute(select(LexiconEntry))
        entries = result.scalars().all()
        print(f"Found {len(entries)} lexicon entries in database.")

        updated_count = 0
        fixed_definitions_count = 0

        for entry in entries:
            code = entry.strongs_number.upper()
            lookup = None
            if code.startswith("G"):
                lookup = greek_dict.get(code)
                if not lookup:
                    num_part = code[1:].lstrip("0")
                    lookup = greek_dict.get(f"G{num_part}")
            elif code.startswith("H"):
                lookup = hebrew_dict.get(code)
                if not lookup:
                    num_part = code[1:].lstrip("0")
                    lookup = hebrew_dict.get(f"H{num_part}")

            changed = False

            # Check if short_definition needs repair
            curr_def = (entry.short_definition or "").strip()
            if len(curr_def) <= 2 or curr_def == ".":
                new_def = None
                if lookup and lookup.get("strongs_def"):
                    clean = lookup["strongs_def"].strip()
                    if len(clean) > 2 and clean != ".":
                        new_def = clean
                if not new_def and lookup and lookup.get("kjv_def"):
                    new_def = lookup["kjv_def"].strip()
                if not new_def and entry.outline_usage:
                    first_clause = entry.outline_usage.split("\n")[0].split(";")[0].strip()
                    if len(first_clause) > 2 and first_clause != ".":
                        new_def = first_clause
                if not new_def and entry.long_definition:
                    first_clause = entry.long_definition.split("\n")[0].split(";")[0].strip()
                    if len(first_clause) > 2 and first_clause != ".":
                        new_def = first_clause

                if new_def:
                    entry.short_definition = new_def
                    fixed_definitions_count += 1
                    changed = True

            # Enrich other missing fields
            if lookup:
                if not entry.derivation and lookup.get("derivation"):
                    entry.derivation = lookup["derivation"].strip()
                    changed = True
                if not entry.kjv_definition and lookup.get("kjv_def"):
                    entry.kjv_definition = lookup["kjv_def"].strip()
                    changed = True
                if not entry.pronunciation and lookup.get("pron"):
                    entry.pronunciation = lookup["pron"].strip()
                    changed = True
                if (not entry.transliteration or len(entry.transliteration) == 0) and (lookup.get("translit") or lookup.get("xlit")):
                    entry.transliteration = (lookup.get("translit") or lookup.get("xlit")).strip()
                    changed = True

            if changed:
                updated_count += 1

        print(f"Committing updates: {updated_count} entries enriched, {fixed_definitions_count} definitions repaired...")
        await session.commit()
        print("Successfully updated database!")


if __name__ == "__main__":
    asyncio.run(main())
