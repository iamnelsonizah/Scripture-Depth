import json
import os
import re
import urllib.request
from dataclasses import dataclass
from typing import Iterator, Optional

# Public domain OpenScriptures Strong's Concordance mirrors
LEXICON_URLS = {
    "greek": "https://raw.githubusercontent.com/openscriptures/strongs/master/greek/strongs-greek-dictionary.js",
    "hebrew": "https://raw.githubusercontent.com/openscriptures/strongs/master/hebrew/strongs-hebrew-dictionary.js",
}


@dataclass
class ParsedLexiconEntry:
    strongs_number: str
    language: str
    lemma: str
    transliteration: Optional[str]
    pronunciation: Optional[str]
    short_definition: str
    long_definition: Optional[str]
    source: str = "strongs"
    occurrences_count: int = 0


class LexiconParser:
    def __init__(self, language: str = "greek"):
        self.language = language.lower()  # 'greek' or 'hebrew'
        self.prefix = "G" if self.language == "greek" else "H"

    def download_lexicon(self, dest_dir: str = "ingestion/data") -> str:
        """Downloads the Strong's dictionary file."""
        os.makedirs(dest_dir, exist_ok=True)
        target_path = os.path.join(dest_dir, f"strongs_{self.language}.js")

        if os.path.exists(target_path) and os.path.getsize(target_path) > 1000:
            print(f"Lexicon already downloaded: {target_path}")
            return target_path

        url = LEXICON_URLS.get(self.language)
        if not url:
            raise ValueError(f"No lexicon source configured for {self.language}")

        print(f"Downloading Strong's {self.language.title()} dictionary from {url}...")
        urllib.request.urlretrieve(url, target_path)
        print(f"Saved to {target_path} ({os.path.getsize(target_path) // 1024} KB)")
        return target_path

    def parse_file(self, file_path: str) -> Iterator[ParsedLexiconEntry]:
        """
        Parses Strong's JS/JSON dictionary into normalized ParsedLexiconEntry stream.
        """
        with open(file_path, "r", encoding="utf-8") as f:
            raw_text = f.read()

        # Extract JSON object between first { and last }
        start_idx = raw_text.find("{")
        end_idx = raw_text.rfind("}")
        if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
            json_text = raw_text[start_idx : end_idx + 1]
        else:
            json_text = raw_text

        data = json.loads(json_text)

        for key, entry in data.items():
            strongs_num = key.strip().upper()
            if not (strongs_num.startswith("G") or strongs_num.startswith("H")):
                strongs_num = f"{self.prefix}{strongs_num}"

            lemma = entry.get("lemma") or entry.get("word") or ""
            translit = entry.get("translit") or entry.get("xlit") or entry.get("transliteration")
            pron = entry.get("pron") or entry.get("pronunciation")
            short_def = entry.get("strongs_def") or entry.get("definition") or entry.get("kjv_def") or ""
            long_def = entry.get("kjv_def") or entry.get("derivation")

            yield ParsedLexiconEntry(
                strongs_number=strongs_num,
                language=self.language,
                lemma=lemma.strip(),
                transliteration=translit.strip() if translit else None,
                pronunciation=pron.strip() if pron else None,
                short_definition=short_def.strip(),
                long_definition=long_def.strip() if long_def else None,
                source="strongs",
                occurrences_count=0,
            )
