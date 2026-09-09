class OriginalWord {
  final int wordPosition;
  final String surfaceForm;
  final String lemma;
  final String? transliteration;
  final String? strongsNumber;
  final String? morphCode;
  final String language;
  final String? englishGloss;
  final String? morphDescription;

  const OriginalWord({
    required this.wordPosition,
    required this.surfaceForm,
    required this.lemma,
    this.transliteration,
    this.strongsNumber,
    this.morphCode,
    required this.language,
    this.englishGloss,
    this.morphDescription,
  });

  factory OriginalWord.fromJson(Map<String, dynamic> json) {
    return OriginalWord(
      wordPosition: json['word_position'] ?? 0,
      surfaceForm: json['surface_form'] ?? '',
      lemma: json['lemma'] ?? '',
      transliteration: json['transliteration'],
      strongsNumber: json['strongs_number'],
      morphCode: json['morph_code'],
      language: json['language'] ?? 'greek',
      englishGloss: json['english_gloss'],
      morphDescription: json['morph_description'],
    );
  }
}

class VerseModel {
  final int verse;
  final String text;
  final List<OriginalWord> originalWords;

  const VerseModel({
    required this.verse,
    required this.text,
    this.originalWords = const [],
  });

  factory VerseModel.fromJson(Map<String, dynamic> json) {
    return VerseModel(
      verse: json['verse'] ?? 0,
      text: json['text'] ?? '',
      originalWords: (json['original_words'] as List<dynamic>? ?? [])
          .map((w) => OriginalWord.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChapterData {
  final String book;
  final String bookCode;
  final int chapter;
  final String translationId;
  final String translationName;
  final List<VerseModel> verses;

  const ChapterData({
    required this.book,
    required this.bookCode,
    required this.chapter,
    required this.translationId,
    required this.translationName,
    required this.verses,
  });

  factory ChapterData.fromJson(Map<String, dynamic> json) {
    return ChapterData(
      book: json['book'] ?? '',
      bookCode: json['book_code'] ?? '',
      chapter: json['chapter'] ?? 0,
      translationId: json['translation_id'] ?? '',
      translationName: json['translation_name'] ?? '',
      verses: (json['verses'] as List<dynamic>? ?? [])
          .map((v) => VerseModel.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LexiconEntryModel {
  final String strongsNumber;
  final String language;
  final String lemma;
  final String? transliteration;
  final String? pronunciation;
  final String shortDefinition;
  final String? longDefinition;
  final String source;
  final int occurrencesCount;
  final String? derivation;
  final String? outlineUsage;
  final String? kjvDefinition;

  const LexiconEntryModel({
    required this.strongsNumber,
    required this.language,
    required this.lemma,
    this.transliteration,
    this.pronunciation,
    required this.shortDefinition,
    this.longDefinition,
    required this.source,
    this.occurrencesCount = 0,
    this.derivation,
    this.outlineUsage,
    this.kjvDefinition,
  });

  factory LexiconEntryModel.fromJson(Map<String, dynamic> json) {
    return LexiconEntryModel(
      strongsNumber: json['strongs_number'] ?? '',
      language: json['language'] ?? 'greek',
      lemma: json['lemma'] ?? '',
      transliteration: json['transliteration'],
      pronunciation: json['pronunciation'],
      shortDefinition: json['short_definition'] ?? '',
      longDefinition: json['long_definition'],
      source: json['source'] ?? 'strongs',
      occurrencesCount: json['occurrences_count'] ?? 0,
      derivation: json['derivation'],
      outlineUsage: json['outline_usage'],
      kjvDefinition: json['kjv_definition'],
    );
  }
}

class WordOccurrenceModel {
  final String bookCode;
  final int chapter;
  final int verse;
  final String surfaceForm;
  final String? verseText;

  const WordOccurrenceModel({
    required this.bookCode,
    required this.chapter,
    required this.verse,
    required this.surfaceForm,
    this.verseText,
  });

  String get reference => '$bookCode $chapter:$verse';

  factory WordOccurrenceModel.fromJson(Map<String, dynamic> json) {
    return WordOccurrenceModel(
      bookCode: json['book_code'] ?? '',
      chapter: json['chapter'] ?? 0,
      verse: json['verse'] ?? 0,
      surfaceForm: json['surface_form'] ?? '',
      verseText: json['verse_text'],
    );
  }
}

class LexiconDetailModel {
  final LexiconEntryModel entry;
  final List<WordOccurrenceModel> occurrences;

  const LexiconDetailModel({
    required this.entry,
    this.occurrences = const [],
  });

  factory LexiconDetailModel.fromJson(Map<String, dynamic> json) {
    return LexiconDetailModel(
      entry: LexiconEntryModel.fromJson(json['entry'] ?? {}),
      occurrences: (json['occurrences'] as List<dynamic>? ?? [])
          .map((o) => WordOccurrenceModel.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SearchResultModel {
  final String book;
  final String bookCode;
  final int chapter;
  final int verse;
  final String text;
  final String? highlightedText;
  final String? translationId;

  const SearchResultModel({
    required this.book,
    required this.bookCode,
    required this.chapter,
    required this.verse,
    required this.text,
    this.highlightedText,
    this.translationId,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    return SearchResultModel(
      book: json['book'] ?? '',
      bookCode: json['book_code'] ?? '',
      chapter: json['chapter'] ?? 0,
      verse: json['verse'] ?? 0,
      text: json['text'] ?? '',
      highlightedText: json['highlighted_text'],
      translationId: json['translation_id'],
    );
  }
}

class CrossReferenceModel {
  final String toBookCode;
  final String toBookName;
  final int toChapter;
  final int toVerse;
  final String? refType;
  final double weight;
  final String? verseText;

  const CrossReferenceModel({
    required this.toBookCode,
    required this.toBookName,
    required this.toChapter,
    required this.toVerse,
    this.refType,
    this.weight = 1.0,
    this.verseText,
  });

  String get reference => '$toBookName $toChapter:$toVerse';

  factory CrossReferenceModel.fromJson(Map<String, dynamic> json) {
    return CrossReferenceModel(
      toBookCode: json['to_book_code'] ?? '',
      toBookName: json['to_book_name'] ?? json['to_book_code'] ?? '',
      toChapter: json['to_chapter'] ?? 0,
      toVerse: json['to_verse'] ?? 0,
      refType: json['ref_type'],
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      verseText: json['verse_text'],
    );
  }
}

class BibleBook {
  final String code;
  final String name;
  final String testament; // 'OT' or 'NT'
  final int totalChapters;

  const BibleBook({
    required this.code,
    required this.name,
    required this.testament,
    required this.totalChapters,
  });

  static const List<BibleBook> allBooks = [
    // Old Testament (39)
    BibleBook(code: 'GEN', name: 'Genesis', testament: 'OT', totalChapters: 50),
    BibleBook(code: 'EXO', name: 'Exodus', testament: 'OT', totalChapters: 40),
    BibleBook(code: 'LEV', name: 'Leviticus', testament: 'OT', totalChapters: 27),
    BibleBook(code: 'NUM', name: 'Numbers', testament: 'OT', totalChapters: 36),
    BibleBook(code: 'DEU', name: 'Deuteronomy', testament: 'OT', totalChapters: 34),
    BibleBook(code: 'JOS', name: 'Joshua', testament: 'OT', totalChapters: 24),
    BibleBook(code: 'JDG', name: 'Judges', testament: 'OT', totalChapters: 21),
    BibleBook(code: 'RUT', name: 'Ruth', testament: 'OT', totalChapters: 4),
    BibleBook(code: '1SA', name: '1 Samuel', testament: 'OT', totalChapters: 31),
    BibleBook(code: '2SA', name: '2 Samuel', testament: 'OT', totalChapters: 24),
    BibleBook(code: '1KI', name: '1 Kings', testament: 'OT', totalChapters: 22),
    BibleBook(code: '2KI', name: '2 Kings', testament: 'OT', totalChapters: 25),
    BibleBook(code: '1CH', name: '1 Chronicles', testament: 'OT', totalChapters: 29),
    BibleBook(code: '2CH', name: '2 Chronicles', testament: 'OT', totalChapters: 36),
    BibleBook(code: 'EZR', name: 'Ezra', testament: 'OT', totalChapters: 10),
    BibleBook(code: 'NEH', name: 'Nehemiah', testament: 'OT', totalChapters: 13),
    BibleBook(code: 'EST', name: 'Esther', testament: 'OT', totalChapters: 10),
    BibleBook(code: 'JOB', name: 'Job', testament: 'OT', totalChapters: 42),
    BibleBook(code: 'PSA', name: 'Psalms', testament: 'OT', totalChapters: 150),
    BibleBook(code: 'PRO', name: 'Proverbs', testament: 'OT', totalChapters: 31),
    BibleBook(code: 'ECC', name: 'Ecclesiastes', testament: 'OT', totalChapters: 12),
    BibleBook(code: 'SNG', name: 'Song of Songs', testament: 'OT', totalChapters: 8),
    BibleBook(code: 'ISA', name: 'Isaiah', testament: 'OT', totalChapters: 66),
    BibleBook(code: 'JER', name: 'Jeremiah', testament: 'OT', totalChapters: 52),
    BibleBook(code: 'LAM', name: 'Lamentations', testament: 'OT', totalChapters: 5),
    BibleBook(code: 'EZK', name: 'Ezekiel', testament: 'OT', totalChapters: 48),
    BibleBook(code: 'DAN', name: 'Daniel', testament: 'OT', totalChapters: 12),
    BibleBook(code: 'HOS', name: 'Hosea', testament: 'OT', totalChapters: 14),
    BibleBook(code: 'JOL', name: 'Joel', testament: 'OT', totalChapters: 3),
    BibleBook(code: 'AMO', name: 'Amos', testament: 'OT', totalChapters: 9),
    BibleBook(code: 'OBA', name: 'Obadiah', testament: 'OT', totalChapters: 1),
    BibleBook(code: 'JON', name: 'Jonah', testament: 'OT', totalChapters: 4),
    BibleBook(code: 'MIC', name: 'Micah', testament: 'OT', totalChapters: 7),
    BibleBook(code: 'NAM', name: 'Nahum', testament: 'OT', totalChapters: 3),
    BibleBook(code: 'HAB', name: 'Habakkuk', testament: 'OT', totalChapters: 3),
    BibleBook(code: 'ZEP', name: 'Zephaniah', testament: 'OT', totalChapters: 3),
    BibleBook(code: 'HAG', name: 'Haggai', testament: 'OT', totalChapters: 2),
    BibleBook(code: 'ZEC', name: 'Zechariah', testament: 'OT', totalChapters: 14),
    BibleBook(code: 'MAL', name: 'Malachi', testament: 'OT', totalChapters: 4),

    // New Testament (27)
    BibleBook(code: 'MAT', name: 'Matthew', testament: 'NT', totalChapters: 28),
    BibleBook(code: 'MRK', name: 'Mark', testament: 'NT', totalChapters: 16),
    BibleBook(code: 'LUK', name: 'Luke', testament: 'NT', totalChapters: 24),
    BibleBook(code: 'JHN', name: 'John', testament: 'NT', totalChapters: 21),
    BibleBook(code: 'ACT', name: 'Acts', testament: 'NT', totalChapters: 28),
    BibleBook(code: 'ROM', name: 'Romans', testament: 'NT', totalChapters: 16),
    BibleBook(code: '1CO', name: '1 Corinthians', testament: 'NT', totalChapters: 16),
    BibleBook(code: '2CO', name: '2 Corinthians', testament: 'NT', totalChapters: 13),
    BibleBook(code: 'GAL', name: 'Galatians', testament: 'NT', totalChapters: 6),
    BibleBook(code: 'EPH', name: 'Ephesians', testament: 'NT', totalChapters: 6),
    BibleBook(code: 'PHP', name: 'Philippians', testament: 'NT', totalChapters: 4),
    BibleBook(code: 'COL', name: 'Colossians', testament: 'NT', totalChapters: 4),
    BibleBook(code: '1TH', name: '1 Thessalonians', testament: 'NT', totalChapters: 5),
    BibleBook(code: '2TH', name: '2 Thessalonians', testament: 'NT', totalChapters: 3),
    BibleBook(code: '1TI', name: '1 Timothy', testament: 'NT', totalChapters: 6),
    BibleBook(code: '2TI', name: '2 Timothy', testament: 'NT', totalChapters: 4),
    BibleBook(code: 'TIT', name: 'Titus', testament: 'NT', totalChapters: 3),
    BibleBook(code: 'PHM', name: 'Philemon', testament: 'NT', totalChapters: 1),
    BibleBook(code: 'HEB', name: 'Hebrews', testament: 'NT', totalChapters: 13),
    BibleBook(code: 'JAS', name: 'James', testament: 'NT', totalChapters: 5),
    BibleBook(code: '1PE', name: '1 Peter', testament: 'NT', totalChapters: 5),
    BibleBook(code: '2PE', name: '2 Peter', testament: 'NT', totalChapters: 3),
    BibleBook(code: '1JN', name: '1 John', testament: 'NT', totalChapters: 5),
    BibleBook(code: '2JN', name: '2 John', testament: 'NT', totalChapters: 1),
    BibleBook(code: '3JN', name: '3 John', testament: 'NT', totalChapters: 1),
    BibleBook(code: 'JUD', name: 'Jude', testament: 'NT', totalChapters: 1),
    BibleBook(code: 'REV', name: 'Revelation', testament: 'NT', totalChapters: 22),
  ];

  /// Returns (code, name, chapter) for the next chapter.
  /// Advances to the first chapter of the next book at book boundaries.
  /// Returns null at Revelation's last chapter (end of Bible).
  static ({String code, String name, int chapter})? getNextChapter(String currentBookCode, int currentChapter) {
    final idx = allBooks.indexWhere((b) => b.code == currentBookCode);
    if (idx < 0) return null;
    final book = allBooks[idx];
    if (currentChapter < book.totalChapters) {
      return (code: book.code, name: book.name, chapter: currentChapter + 1);
    }
    if (idx + 1 < allBooks.length) {
      final next = allBooks[idx + 1];
      return (code: next.code, name: next.name, chapter: 1);
    }
    return null;
  }

  /// Returns (code, name, chapter) for the previous chapter.
  /// Goes to the last chapter of the previous book at book boundaries.
  /// Returns null at Genesis 1 (start of Bible).
  static ({String code, String name, int chapter})? getPreviousChapter(String currentBookCode, int currentChapter) {
    final idx = allBooks.indexWhere((b) => b.code == currentBookCode);
    if (idx < 0) return null;
    if (currentChapter > 1) {
      final book = allBooks[idx];
      return (code: book.code, name: book.name, chapter: currentChapter - 1);
    }
    if (idx > 0) {
      final prev = allBooks[idx - 1];
      return (code: prev.code, name: prev.name, chapter: prev.totalChapters);
    }
    return null;
  }
}

class UserNoteModel {
  final int id;
  final String bookCode;
  final int chapter;
  final int verse;
  final String text;
  final DateTime createdAt;

  const UserNoteModel({
    required this.id,
    required this.bookCode,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.createdAt,
  });

  factory UserNoteModel.fromJson(Map<String, dynamic> json) {
    return UserNoteModel(
      id: json['id'] ?? 0,
      bookCode: json['book_code'] ?? '',
      chapter: json['chapter'] ?? 0,
      verse: json['verse'] ?? 0,
      text: json['text'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class BookmarkModel {
  final int id;
  final String bookCode;
  final int chapter;
  final int verse;
  final String? label;

  const BookmarkModel({
    required this.id,
    required this.bookCode,
    required this.chapter,
    required this.verse,
    this.label,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'] ?? 0,
      bookCode: json['book_code'] ?? '',
      chapter: json['chapter'] ?? 0,
      verse: json['verse'] ?? 0,
      label: json['label'],
    );
  }
}

class MemorizationCardModel {
  final int id;
  final String bookCode;
  final int chapter;
  final int verse;
  final String verseText;
  final int intervalDays;
  final int repetitions;

  const MemorizationCardModel({
    required this.id,
    required this.bookCode,
    required this.chapter,
    required this.verse,
    required this.verseText,
    this.intervalDays = 1,
    this.repetitions = 0,
  });

  String get reference {
    final book = BibleBook.allBooks.firstWhere(
      (b) => b.code == bookCode.toUpperCase(),
      orElse: () => BibleBook(code: bookCode, name: bookCode, testament: 'OT', totalChapters: 1),
    );
    return '${book.name} $chapter:$verse';
  }

  factory MemorizationCardModel.fromJson(Map<String, dynamic> json) {
    return MemorizationCardModel(
      id: json['id'] ?? 0,
      bookCode: json['book_code'] ?? '',
      chapter: json['chapter'] ?? 0,
      verse: json['verse'] ?? 0,
      verseText: json['verse_text'] ?? '',
      intervalDays: json['interval_days'] ?? 1,
      repetitions: json['repetitions'] ?? 0,
    );
  }
}

class DailyVerseModel {
  final String bookCode;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;
  final String translationId;

  const DailyVerseModel({
    required this.bookCode,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.translationId,
  });

  String get reference => '$bookName $chapter:$verse';

  factory DailyVerseModel.fromJson(Map<String, dynamic> json) {
    return DailyVerseModel(
      bookCode: json['book_code'] ?? 'JHN',
      bookName: json['book_name'] ?? 'John',
      chapter: json['chapter'] ?? 3,
      verse: json['verse'] ?? 16,
      text: json['text'] ?? '',
      translationId: json['translation_id'] ?? 'ESV',
    );
  }
}

class DailyWordModel {
  final String strongsNumber;
  final String language;
  final String lemma;
  final String transliteration;
  final String pronunciation;
  final String shortDefinition;
  final String outlineUsage;
  final int occurrencesCount;
  final String derivation;

  const DailyWordModel({
    required this.strongsNumber,
    required this.language,
    required this.lemma,
    required this.transliteration,
    required this.pronunciation,
    required this.shortDefinition,
    required this.outlineUsage,
    required this.occurrencesCount,
    required this.derivation,
  });

  factory DailyWordModel.fromJson(Map<String, dynamic> json) {
    return DailyWordModel(
      strongsNumber: json['strongs_number'] ?? 'G26',
      language: json['language'] ?? 'greek',
      lemma: json['lemma'] ?? 'ἀγάπη',
      transliteration: json['transliteration'] ?? 'agapē',
      pronunciation: json['pronunciation'] ?? '',
      shortDefinition: json['short_definition'] ?? '',
      outlineUsage: json['outline_usage'] ?? '',
      occurrencesCount: json['occurrences_count'] ?? 0,
      derivation: json['derivation'] ?? '',
    );
  }
}

class DailyPlanModel {
  final String id;
  final String title;
  final String description;
  final int durationDays;
  final int currentDay;
  final String nextReading;
  final String nextBookCode;
  final int nextChapter;
  final String versePreview;
  final double progressPercent;

  const DailyPlanModel({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.currentDay,
    required this.nextReading,
    required this.nextBookCode,
    required this.nextChapter,
    required this.versePreview,
    required this.progressPercent,
  });

  factory DailyPlanModel.fromJson(Map<String, dynamic> json) {
    return DailyPlanModel(
      id: json['id'] ?? 'gospel_of_john_30d',
      title: json['title'] ?? 'The Gospel of John',
      description: json['description'] ?? 'A 30-day journey exploring the signs, I Am statements, and original Greek depth of Johns gospel.',
      durationDays: json['duration_days'] ?? 30,
      currentDay: json['current_day'] ?? 12,
      nextReading: json['next_reading'] ?? 'John 15:5',
      nextBookCode: json['next_book_code'] ?? 'JHN',
      nextChapter: json['next_chapter'] ?? 15,
      versePreview: json['verse_preview'] ??
          'I am the vine; you are the branches. Whoever abides in me and I in him, he it is that bears much fruit.',
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.40,
    );
  }
}

class DailyStudyModel {
  final DailyVerseModel verseOfTheDay;
  final DailyWordModel wordOfTheDay;
  final DailyPlanModel readingPlan;
  final int memorizationDueCount;
  final int streakDays;

  const DailyStudyModel({
    required this.verseOfTheDay,
    required this.wordOfTheDay,
    required this.readingPlan,
    required this.memorizationDueCount,
    required this.streakDays,
  });

  factory DailyStudyModel.fromJson(Map<String, dynamic> json) {
    return DailyStudyModel(
      verseOfTheDay: DailyVerseModel.fromJson(json['verse_of_the_day'] ?? {}),
      wordOfTheDay: DailyWordModel.fromJson(json['word_of_the_day'] ?? {}),
      readingPlan: DailyPlanModel.fromJson(json['reading_plan'] ?? {}),
      memorizationDueCount: json['memorization_due_count'] ?? 6,
      streakDays: json['streak_days'] ?? 12,
    );
  }
}

class AudioVerseMarker {
  final int verse;
  final int startMs;
  final int endMs;

  const AudioVerseMarker({
    required this.verse,
    required this.startMs,
    required this.endMs,
  });

  factory AudioVerseMarker.fromJson(Map<String, dynamic> json) {
    return AudioVerseMarker(
      verse: json['verse'] ?? 1,
      startMs: json['start_ms'] ?? 0,
      endMs: json['end_ms'] ?? 0,
    );
  }
}

class ChapterAudioInfo {
  final String translationId;
  final String bookCode;
  final String bookName;
  final int chapter;
  final String narrator;
  final String fidelity;
  final String fidelityLabel;
  final String streamUrl;
  final String directCdnUrl;
  final double totalDurationSeconds;
  final List<AudioVerseMarker> verses;

  const ChapterAudioInfo({
    required this.translationId,
    required this.bookCode,
    required this.bookName,
    required this.chapter,
    required this.narrator,
    required this.fidelity,
    required this.fidelityLabel,
    required this.streamUrl,
    required this.directCdnUrl,
    required this.totalDurationSeconds,
    required this.verses,
  });

  factory ChapterAudioInfo.fromJson(Map<String, dynamic> json, {String baseUrl = 'http://127.0.0.1:8000/api/v1'}) {
    final rawStream = json['stream_url'] ?? '';
    final fullStreamUrl = rawStream.startsWith('http')
        ? rawStream
        : (baseUrl.replaceAll('/api/v1', '') + rawStream);

    return ChapterAudioInfo(
      translationId: json['translation_id'] ?? 'kjv',
      bookCode: json['book_code'] ?? 'GEN',
      bookName: json['book_name'] ?? 'Genesis',
      chapter: json['chapter'] ?? 1,
      narrator: json['narrator'] ?? 'Alexander Scourby',
      fidelity: json['fidelity'] ?? 'high_fidelity_human',
      fidelityLabel: json['fidelity_label'] ?? 'Alexander Scourby · Human Studio',
      streamUrl: fullStreamUrl,
      directCdnUrl: json['direct_cdn_url'] ?? '',
      totalDurationSeconds: (json['total_duration_seconds'] as num?)?.toDouble() ?? 180.0,
      verses: (json['verses'] as List<dynamic>? ?? [])
          .map((v) => AudioVerseMarker.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

