import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TheologicalTheme {
  final String key;
  final String label;
  final Color color;
  final String description;

  const TheologicalTheme({
    required this.key,
    required this.label,
    required this.color,
    required this.description,
  });
}

class TheologicalThemes {
  static const TheologicalTheme promises = TheologicalTheme(
    key: 'promises',
    label: 'Promises of God',
    color: Color(0xFFF59E0B), // Gold/Amber
    description: 'Covenant assurances, divine faithfulness & inheritances',
  );

  static const TheologicalTheme living = TheologicalTheme(
    key: 'living',
    label: 'Living & Obedience',
    color: Color(0xFF10B981), // Mint/Emerald
    description: 'Commandments, spiritual fruit & holy walk',
  );

  static const TheologicalTheme comfort = TheologicalTheme(
    key: 'comfort',
    label: 'Comfort & Hope',
    color: Color(0xFFF43F5E), // Rose
    description: 'Mercy in trials, healing, peace & deliverance',
  );

  static const TheologicalTheme prophecy = TheologicalTheme(
    key: 'prophecy',
    label: 'Prophecy & Glory',
    color: Color(0xFF8B5CF6), // Royal Purple
    description: 'Messianic predictions, kingdom eternity & kingship',
  );

  static const TheologicalTheme doctrine = TheologicalTheme(
    key: 'doctrine',
    label: 'Doctrine & Wisdom',
    color: Color(0xFF06B6D4), // Cyan/Sky
    description: 'Atonement, divine nature, grace & foundational truth',
  );

  static const List<TheologicalTheme> all = [
    promises,
    living,
    comfort,
    prophecy,
    doctrine,
  ];

  static TheologicalTheme fromColor(Color color) {
    for (final theme in all) {
      if (theme.color.value == color.value) return theme;
    }
    return promises;
  }

  static TheologicalTheme fromKey(String key) {
    for (final theme in all) {
      if (theme.key == key) return theme;
    }
    return promises;
  }
}

class JournalEntryModel {
  final String id;
  final String bookCode;
  final String bookName;
  final int chapter;
  final int verse;
  final String verseText;
  final String translationId;
  final int colorValue;
  final String theologicalKey;
  final String? noteText;
  final DateTime createdAt;

  const JournalEntryModel({
    required this.id,
    required this.bookCode,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.verseText,
    this.translationId = 'kjv',
    required this.colorValue,
    required this.theologicalKey,
    this.noteText,
    required this.createdAt,
  });

  Color get color => Color(colorValue);
  TheologicalTheme get theme => TheologicalThemes.fromKey(theologicalKey);
  String get reference => '$bookName $chapter:$verse';
  bool get hasNote => noteText != null && noteText!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'book_code': bookCode,
        'book_name': bookName,
        'chapter': chapter,
        'verse': verse,
        'verse_text': verseText,
        'translation_id': translationId,
        'color_value': colorValue,
        'theological_key': theologicalKey,
        'note_text': noteText,
        'created_at': createdAt.toIso8601String(),
      };

  factory JournalEntryModel.fromJson(Map<String, dynamic> map) {
    return JournalEntryModel(
      id: map['id'] ?? '',
      bookCode: map['book_code'] ?? '',
      bookName: map['book_name'] ?? '',
      chapter: map['chapter'] ?? 0,
      verse: map['verse'] ?? 0,
      verseText: map['verse_text'] ?? '',
      translationId: map['translation_id'] ?? 'kjv',
      colorValue: map['color_value'] ?? TheologicalThemes.promises.color.value,
      theologicalKey: map['theological_key'] ?? TheologicalThemes.promises.key,
      noteText: map['note_text'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  JournalEntryModel copyWith({
    String? noteText,
    int? colorValue,
    String? theologicalKey,
  }) {
    return JournalEntryModel(
      id: id,
      bookCode: bookCode,
      bookName: bookName,
      chapter: chapter,
      verse: verse,
      verseText: verseText,
      translationId: translationId,
      colorValue: colorValue ?? this.colorValue,
      theologicalKey: theologicalKey ?? this.theologicalKey,
      noteText: noteText ?? this.noteText,
      createdAt: createdAt,
    );
  }
}

class StudyJournalService {
  static final StudyJournalService _instance = StudyJournalService._internal();
  factory StudyJournalService() => _instance;
  StudyJournalService._internal();

  static const String _storageKey = 'theological_study_journal_entries';

  final List<JournalEntryModel> _entries = [];
  final ValueNotifier<List<JournalEntryModel>> entriesNotifier =
      ValueNotifier<List<JournalEntryModel>>([]);

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final List<dynamic> decoded = json.decode(raw);
        _entries.clear();
        _entries.addAll(decoded.map((m) => JournalEntryModel.fromJson(m)));
      } else {
        // Pre-seed sample entries to illustrate theological categorization on fresh launch
        _entries.clear();
        _entries.addAll(_initialSeedEntries);
        await _save();
      }
      _notify();
    } catch (_) {
      if (_entries.isEmpty) {
        _entries.addAll(_initialSeedEntries);
      }
      _notify();
    }
  }

  void _notify() {
    entriesNotifier.value = List.unmodifiable(_entries);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = json.encode(_entries.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (_) {}
    _notify();
  }

  List<JournalEntryModel> get entries => List.unmodifiable(_entries);

  Map<int, Color> getHighlightsForChapter(String bookCode, int chapter) {
    final Map<int, Color> map = {};
    for (final e in _entries) {
      if (e.bookCode.toUpperCase() == bookCode.toUpperCase() && e.chapter == chapter) {
        map[e.verse] = e.color;
      }
    }
    return map;
  }

  Future<JournalEntryModel> addOrUpdateHighlight({
    required String bookCode,
    required String bookName,
    required int chapter,
    required int verse,
    required String verseText,
    required Color color,
    String? theologicalKey,
    String? translationId,
    String? noteText,
  }) async {
    final tKey = theologicalKey ?? TheologicalThemes.fromColor(color).key;
    final entryId = '${bookCode}_${chapter}_$verse'.toUpperCase();

    final existingIndex = _entries.indexWhere((e) => e.id == entryId);
    final JournalEntryModel result;
    if (existingIndex >= 0) {
      result = _entries[existingIndex].copyWith(
        colorValue: color.value,
        theologicalKey: tKey,
        noteText: noteText ?? _entries[existingIndex].noteText,
      );
      _entries[existingIndex] = result;
    } else {
      result = JournalEntryModel(
        id: entryId,
        bookCode: bookCode.toUpperCase(),
        bookName: bookName,
        chapter: chapter,
        verse: verse,
        verseText: verseText,
        translationId: translationId ?? 'kjv',
        colorValue: color.value,
        theologicalKey: tKey,
        noteText: noteText,
        createdAt: DateTime.now(),
      );
      _entries.insert(0, result);
    }
    _notify();
    _save();
    return result;
  }

  Future<JournalEntryModel> addOrUpdateNote({
    required String bookCode,
    required String bookName,
    required int chapter,
    required int verse,
    required String verseText,
    required String noteText,
    Color? color,
    String? theologicalKey,
    String? translationId,
  }) async {
    final assignedColor = color ?? TheologicalThemes.doctrine.color;
    final assignedKey = theologicalKey ?? TheologicalThemes.fromColor(assignedColor).key;
    final entryId = '${bookCode}_${chapter}_$verse'.toUpperCase();

    final existingIndex = _entries.indexWhere((e) => e.id == entryId);
    final JournalEntryModel result;
    if (existingIndex >= 0) {
      result = _entries[existingIndex].copyWith(
        noteText: noteText,
        colorValue: color?.value,
        theologicalKey: theologicalKey,
      );
      _entries[existingIndex] = result;
    } else {
      result = JournalEntryModel(
        id: entryId,
        bookCode: bookCode.toUpperCase(),
        bookName: bookName,
        chapter: chapter,
        verse: verse,
        verseText: verseText,
        translationId: translationId ?? 'kjv',
        colorValue: assignedColor.value,
        theologicalKey: assignedKey,
        noteText: noteText,
        createdAt: DateTime.now(),
      );
      _entries.insert(0, result);
    }
    _notify();
    _save();
    return result;
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _save();
  }

  String exportToMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Theological Study Journal');
    buffer.writeln('*Exported from ScriptureDepth on ${DateTime.now().toLocal().toString().split(' ').first}*');
    buffer.writeln();

    for (final theme in TheologicalThemes.all) {
      final themeEntries = _entries.where((e) => e.theologicalKey == theme.key).toList();
      if (themeEntries.isEmpty) continue;

      buffer.writeln('## ${theme.label}');
      buffer.writeln('*${theme.description}*');
      buffer.writeln();

      for (final e in themeEntries) {
        buffer.writeln('### ${e.reference} (${e.translationId.toUpperCase()})');
        buffer.writeln('> "${e.verseText}"');
        if (e.hasNote) {
          buffer.writeln();
          buffer.writeln('**Study Notes:** ${e.noteText}');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  static final List<JournalEntryModel> _initialSeedEntries = [
    JournalEntryModel(
      id: 'JHN_15_5',
      bookCode: 'JHN',
      bookName: 'John',
      chapter: 15,
      verse: 5,
      verseText: 'I am the vine, ye are the branches: He that abideth in me, and I in him, the same bringeth forth much fruit: for without me ye can do nothing.',
      translationId: 'kjv',
      colorValue: TheologicalThemes.promises.color.value,
      theologicalKey: TheologicalThemes.promises.key,
      noteText: 'Vitally connected to Christ as the sole source of spiritual life and endurance.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    JournalEntryModel(
      id: 'ROM_8_28',
      bookCode: 'ROM',
      bookName: 'Romans',
      chapter: 8,
      verse: 28,
      verseText: 'And we know that all things work together for good to them that love God, to them who are the called according to his purpose.',
      translationId: 'kjv',
      colorValue: TheologicalThemes.comfort.color.value,
      theologicalKey: TheologicalThemes.comfort.key,
      noteText: 'Sovereign providence: every sorrow, trial, and victory orchestrates God\'s eternal good.',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    JournalEntryModel(
      id: 'EPH_2_8',
      bookCode: 'EPH',
      bookName: 'Ephesians',
      chapter: 2,
      verse: 8,
      verseText: 'For by grace are ye saved through faith; and that not of yourselves: it is the gift of God.',
      translationId: 'kjv',
      colorValue: TheologicalThemes.doctrine.color.value,
      theologicalKey: TheologicalThemes.doctrine.key,
      noteText: 'Sola Gratia. Salvation is an unmerited gift; no human boasting can ever stand before the cross.',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
    JournalEntryModel(
      id: 'MIC_5_2',
      bookCode: 'MIC',
      bookName: 'Micah',
      chapter: 5,
      verse: 2,
      verseText: 'But thou, Bethlehem Ephratah, though thou be little among the thousands of Judah, yet out of thee shall he come forth unto me that is to be ruler in Israel; whose goings forth have been from of old, from everlasting.',
      translationId: 'kjv',
      colorValue: TheologicalThemes.prophecy.color.value,
      theologicalKey: TheologicalThemes.prophecy.key,
      noteText: 'Micah prophesies the birthplace of the eternal King 700 years before Bethlehem.',
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];
}
