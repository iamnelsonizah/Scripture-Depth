import json
import os
import urllib.request
from dataclasses import dataclass
from typing import Iterator, List, Optional
from ingestion.parsers.book_names import normalize_book

# Open-source public domain Bible repositories (JSON mirrors)
SOURCE_URLS = {
    "kjv": "https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/KJV.json",
    "asv": "https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/ASV.json",
    "bsb": "https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/BSB.json",
    "web": "https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/ASV.json",
}


@dataclass
class ParsedVerse:
    translation_id: str
    book: str
    book_code: str
    chapter: int
    verse: int
    text: str


class BibleParser:
    def __init__(self, translation_id: str = "web"):
        self.translation_id = translation_id.lower()

    def download_translation(self, dest_dir: str = "ingestion/data") -> str:
        """Downloads the open JSON dataset if not already present locally."""
        os.makedirs(dest_dir, exist_ok=True)
        target_path = os.path.join(dest_dir, f"{self.translation_id}.json")

        if os.path.exists(target_path) and os.path.getsize(target_path) > 1000:
            print(f"File already downloaded: {target_path}")
            return target_path

        url = SOURCE_URLS.get(self.translation_id)
        if not url:
            raise ValueError(f"No source URL configured for translation: {self.translation_id}")

        print(f"Downloading {self.translation_id.upper()} from {url}...")
        urllib.request.urlretrieve(url, target_path)
        print(f"Saved to {target_path} ({os.path.getsize(target_path) // 1024} KB)")
        return target_path

    def parse_file(self, file_path: str) -> Iterator[ParsedVerse]:
        """
        Parses a Bible JSON file into normalized ParsedVerse stream.
        Handles both hierarchical formats: {"books": [{"name": "Genesis", "chapters": ...}]}
        and flat verse lists.
        """
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        if isinstance(data, dict):
            # Standard scrollmapper books schema
            if "books" in data and isinstance(data["books"], list):
                for book_obj in data["books"]:
                    raw_book = book_obj.get("name") or ""
                    book_name, book_code, _, _ = normalize_book(raw_book)
                    for ch_obj in book_obj.get("chapters", []):
                        try:
                            ch_num = int(ch_obj.get("chapter", 1))
                        except ValueError:
                            continue
                        for v_obj in ch_obj.get("verses", []):
                            try:
                                v_num = int(v_obj.get("verse", 1))
                            except ValueError:
                                continue
                            yield ParsedVerse(
                                translation_id=self.translation_id,
                                book=book_name,
                                book_code=book_code,
                                chapter=ch_num,
                                verse=v_num,
                                text=str(v_obj.get("text", "")).strip(),
                            )
            elif "verses" in data and isinstance(data["verses"], list):
                for item in data["verses"]:
                    raw_book = item.get("book_name") or item.get("book") or ""
                    book_name, book_code, _, _ = normalize_book(raw_book)
                    yield ParsedVerse(
                        translation_id=self.translation_id,
                        book=book_name,
                        book_code=book_code,
                        chapter=int(item["chapter"]),
                        verse=int(item["verse"]),
                        text=item["text"].strip(),
                    )
            else:
                # Direct map book -> chapter -> verse
                for raw_book, chapters in data.items():
                    if raw_book.lower() in ("metadata", "info", "translation"):
                        continue
                    book_name, book_code, _, _ = normalize_book(raw_book)
                    if isinstance(chapters, dict):
                        for ch_str, verses in chapters.items():
                            try:
                                ch_num = int(ch_str)
                            except ValueError:
                                continue
                            if isinstance(verses, dict):
                                for v_str, text in verses.items():
                                    try:
                                        v_num = int(v_str)
                                    except ValueError:
                                        continue
                                    yield ParsedVerse(
                                        translation_id=self.translation_id,
                                        book=book_name,
                                        book_code=book_code,
                                        chapter=ch_num,
                                        verse=v_num,
                                        text=str(text).strip(),
                                    )
        elif isinstance(data, list):
            for item in data:
                raw_book = item.get("book_name") or item.get("book") or ""
                book_name, book_code, _, _ = normalize_book(raw_book)
                yield ParsedVerse(
                    translation_id=self.translation_id,
                    book=book_name,
                    book_code=book_code,
                    chapter=int(item["chapter"]),
                    verse=int(item["verse"]),
                    text=item["text"].strip(),
                )
