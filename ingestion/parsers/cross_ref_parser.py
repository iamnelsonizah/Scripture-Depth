import os
import urllib.request
import zipfile
from dataclasses import dataclass
from typing import Iterator, Optional
from ingestion.parsers.book_names import normalize_book

CROSS_REF_ZIP_URL = "https://a.openbible.info/data/cross-references.zip"


@dataclass
class ParsedCrossRef:
    from_book_code: str
    from_chapter: int
    from_verse: int
    to_book_code: str
    to_chapter: int
    to_verse: int
    weight: float
    ref_type: str = "thematic"
    source: str = "openbible"


class CrossRefParser:
    def download_data(self, dest_dir: str = "ingestion/data") -> str:
        """Downloads and extracts the cross-reference dataset."""
        os.makedirs(dest_dir, exist_ok=True)
        txt_path = os.path.join(dest_dir, "cross_references.txt")

        if os.path.exists(txt_path) and os.path.getsize(txt_path) > 1000:
            print(f"Cross-reference dataset already downloaded: {txt_path}")
            return txt_path

        zip_path = os.path.join(dest_dir, "cross-references.zip")
        print(f"Downloading cross-references from {CROSS_REF_ZIP_URL}...")
        try:
            # Set custom User-Agent to comply with standard HTTP servers
            req = urllib.request.Request(
                CROSS_REF_ZIP_URL,
                headers={"User-Agent": "ScriptureDepth-Ingest/1.0"},
            )
            with urllib.request.urlopen(req) as resp, open(zip_path, "wb") as out_f:
                out_f.write(resp.read())

            print(f"Extracting {zip_path}...")
            with zipfile.ZipFile(zip_path, "r") as zip_ref:
                zip_ref.extractall(dest_dir)

            # Find extracted txt file
            for fname in os.listdir(dest_dir):
                if fname.endswith(".txt") and "cross" in fname.lower():
                    extracted_path = os.path.join(dest_dir, fname)
                    if extracted_path != txt_path:
                        os.replace(extracted_path, txt_path)
                    break

            print(f"Saved to {txt_path} ({os.path.getsize(txt_path) // 1024} KB)")
        except Exception as e:
            print(f"Notice: Cross-reference download failed: {e}")
        return txt_path

    def parse_file(self, file_path: str, max_items: Optional[int] = None) -> Iterator[ParsedCrossRef]:
        """
        Parses TSV cross references:
        From_Verse \t To_Verse \t Votes
        e.g., Matt.1.1 \t Luke.3.23 \t 95
        """
        if not os.path.exists(file_path):
            return

        count = 0
        with open(file_path, "r", encoding="utf-8") as f:
            for line in f:
                if max_items and count >= max_items:
                    break

                parts = line.strip().split("\t")
                if len(parts) < 2:
                    continue

                from_ref = parts[0].strip()
                to_ref = parts[1].strip()
                votes = 1.0
                if len(parts) > 2:
                    try:
                        votes = float(parts[2].strip())
                    except ValueError:
                        votes = 1.0

                from_parsed = self._parse_verse_key(from_ref)
                to_parsed = self._parse_verse_key(to_ref)

                if from_parsed and to_parsed:
                    count += 1
                    yield ParsedCrossRef(
                        from_book_code=from_parsed[0],
                        from_chapter=from_parsed[1],
                        from_verse=from_parsed[2],
                        to_book_code=to_parsed[0],
                        to_chapter=to_parsed[1],
                        to_verse=to_parsed[2],
                        weight=votes,
                    )

    def _parse_verse_key(self, ref_str: str):
        # Format: 'Matt.1.1' or '1Jn.4.9' or 'Gen.1.1'
        parts = ref_str.split(".")
        if len(parts) < 3:
            return None

        raw_book = parts[0]
        _, book_code, _, _ = normalize_book(raw_book)
        try:
            ch = int(parts[1])
            vs = int(parts[2])
            return (book_code, ch, vs)
        except ValueError:
            return None
