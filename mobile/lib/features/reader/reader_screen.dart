import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/scripture_models.dart';
import '../../core/network/api_client.dart';
import '../../core/data/scripture_library.dart';
import '../../core/services/audio_bible_service.dart';
import 'widgets/word_study_sheet.dart';
import 'widgets/book_chapter_picker.dart';
import 'widgets/verse_action_sheet.dart';
import 'widgets/audio_player_bar.dart';
import 'widgets/verse_connections_sheet.dart';
import 'widgets/parallel_reader_view.dart';
import '../../core/services/verse_word_parser.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/reader_navigation_service.dart';
import '../../core/services/study_journal_service.dart';

class ReaderScreen extends StatefulWidget {
  final ApiClient apiClient;

  const ReaderScreen({super.key, required this.apiClient});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool isInterlinearOn = false;
  bool isParallelMode = false;
  bool isZenMode = false;
  String currentBookCode = 'GEN';
  String currentBookName = 'Genesis';
  int currentChapter = 1;
  String currentTranslationId = 'kjv';
  String currentTranslationAbbr = 'KJV';
  String secondaryTranslationId = 'amp';
  String secondaryTranslationAbbr = 'AMP';
  int? selectedVerseNumber;
  final Map<int, Color> _verseHighlights = {};
  final Map<int, GlobalKey> _verseKeys = {};
  ScrollController? _scrollController;

  ChapterData? chapterData;
  ChapterData? secondaryChapterData;
  List<UserNoteModel> userNotes = [];
  bool isLoading = true;
  bool showAudioBar = false;

  final List<Map<String, String>> _availableTranslations = [
    {
      'id': 'kjv',
      'abbr': 'KJV',
      'name': 'King James Version',
      'desc': 'Historic classic text with full Strong’s concordance',
    },
    {
      'id': 'amp',
      'abbr': 'AMP',
      'name': 'Amplified Bible',
      'desc': 'Expanded word meanings and clarifying context',
    },
    {
      'id': 'nkjv',
      'abbr': 'NKJV',
      'name': 'New King James Version',
      'desc': 'Classic majesty with modern linguistic clarity',
    },
    {
      'id': 'esv',
      'abbr': 'ESV',
      'name': 'English Standard Version',
      'desc': 'Word-for-word formal equivalence study text',
    },
    {
      'id': 'niv',
      'abbr': 'NIV',
      'name': 'New International Version',
      'desc': 'Most widely read dynamic modern translation',
    },
    {
      'id': 'nlt',
      'abbr': 'NLT',
      'name': 'New Living Translation',
      'desc': 'Warm, highly engaging, thought-for-thought clarity',
    },
    {
      'id': 'msg',
      'abbr': 'MSG',
      'name': 'The Message',
      'desc': 'Vivid, contemporary paraphrase by Eugene Peterson',
    },
    {
      'id': 'gnt',
      'abbr': 'GNT',
      'name': 'Good News Translation',
      'desc': 'Clear, everyday language faithful to original meaning',
    },
    {
      'id': 'cev',
      'abbr': 'CEV',
      'name': 'Contemporary English Version',
      'desc': 'Simple, direct, reader-friendly translation',
    },
    {
      'id': 'nasb',
      'abbr': 'NASB',
      'name': 'New American Standard Bible',
      'desc': 'Strict, literal word-for-word accuracy',
    },
    {
      'id': 'asv',
      'abbr': 'ASV',
      'name': 'American Standard Version (1901)',
      'desc': 'Rigorous 1901 literal scholarly standard',
    },
    {
      'id': 'web',
      'abbr': 'WEB',
      'name': 'World English Bible',
      'desc': 'Modern public domain literal translation',
    },
    {
      'id': 'bsb',
      'abbr': 'BSB',
      'name': 'Berean Standard Bible',
      'desc': 'Faithful, transparent study translation',
    },
  ];

  final Map<String, String> _sectionHeadings = {
    'GEN_1': 'The Creation of Heaven and Earth',
    'GEN_2': 'The Garden of Eden & The Sabbath',
    'EXO_20': 'The Ten Commandments & The Covenant',
    'PSA_23': 'The Lord is My Shepherd',
    'PSA_102': 'A Prayer of the Afflicted',
    'MAT_5': 'The Sermon on the Mount',
    'JHN_1': 'The Eternal Word Made Flesh',
    'JHN_3': 'The New Birth & God’s Love',
    'ROM_5': 'Peace with God Through Faith',
    'ROM_8': 'Life in the Spirit & Everlasting Love',
    '1TH_5': 'God’s Times and Seasons',
    'HEB_11': 'The Great Hall of Faith',
  };

  late final AppSettingsService _settings;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _settings = AppSettingsService();
    _settings.addListener(_onSettingsChanged);
    AudioBibleService().currentVerseNumber.addListener(_onAudioVerseChanged);
    ReaderNavigationService().navigationRequest.addListener(_onNavigationRequest);
    StudyJournalService().entriesNotifier.addListener(_onJournalUpdated);
    currentTranslationId = _settings.defaultTranslationId;
    currentTranslationAbbr = _settings.defaultTranslationAbbr;
    if (secondaryTranslationId == currentTranslationId) {
      secondaryTranslationId = (currentTranslationId == 'kjv') ? 'amp' : 'kjv';
      secondaryTranslationAbbr = (currentTranslationId == 'kjv') ? 'AMP' : 'KJV';
    }
    _loadChapter();
  }

  @override
  void dispose() {
    StudyJournalService().entriesNotifier.removeListener(_onJournalUpdated);
    ReaderNavigationService().navigationRequest.removeListener(_onNavigationRequest);
    AudioBibleService().currentVerseNumber.removeListener(_onAudioVerseChanged);
    _settings.removeListener(_onSettingsChanged);
    _scrollController?.dispose();
    super.dispose();
  }

  void _onNavigationRequest() {
    final req = ReaderNavigationService().navigationRequest.value;
    if (req == null || !mounted) return;

    final book = BibleBook.allBooks.firstWhere(
      (b) => b.code.toUpperCase() == req.bookCode.toUpperCase(),
      orElse: () => BibleBook.allBooks.first,
    );

    setState(() {
      currentBookCode = req.bookCode.toUpperCase();
      currentBookName = req.bookName ?? book.name;
      currentChapter = req.chapter;
      selectedVerseNumber = req.verse;
    });
    _loadChapter();

    if (req.verse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _verseKeys[req.verse!];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _onJournalUpdated() {
    if (!mounted) return;
    final savedHighlights = StudyJournalService().getHighlightsForChapter(currentBookCode, currentChapter);
    setState(() {
      _verseHighlights.clear();
      _verseHighlights.addAll(savedHighlights);
    });
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    if (currentTranslationId != _settings.defaultTranslationId) {
      setState(() {
        currentTranslationId = _settings.defaultTranslationId;
        currentTranslationAbbr = _settings.defaultTranslationAbbr;
      });
      _loadChapter();
    } else {
      setState(() {});
    }
  }

  void _onAudioVerseChanged() {
    if (!mounted) return;
    final activeVerse = AudioBibleService().currentVerseNumber.value;
    if (activeVerse != null && _verseKeys.containsKey(activeVerse)) {
      final keyContext = _verseKeys[activeVerse]?.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          alignment: 0.32,
        );
      }
    }
    setState(() {});
  }

  Future<void> _loadSecondaryChapter() async {
    try {
      final secData = await widget.apiClient.getChapter(
        translationId: secondaryTranslationId,
        bookCode: currentBookCode,
        chapter: currentChapter,
      );
      if (mounted) {
        setState(() {
          secondaryChapterData = secData;
        });
      }
    } catch (_) {}
  }

  void _toggleParallelMode() {
    HapticFeedback.lightImpact();
    setState(() {
      isParallelMode = !isParallelMode;
    });
    if (isParallelMode && (secondaryChapterData == null || secondaryChapterData!.chapter != currentChapter)) {
      _loadSecondaryChapter();
    }
  }

  String _getTranslationDisplayName(String id, [String? fallback]) {
    final match = _availableTranslations.where((t) => t['id'] == id).firstOrNull;
    if (match != null && match['name'] != null && match['name']!.isNotEmpty) {
      return match['name']!;
    }
    return fallback ?? id.toUpperCase();
  }

  void _swapParallelTranslations() {
    HapticFeedback.lightImpact();
    final tempId = currentTranslationId;
    final tempAbbr = currentTranslationAbbr;
    final tempChapter = chapterData;

    final targetPrimaryId = secondaryTranslationId;
    final targetPrimaryAbbr = secondaryTranslationAbbr;

    final targetSecondaryId = tempId;
    final targetSecondaryAbbr = tempAbbr;

    // Resolve or synthesize valid chapter data for the new primary translation
    final newPrimaryChapter = (secondaryChapterData != null)
        ? ChapterData(
            book: secondaryChapterData!.book,
            bookCode: secondaryChapterData!.bookCode,
            chapter: secondaryChapterData!.chapter,
            translationId: targetPrimaryId,
            translationName: _getTranslationDisplayName(targetPrimaryId, targetPrimaryAbbr),
            verses: secondaryChapterData!.verses,
          )
        : (ScriptureLibrary.getChapter(
                bookCode: currentBookCode,
                chapter: currentChapter,
                translationId: targetPrimaryId,
              ) ??
              (tempChapter != null
                  ? ChapterData(
                      book: tempChapter.book,
                      bookCode: tempChapter.bookCode,
                      chapter: tempChapter.chapter,
                      translationId: targetPrimaryId,
                      translationName: _getTranslationDisplayName(targetPrimaryId, targetPrimaryAbbr),
                      verses: tempChapter.verses,
                    )
                  : null));

    // Resolve or synthesize valid chapter data for the new secondary translation
    final newSecondaryChapter = (tempChapter != null)
        ? ChapterData(
            book: tempChapter.book,
            bookCode: tempChapter.bookCode,
            chapter: tempChapter.chapter,
            translationId: targetSecondaryId,
            translationName: _getTranslationDisplayName(targetSecondaryId, targetSecondaryAbbr),
            verses: tempChapter.verses,
          )
        : null;

    setState(() {
      currentTranslationId = targetPrimaryId;
      currentTranslationAbbr = targetPrimaryAbbr;
      chapterData = newPrimaryChapter;

      secondaryTranslationId = targetSecondaryId;
      secondaryTranslationAbbr = targetSecondaryAbbr;
      secondaryChapterData = newSecondaryChapter;
    });

    _loadSecondaryChapter();
  }

  Future<void> _loadChapter() async {
    setState(() => isLoading = true);
    final data = await widget.apiClient.getChapter(
      translationId: currentTranslationId,
      bookCode: currentBookCode,
      chapter: currentChapter,
    );
    final notes = await widget.apiClient.getNotes(bookCode: currentBookCode);
    final savedHighlights = StudyJournalService().getHighlightsForChapter(currentBookCode, currentChapter);

    if (mounted) {
      setState(() {
        chapterData = data;
        userNotes = notes;
        currentBookName = data.book.isNotEmpty ? data.book : currentBookName;
        _verseHighlights.clear();
        _verseHighlights.addAll(savedHighlights);
        isLoading = false;
      });
      StreakService().recordActivity(chaptersRead: 1);
    }
    if (isParallelMode) {
      _loadSecondaryChapter();
    }
  }

  void _onWordTapped(OriginalWord word) async {
    LexiconDetailModel? detail;
    if (word.strongsNumber != null) {
      detail = await widget.apiClient.getLexiconDetail(word.strongsNumber!);
    }
    if (!mounted) return;

    WordStudySheet.show(
      context,
      word: word,
      detail: detail,
      verseReference: '$currentBookName $currentChapter:${selectedVerseNumber ?? 1}',
      onSelectOccurrence: (occ) {
        setState(() {
          currentBookCode = occ.bookCode;
          currentChapter = occ.chapter;
          selectedVerseNumber = occ.verse;
          final matchedBook = BibleBook.allBooks.firstWhere(
            (b) => b.code == occ.bookCode.toUpperCase(),
            orElse: () => BibleBook(code: occ.bookCode, name: occ.bookCode, testament: 'NT', totalChapters: 1),
          );
          currentBookName = matchedBook.name;
        });
        _loadChapter();
      },
    );
  }

  void _openBookChapterPicker() async {
    final selection = await BookChapterPickerSheet.show(
      context,
      currentBookCode: currentBookCode,
      currentChapter: currentChapter,
    );

    if (selection != null) {
      setState(() {
        currentBookCode = selection.book.code;
        currentBookName = selection.book.name;
        currentChapter = selection.chapter;
        selectedVerseNumber = null;
      });
      _loadChapter();
    }
  }

  void _navigateChapter({required bool isPrevious}) {
    final target = isPrevious
        ? BibleBook.getPreviousChapter(currentBookCode, currentChapter)
        : BibleBook.getNextChapter(currentBookCode, currentChapter);
    if (target == null) return;
    setState(() {
      currentBookCode = target.code;
      currentBookName = target.name;
      currentChapter = target.chapter;
      selectedVerseNumber = null;
    });
    _loadChapter();
  }

  void _openTranslationPicker() {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: ext.paper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: ext.line)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: ext.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Translation',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ext.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '12 complete translations stored in database',
                        style: TextStyle(fontSize: 12, color: ext.inkSoft),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: ext.inkSoft),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Translation Cards List
              Expanded(
                child: ListView.builder(
                  itemCount: _availableTranslations.length,
                  itemBuilder: (context, index) {
                    final t = _availableTranslations[index];
                    final isSelected = t['id'] == currentTranslationId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          if (mounted) {
                            setState(() {
                              currentTranslationId = t['id']!;
                              currentTranslationAbbr = t['abbr']!;
                            });
                            _loadChapter();
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? ext.tealSoft : ext.paperSecondary,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? ext.teal : ext.line,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? ext.teal : ext.surfaceElevated,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  t['abbr']!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : ext.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t['name']!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? ext.teal : ext.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      t['desc']!,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: ext.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, size: 20, color: ext.teal),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openVerseActions(VerseModel verse) {
    setState(() {
      selectedVerseNumber = verse.verse;
    });

    VerseActionSheet.show(
      context,
      bookCode: currentBookCode,
      bookName: currentBookName,
      chapter: currentChapter,
      verse: verse.verse,
      verseText: verse.text,
      apiClient: widget.apiClient,
      onNoteSaved: (text) {
        _loadChapter();
      },
      onHighlightSelected: (color) {
        setState(() {
          _verseHighlights[verse.verse] = color;
        });
      },
      onOpenDeepStudy: () {
        if (verse.originalWords.isNotEmpty) {
          _onWordTapped(verse.originalWords.first);
        } else {
          _openFirstOriginalWord(verse);
        }
      },
      onOpenConnections: () => _openVerseConnections(verse),
    );
  }

  void _openVerseConnections(VerseModel verse) async {
    final connections = await widget.apiClient.getCrossReferences(
      bookCode: currentBookCode,
      chapter: currentChapter,
      verse: verse.verse,
      translationId: currentTranslationId,
    );
    if (!mounted) return;
    VerseConnectionsSheet.show(
      context,
      sourceBookName: currentBookName,
      sourceChapter: currentChapter,
      sourceVerse: verse.verse,
      sourceVerseText: verse.text,
      connections: connections,
      onNavigateToPassage: (bookCode, chapter, verseNum) {
        setState(() {
          currentBookCode = bookCode;
          currentChapter = chapter;
          selectedVerseNumber = verseNum;
          final matched = BibleBook.allBooks.firstWhere(
            (b) => b.code == bookCode.toUpperCase(),
            orElse: () => BibleBook(code: bookCode, name: bookCode, testament: 'NT', totalChapters: 1),
          );
          currentBookName = matched.name;
        });
        _loadChapter();
      },
    );
  }

  void _openFirstOriginalWord(VerseModel verse) {
    final tokens = VerseWordParser.parseVerse(verse.text, currentBookCode, verse.originalWords);
    final firstInteractive = tokens.where((t) => t.isInteractive && t.word != null).firstOrNull;
    if (firstInteractive != null) {
      _onWordTapped(firstInteractive.word!);
      return;
    }

    final isNT = BibleBook.allBooks.firstWhere(
      (b) => b.code == currentBookCode,
      orElse: () => BibleBook(code: currentBookCode, name: currentBookName, testament: 'NT', totalChapters: 1),
    ).testament == 'NT';

    _onWordTapped(isNT
        ? const OriginalWord(
            wordPosition: 1,
            surfaceForm: 'κύριος',
            lemma: 'κύριος',
            transliteration: 'kýrios',
            strongsNumber: 'G2962',
            language: 'greek',
            englishGloss: 'Lord',
          )
        : const OriginalWord(
            wordPosition: 1,
            surfaceForm: 'יְהֹוָה',
            lemma: 'יְהֹוָה',
            transliteration: "Yᵊhōvâ",
            strongsNumber: 'H3068',
            language: 'hebrew',
            englishGloss: 'LORD',
          ));
  }

  void _startAudioBible() {
    if (chapterData == null || chapterData!.verses.isEmpty) return;
    setState(() => showAudioBar = true);
    final startIndex = selectedVerseNumber != null
        ? chapterData!.verses.indexWhere((v) => v.verse == selectedVerseNumber)
        : 0;
    AudioBibleService().playChapter(
      chapterData!.verses,
      startVerseIndex: startIndex >= 0 ? startIndex : 0,
      bookName: currentBookName,
      bookCode: currentBookCode,
      chapter: currentChapter,
      translationId: currentTranslationId,
      apiClient: widget.apiClient,
    );
  }

  GlobalKey _getVerseKey(int verseNumber) {
    return _verseKeys.putIfAbsent(verseNumber, () => GlobalKey());
  }

  String _toSuperscript(int number) {
    const digits = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
    };
    return number.toString().split('').map((c) => digits[c] ?? c).join();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    final sectionKey = '${currentBookCode.toUpperCase()}_$currentChapter';
    final sectionTitle = _sectionHeadings[sectionKey] ?? '$currentBookName $currentChapter';

    return SafeArea(
      child: Scaffold(
        backgroundColor: ext.paper,
        body: Column(
          children: [
            // Top Navigation & Selector Bar
            if (isZenMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: ext.paperSecondary.withOpacity(0.6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_center_focus, size: 14, color: ext.gold),
                    const SizedBox(width: 8),
                    Text(
                      'FOCUS READING · $currentBookName $currentChapter',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: ext.gold,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => isZenMode = false),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ext.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ext.gold.withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, size: 12, color: ext.gold),
                            const SizedBox(width: 4),
                            Text(
                              'Exit Focus',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ext.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  if (selectedVerseNumber != null)
                    GestureDetector(
                      onTap: () {
                        setState(() => selectedVerseNumber = null);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
                        child: Icon(Icons.arrow_back_ios_new, size: 15, color: ext.ink),
                      ),
                    ),

                  // Previous Chapter Chevron
                  GestureDetector(
                    onTap: BibleBook.getPreviousChapter(currentBookCode, currentChapter) != null
                        ? () => _navigateChapter(isPrevious: true)
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                      child: Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: BibleBook.getPreviousChapter(currentBookCode, currentChapter) != null ? ext.inkSoft : ext.line,
                      ),
                    ),
                  ),

                  // Book & Chapter Picker (Plain text navigation with chevron)
                  Flexible(
                    child: GestureDetector(
                      onTap: _openBookChapterPicker,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '$currentBookName $currentChapter',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: ext.ink,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down, size: 16, color: ext.inkSoft),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Next Chapter Chevron
                  GestureDetector(
                    onTap: BibleBook.getNextChapter(currentBookCode, currentChapter) != null
                        ? () => _navigateChapter(isPrevious: false)
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                      child: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: BibleBook.getNextChapter(currentBookCode, currentChapter) != null ? ext.inkSoft : ext.line,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Translation Switcher (Plain text navigation with chevron)
                  if (!isParallelMode)
                    GestureDetector(
                      onTap: _openTranslationPicker,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentTranslationAbbr,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: ext.ink,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down, size: 15, color: ext.inkSoft),
                          ],
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Actions: Audio Bible & Interlinear toggle
                  GestureDetector(
                    onTap: _startAudioBible,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Icon(
                        Icons.volume_up_rounded,
                        size: 20,
                        color: (showAudioBar || AudioBibleService().isPlaying.value)
                            ? const Color(0xFFB45309)
                            : ext.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: () => setState(() => isInterlinearOn = !isInterlinearOn),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Icon(
                        isInterlinearOn ? Icons.translate : Icons.translate_outlined,
                        size: 18,
                        color: isInterlinearOn ? ext.teal : ext.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: _toggleParallelMode,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Icon(
                        isParallelMode ? Icons.vertical_split_rounded : Icons.vertical_split_outlined,
                        size: 19,
                        color: isParallelMode ? ext.teal : ext.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: () => setState(() => isZenMode = !isZenMode),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Icon(
                        isZenMode ? Icons.filter_center_focus : Icons.filter_center_focus_outlined,
                        size: 19,
                        color: isZenMode ? ext.gold : ext.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: ext.line, height: 1),

            // Main Reader Content: Displays ALL verses of the chapter
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: ext.teal))
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Heading
                          Text(
                            sectionTitle,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              color: ext.ink,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Parallel translation comparison or single flowing verses
                          if (isParallelMode && chapterData != null)
                            ParallelReaderView(
                              primaryChapter: chapterData!,
                              secondaryChapter: secondaryChapterData,
                              primaryTranslationId: currentTranslationId,
                              primaryTranslationAbbr: currentTranslationAbbr,
                              secondaryTranslationId: secondaryTranslationId,
                              secondaryTranslationAbbr: secondaryTranslationAbbr,
                              availableTranslations: _availableTranslations,
                              onSelectSecondaryTranslation: (t) {
                                setState(() {
                                  secondaryTranslationId = t['id']!;
                                  secondaryTranslationAbbr = t['abbr']!;
                                });
                                _loadSecondaryChapter();
                              },
                              onSwapTranslations: _swapParallelTranslations,
                              onSelectPrimaryTranslation: _openTranslationPicker,
                              onWordTapped: _onWordTapped,
                              onVerseTapped: (v) {
                                if (showAudioBar && AudioBibleService().isPlaying.value) {
                                  AudioBibleService().seekToVerse(v.verse);
                                } else {
                                  _openVerseActions(v);
                                }
                              },
                              activeAudioVerse: AudioBibleService().currentVerseNumber.value,
                              selectedVerseNumber: selectedVerseNumber,
                              fontFamily: _settings.readerFontFamily,
                              fontSize: _settings.readerFontSize,
                            )
                          else
                            _buildFlowingVerses(ext),

                          const SizedBox(height: 24),

                          // Previous / Next Chapter Navigation Card
                          _buildChapterNavigationCard(ext),

                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              'Tap any verse for connections & study • Tap gold words for Hebrew/Greek',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: ext.inkSoft,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),

            // Floating Audio Bible Bar (if active)
            ValueListenableBuilder<bool>(
              valueListenable: AudioBibleService().isPlaying,
              builder: (context, isPlaying, _) {
                return ValueListenableBuilder<int?>(
                  valueListenable: AudioBibleService().currentVerseNumber,
                  builder: (context, currentVerse, _) {
                    if (isPlaying || currentVerse != null || showAudioBar) {
                      return AudioPlayerBar(
                        onClose: () => setState(() => showAudioBar = false),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowingVerses(ScriptureThemeExtension ext) {
    final verses = chapterData?.verses ?? [];
    if (verses.isEmpty) {
      return Center(
        child: Text(
          'No verses found for this chapter.',
          style: TextStyle(color: ext.inkSoft),
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: AudioBibleService().isManuscriptMode,
      builder: (context, isManuscript, _) {
        return ValueListenableBuilder<int?>(
          valueListenable: AudioBibleService().currentVerseNumber,
          builder: (context, audioVerseNumber, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: verses.map((verse) {
                final isSelected = selectedVerseNumber == verse.verse;
                final isAudioActive = audioVerseNumber == verse.verse;
                final highlightColor = _verseHighlights[verse.verse];
                final matchingNotes = userNotes.where(
                  (n) => n.chapter == currentChapter && n.verse == verse.verse,
                );
                final hasNote = matchingNotes.isNotEmpty;
                final showInterlinear = isInterlinearOn || (isAudioActive && isManuscript);

                return GestureDetector(
                  key: _getVerseKey(verse.verse),
                  onTap: () {
                    if (showAudioBar && AudioBibleService().isPlaying.value) {
                      AudioBibleService().seekToVerse(verse.verse);
                    } else {
                      _openVerseActions(verse);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAudioActive
                          ? ext.gold.withOpacity(0.14)
                          : highlightColor != null
                              ? highlightColor.withOpacity(0.18)
                              : isSelected
                                  ? ext.paperSecondary
                                  : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isAudioActive
                          ? Border.all(color: ext.gold, width: 1.6)
                          : isSelected
                              ? Border.all(color: ext.gold.withOpacity(0.6), width: 1.2)
                              : null,
                      boxShadow: isAudioActive
                          ? [
                              BoxShadow(
                                color: ext.gold.withOpacity(0.20),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isAudioActive) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.volume_up_rounded, size: 13, color: ext.gold),
                              const SizedBox(width: 4),
                              Text(
                                isManuscript ? 'Manuscript Reading Sync' : 'Reading aloud',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                  color: ext.gold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        _buildVerseTextWithWords(verse, isSelected, showInterlinear, ext),
                        if (hasNote) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 14, color: ext.teal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              matchingNotes.first.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: ext.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  },
);
  }

  Widget _buildChapterNavigationCard(ScriptureThemeExtension ext) {
    final prev = BibleBook.getPreviousChapter(currentBookCode, currentChapter);
    final next = BibleBook.getNextChapter(currentBookCode, currentChapter);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (prev != null)
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateChapter(isPrevious: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: ext.paperSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ext.line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios_rounded, size: 16, color: ext.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Previous',
                              style: TextStyle(fontSize: 11, color: ext.inkSoft, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${prev.name} ${prev.chapter}',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ext.ink),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 10),
          if (next != null)
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateChapter(isPrevious: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: ext.paperSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ext.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Next',
                              style: TextStyle(fontSize: 11, color: ext.inkSoft, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${next.name} ${next.chapter}',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ext.ink),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: ext.teal),
                    ],
                  ),
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildVerseTextWithWords(
    VerseModel verse,
    bool isSelected,
    bool interlinear,
    ScriptureThemeExtension ext,
  ) {
    // 1. Genesis 1:1 Special Hebrew Word Mapping
    if (currentBookCode == 'GEN' && currentChapter == 1 && verse.verse == 1) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: interlinear ? 8 : 4,
        children: [
          Text(
            _toSuperscript(verse.verse),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ext.inkSoft),
          ),
          const SizedBox(width: 2),
          _goldWord(
            'In the beginning',
            const OriginalWord(
              wordPosition: 1,
              surfaceForm: 'בְּרֵאשִׁית',
              lemma: 'רֵאשִׁית',
              transliteration: "bərēʾšît",
              strongsNumber: 'H7225',
              language: 'hebrew',
              englishGloss: 'In the beginning',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _goldWord(
            'God',
            const OriginalWord(
              wordPosition: 2,
              surfaceForm: 'אֱלֹהִים',
              lemma: 'אֱלֹהִים',
              transliteration: "ʾĕlōhîm",
              strongsNumber: 'H430',
              language: 'hebrew',
              englishGloss: 'God',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _goldWord(
            'created',
            const OriginalWord(
              wordPosition: 3,
              surfaceForm: 'בָּרָא',
              lemma: 'בָּרָא',
              transliteration: "bārāʾ",
              strongsNumber: 'H1254',
              language: 'hebrew',
              englishGloss: 'created',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord('the heaven and the earth.', isSelected, ext),
        ],
      );
    }

    // 2. Genesis 1:2 & 1:3 Hebrew roots
    if (currentBookCode == 'GEN' && currentChapter == 1 && verse.verse == 2) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: interlinear ? 8 : 4,
        children: [
          Text(_toSuperscript(verse.verse), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ext.inkSoft)),
          const SizedBox(width: 2),
          _plainWord('And the earth was without form, and void; and darkness was upon the face of the deep. And the', isSelected, ext),
          _goldWord(
            'Spirit',
            const OriginalWord(
              wordPosition: 3,
              surfaceForm: 'רוּחַ',
              lemma: 'רוּחַ',
              transliteration: "rûaḥ",
              strongsNumber: 'H7307',
              language: 'hebrew',
              englishGloss: 'Spirit',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord('of', isSelected, ext),
          _goldWord(
            'God',
            const OriginalWord(
              wordPosition: 4,
              surfaceForm: 'אֱלֹהִים',
              lemma: 'אֱלֹהִים',
              transliteration: "ʾĕlōhîm",
              strongsNumber: 'H430',
              language: 'hebrew',
              englishGloss: 'God',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord('moved upon the face of the waters.', isSelected, ext),
        ],
      );
    }

    if (currentBookCode == 'GEN' && currentChapter == 1 && verse.verse == 3) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: interlinear ? 8 : 4,
        children: [
          Text(_toSuperscript(verse.verse), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ext.inkSoft)),
          const SizedBox(width: 2),
          _plainWord('And', isSelected, ext),
          _goldWord(
            'God',
            const OriginalWord(
              wordPosition: 1,
              surfaceForm: 'אֱלֹהִים',
              lemma: 'אֱלֹהִים',
              transliteration: "ʾĕlōhîm",
              strongsNumber: 'H430',
              language: 'hebrew',
              englishGloss: 'God',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord('said, Let there be', isSelected, ext),
          _goldWord(
            'light',
            const OriginalWord(
              wordPosition: 3,
              surfaceForm: 'אוֹר',
              lemma: 'אוֹר',
              transliteration: "ʾôr",
              strongsNumber: 'H216',
              language: 'hebrew',
              englishGloss: 'light',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord(': and there was light.', isSelected, ext),
        ],
      );
    }

    // 3. John 1:1 Greek Word Mapping
    if (currentBookCode == 'JHN' && currentChapter == 1 && verse.verse == 1) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: interlinear ? 8 : 4,
        children: [
          Text(_toSuperscript(verse.verse), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ext.inkSoft)),
          const SizedBox(width: 2),
          _plainWord('In the beginning was the', isSelected, ext),
          _goldWord(
            'Word,',
            const OriginalWord(
              wordPosition: 2,
              surfaceForm: 'λόγος',
              lemma: 'λόγος',
              transliteration: 'lógos',
              strongsNumber: 'G3056',
              language: 'greek',
              englishGloss: 'Word',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord('and the Word was with', isSelected, ext),
          _goldWord(
            'God,',
            const OriginalWord(
              wordPosition: 4,
              surfaceForm: 'θεός',
              lemma: 'θεός',
              transliteration: 'theós',
              strongsNumber: 'G2316',
              language: 'greek',
              englishGloss: 'God',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord('and the Word was God.', isSelected, ext),
        ],
      );
    }

    // 4. John 3:16 Greek Word Mapping
    if (currentBookCode == 'JHN' && currentChapter == 3 && verse.verse == 16) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: interlinear ? 8 : 4,
        children: [
          Text(_toSuperscript(verse.verse), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ext.inkSoft)),
          const SizedBox(width: 2),
          _plainWord('For', isSelected, ext),
          _goldWord(
            'God',
            const OriginalWord(
              wordPosition: 2,
              surfaceForm: 'θεός',
              lemma: 'θεός',
              transliteration: 'theós',
              strongsNumber: 'G2316',
              language: 'greek',
              englishGloss: 'God',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord('so', isSelected, ext),
          _goldWord(
            'loved',
            const OriginalWord(
              wordPosition: 3,
              surfaceForm: 'ἠγάπησεν',
              lemma: 'ἀγαπάω',
              transliteration: 'ēgápēsen',
              strongsNumber: 'G25',
              language: 'greek',
              englishGloss: 'loved',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord('the world, that he gave his only begotten', isSelected, ext),
          _goldWord(
            'Son',
            const OriginalWord(
              wordPosition: 5,
              surfaceForm: 'υἱός',
              lemma: 'υἱός',
              transliteration: 'huiós',
              strongsNumber: 'G5207',
              language: 'greek',
              englishGloss: 'Son',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord(', that whosoever believeth in him should not perish, but have everlasting', isSelected, ext),
          _goldWord(
            'life',
            const OriginalWord(
              wordPosition: 7,
              surfaceForm: 'ζωή',
              lemma: 'ζωή',
              transliteration: 'zōḗ',
              strongsNumber: 'G2222',
              language: 'greek',
              englishGloss: 'life',
            ),
            isSelected,
            interlinear,
            ext,
          ),
          _plainWord('.', isSelected, ext),
        ],
      );
    }

    // Universal theological token parser for all other verses across Scripture
    final tokens = VerseWordParser.parseVerse(verse.text, currentBookCode, verse.originalWords);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: interlinear ? 8 : 4,
      children: [
        Text(
          _toSuperscript(verse.verse),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ext.inkSoft),
        ),
        const SizedBox(width: 2),
        ...tokens.map((token) {
          if (token.isInteractive && token.word != null) {
            return _goldWord(token.text, token.word!, isSelected, interlinear, ext);
          } else {
            return _plainWord(token.text, isSelected, ext);
          }
        }),
      ],
    );
  }

  Widget _plainWord(String word, bool isSelected, ScriptureThemeExtension ext) {
    final font = _settings.readerFontFamily == 'Modern Sans' ? null : _settings.readerFontFamily;
    final size = _settings.readerFontSize;

    return Text(
      word,
      style: TextStyle(
        fontFamily: font,
        fontSize: size,
        height: 1.6,
        color: ext.ink,
        decoration: isSelected ? TextDecoration.underline : TextDecoration.none,
        decorationStyle: isSelected ? TextDecorationStyle.dotted : TextDecorationStyle.solid,
        decorationColor: ext.inkSoft,
      ),
    );
  }

  Widget _goldWord(
    String display,
    OriginalWord word,
    bool isSelected,
    bool interlinear,
    ScriptureThemeExtension ext,
  ) {
    final font = _settings.readerFontFamily == 'Modern Sans' ? null : _settings.readerFontFamily;
    final size = _settings.readerFontSize;

    return GestureDetector(
      onTap: () => _onWordTapped(word),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: ext.gold,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            child: Text(
              display,
              style: TextStyle(
                fontFamily: font,
                fontSize: size,
                fontWeight: FontWeight.bold,
                color: ext.gold,
              ),
            ),
          ),
          if (interlinear && word.transliteration != null) ...[
            const SizedBox(height: 2),
            Text(
              word.transliteration!,
              style: TextStyle(
                fontFamily: font,
                fontSize: (size * 0.65).clamp(10.0, 14.0),
                fontStyle: FontStyle.italic,
                color: ext.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
