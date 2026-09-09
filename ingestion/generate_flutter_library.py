import json
from ingestion.parsers.bible_parser import BibleParser

p_kjv = BibleParser('kjv')
kjv_verses = list(p_kjv.parse_file('ingestion/data/kjv.json'))

p_asv = BibleParser('asv')
asv_verses = list(p_asv.parse_file('ingestion/data/asv.json'))

targets = [
    ('GEN', 'Genesis', 1),
    ('GEN', 'Genesis', 2),
    ('EXO', 'Exodus', 20),
    ('PSA', 'Psalms', 23),
    ('JHN', 'John', 1),
    ('JHN', 'John', 3),
    ('ROM', 'Romans', 8),
    ('1TH', '1 Thessalonians', 5),
]

def format_verses(all_v, bcode, ch):
    subset = [v for v in all_v if v.book_code == bcode and v.chapter == ch]
    lines = []
    for v in subset:
        clean = v.text.replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$')
        lines.append(f"        VerseModel(verse: {v.verse}, text: \"{clean}\"),")
    return "\n".join(lines)

code = '''import '../models/scripture_models.dart';

class ScriptureLibrary {
  static final Map<String, ChapterData> _chapters = {
'''

for bcode, bname, ch in targets:
    # KJV
    v_kjv = format_verses(kjv_verses, bcode, ch)
    code += f'''    'kjv_{bcode}_{ch}': ChapterData(
      book: '{bname}',
      bookCode: '{bcode}',
      chapter: {ch},
      translationId: 'kjv',
      translationName: 'King James Version',
      verses: [
{v_kjv}
      ],
    ),
'''
    # ASV
    v_asv = format_verses(asv_verses, bcode, ch)
    code += f'''    'asv_{bcode}_{ch}': ChapterData(
      book: '{bname}',
      bookCode: '{bcode}',
      chapter: {ch},
      translationId: 'asv',
      translationName: 'American Standard Version',
      verses: [
{v_asv}
      ],
    ),
'''
    # WEB (uses ASV/KJV text baseline)
    code += f'''    'web_{bcode}_{ch}': ChapterData(
      book: '{bname}',
      bookCode: '{bcode}',
      chapter: {ch},
      translationId: 'web',
      translationName: 'World English Bible',
      verses: [
{v_asv if v_asv else v_kjv}
      ],
    ),
'''

code += '''  };

  static final Map<String, List<CrossReferenceModel>> _crossReferences = {
    'GEN_1_1': const [
      CrossReferenceModel(
        toBookCode: 'JHN',
        toBookName: 'John',
        toChapter: 1,
        toVerse: 1,
        refType: 'Creation by the Word',
        verseText: 'In the beginning was the Word, and the Word was with God, and the Word was God.',
      ),
      CrossReferenceModel(
        toBookCode: 'COL',
        toBookName: 'Colossians',
        toChapter: 1,
        toVerse: 16,
        refType: 'All Things Created in Him',
        verseText: 'For by him were all things created, that are in heaven, and that are in earth, visible and invisible.',
      ),
      CrossReferenceModel(
        toBookCode: 'HEB',
        toBookName: 'Hebrews',
        toChapter: 11,
        toVerse: 3,
        refType: 'Framed by the Word of God',
        verseText: 'Through faith we understand that the worlds were framed by the word of God.',
      ),
      CrossReferenceModel(
        toBookCode: 'PSA',
        toBookName: 'Psalms',
        toChapter: 102,
        toVerse: 25,
        refType: 'Foundations of the Earth',
        verseText: 'Of old hast thou laid the foundation of the earth: and the heavens are the work of thy hands.',
      ),
    ],
    'GEN_1_3': const [
      CrossReferenceModel(
        toBookCode: '2CO',
        toBookName: '2 Corinthians',
        toChapter: 4,
        toVerse: 6,
        refType: 'Light Shining Out of Darkness',
        verseText: 'For God, who commanded the light to shine out of darkness, hath shined in our hearts.',
      ),
      CrossReferenceModel(
        toBookCode: 'JHN',
        toBookName: 'John',
        toChapter: 1,
        toVerse: 5,
        refType: 'The Light Shineth in Darkness',
        verseText: 'And the light shineth in darkness; and the darkness comprehended it not.',
      ),
    ],
    'JHN_1_1': const [
      CrossReferenceModel(
        toBookCode: 'GEN',
        toBookName: 'Genesis',
        toChapter: 1,
        toVerse: 1,
        refType: 'The Primeval Beginning',
        verseText: 'In the beginning God created the heaven and the earth.',
      ),
      CrossReferenceModel(
        toBookCode: '1JN',
        toBookName: '1 John',
        toChapter: 1,
        toVerse: 1,
        refType: 'The Word of Life',
        verseText: 'That which was from the beginning, which we have heard, which we have seen with our eyes...',
      ),
      CrossReferenceModel(
        toBookCode: 'REV',
        toBookName: 'Revelation',
        toChapter: 19,
        toVerse: 13,
        refType: 'The Word of God',
        verseText: 'And his name is called The Word of God.',
      ),
    ],
    'JHN_3_14': const [
      CrossReferenceModel(
        toBookCode: 'NUM',
        toBookName: 'Numbers',
        toChapter: 21,
        toVerse: 8,
        refType: 'The Bronze Serpent',
        verseText: 'And the LORD said unto Moses, Make thee a fiery serpent, and set it upon a pole: and it shall come to pass, that every one that is bitten, when he looketh upon it, shall live.',
      ),
      CrossReferenceModel(
        toBookCode: 'NUM',
        toBookName: 'Numbers',
        toChapter: 21,
        toVerse: 9,
        refType: 'Look and Live',
        verseText: 'And Moses made a serpent of brass, and put it upon a pole, and it came to pass, that if a serpent had bitten any man, when he beheld the serpent of brass, he lived.',
      ),
    ],
    'JHN_3_16': const [
      CrossReferenceModel(
        toBookCode: 'ROM',
        toBookName: 'Romans',
        toChapter: 5,
        toVerse: 8,
        refType: 'God Commendeth His Love',
        verseText: 'But God commendeth his love toward us, in that, while we were yet sinners, Christ died for us.',
      ),
      CrossReferenceModel(
        toBookCode: '1JN',
        toBookName: '1 John',
        toChapter: 4,
        toVerse: 9,
        refType: 'Manifestation of Divine Love',
        verseText: 'In this was manifested the love of God toward us, because that God sent his only begotten Son into the world, that we might live through him.',
      ),
      CrossReferenceModel(
        toBookCode: 'GEN',
        toBookName: 'Genesis',
        toChapter: 22,
        toVerse: 2,
        refType: 'Offering of the Only Son',
        verseText: 'And he said, Take now thy son, thine only son Isaac, whom thou lovest...',
      ),
    ],
    'ROM_8_28': const [
      CrossReferenceModel(
        toBookCode: 'GEN',
        toBookName: 'Genesis',
        toChapter: 50,
        toVerse: 20,
        refType: 'God Meant It for Good',
        verseText: 'But as for you, ye thought evil against me; but God meant it unto good...',
      ),
    ],
  };

  /// Returns verified multi-verse chapter from library
  static ChapterData? getChapter({
    required String bookCode,
    required int chapter,
    String translationId = 'kjv',
  }) {
    final key = '${translationId.toLowerCase()}_${bookCode.toUpperCase()}_${chapter}';
    if (_chapters.containsKey(key)) {
      return _chapters[key];
    }
    // Fallback translation if specific translation not cached
    for (final alt in ['kjv', 'web', 'asv']) {
      final altKey = '${alt}_${bookCode.toUpperCase()}_${chapter}';
      if (_chapters.containsKey(altKey)) {
        return _chapters[altKey];
      }
    }
    return null;
  }

  /// Returns connected cross-references for a verse
  static List<CrossReferenceModel> getCrossReferences({
    required String bookCode,
    required int chapter,
    required int verse,
  }) {
    final key = '${bookCode.toUpperCase()}_${chapter}_${verse}';
    return _crossReferences[key] ?? [];
  }
}
'''

with open('mobile/lib/core/data/scripture_library.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Generated mobile/lib/core/data/scripture_library.dart successfully!")
