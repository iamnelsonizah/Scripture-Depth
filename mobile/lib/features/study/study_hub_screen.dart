import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/scripture_models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/supabase_service.dart';
import '../reader/widgets/word_study_sheet.dart';
import '../home/memorization_review_screen.dart';
import '../../core/services/reading_plan_service.dart';
import '../../core/services/study_journal_service.dart';
import 'widgets/reading_plan_detail_sheet.dart';
import 'widgets/study_journal_sheet.dart';

class StudyHubScreen extends StatefulWidget {
  final ApiClient apiClient;
  final SupabaseService? supabaseService;
  final VoidCallback? onNavigateToRead;

  const StudyHubScreen({
    super.key,
    required this.apiClient,
    this.supabaseService,
    this.onNavigateToRead,
  });

  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  final TextEditingController _lexiconSearchController = TextEditingController();

  final List<Map<String, dynamic>> _coreTheologicalTerms = [
    {
      'title': 'Yahweh / The LORD',
      'strongs': 'H3068',
      'lemma': 'יְהֹוָה',
      'translit': "Yᵊhōvâ",
      'lang': 'hebrew',
      'meaning': 'The Self-Existent Eternal One; Covenant God of Israel',
      'category': 'Attributes of Deity',
    },
    {
      'title': 'Elohim / God',
      'strongs': 'H430',
      'lemma': 'אֱלֹהִים',
      'translit': "ʾĕlōhîm",
      'lang': 'hebrew',
      'meaning': 'Supreme Divinity, Creator of the Heavens and Earth',
      'category': 'Attributes of Deity',
    },
    {
      'title': 'Agape / Sacrificial Love',
      'strongs': 'G26',
      'lemma': 'ἀγάπη',
      'translit': 'agápē',
      'lang': 'greek',
      'meaning': 'Unconditional, benevolent, divine sacrificial love',
      'category': 'Divine Character',
    },
    {
      'title': 'Logos / The Living Word',
      'strongs': 'G3056',
      'lemma': 'λόγος',
      'translit': 'lógos',
      'lang': 'greek',
      'meaning': 'The Incarnate Revelation of God; Jesus Christ',
      'category': 'Christology',
    },
    {
      'title': 'Pneuma / The Holy Spirit',
      'strongs': 'G4151',
      'lemma': 'πνεῦμα',
      'translit': 'pneûma',
      'lang': 'greek',
      'meaning': 'The Spirit of God, Divine breath, life-giving wind',
      'category': 'Pneumatology',
    },
    {
      'title': 'Ruach / Spirit & Breath',
      'strongs': 'H7307',
      'lemma': 'רוּחַ',
      'translit': 'rûaḥ',
      'lang': 'hebrew',
      'meaning': 'Breath of God, Wind, Creative Divine Spirit',
      'category': 'Pneumatology',
    },
    {
      'title': 'Shalom / Complete Peace',
      'strongs': 'H7965',
      'lemma': 'שָׁלוֹם',
      'translit': 'šālôm',
      'lang': 'hebrew',
      'meaning': 'Wholeness, completeness, sound welfare, reconciliation',
      'category': 'Kingdom Blessings',
    },
    {
      'title': 'Hesed / Covenant Mercy',
      'strongs': 'H2617',
      'lemma': 'חֶסֶד',
      'translit': 'ḥesed',
      'lang': 'hebrew',
      'meaning': 'Steadfast lovingkindness, loyal covenant faithfulness',
      'category': 'Divine Character',
    },
    {
      'title': 'Pistis / Convicting Faith',
      'strongs': 'G4102',
      'lemma': 'πίστις',
      'translit': 'pístis',
      'lang': 'greek',
      'meaning': 'Firm persuasion, moral conviction of God\'s truth',
      'category': 'Christian Walk',
    },
    {
      'title': 'Charis / Unmerited Grace',
      'strongs': 'G5485',
      'lemma': 'χάρις',
      'translit': 'cháris',
      'lang': 'greek',
      'meaning': 'Free, unmerited divine favor and spiritual empowerment',
      'category': 'Salvation',
    },
  ];

  void _openWordStudy(Map<String, dynamic> term) async {
    final word = OriginalWord(
      wordPosition: 1,
      surfaceForm: term['lemma'],
      lemma: term['lemma'],
      transliteration: term['translit'],
      strongsNumber: term['strongs'],
      language: term['lang'],
      englishGloss: term['title'],
      morphDescription: term['meaning'],
    );

    final detail = await widget.apiClient.getLexiconDetail(term['strongs']);
    if (!mounted) return;

    WordStudySheet.show(
      context,
      word: word,
      detail: detail,
    );
  }

  String _selectedLanguageFilter = 'all';

  void _openCustomStrongs([String? custom]) async {
    if (custom != null) {
      _lexiconSearchController.text = custom;
    }
    final input = _lexiconSearchController.text.trim().toUpperCase();
    if (input.isEmpty) return;

    final isHebrew = input.startsWith('H');
    final word = OriginalWord(
      wordPosition: 1,
      surfaceForm: input,
      lemma: input,
      strongsNumber: input,
      language: isHebrew ? 'hebrew' : 'greek',
      englishGloss: 'Concordance Entry $input',
    );

    final detail = await widget.apiClient.getLexiconDetail(input);
    if (!mounted) return;

    WordStudySheet.show(
      context,
      word: word,
      detail: detail,
    );
  }

  List<Map<String, dynamic>> get _filteredTerms {
    if (_selectedLanguageFilter == 'hebrew') {
      return _coreTheologicalTerms.where((t) => t['lang'] == 'hebrew').toList();
    }
    if (_selectedLanguageFilter == 'greek') {
      return _coreTheologicalTerms.where((t) => t['lang'] == 'greek').toList();
    }
    return _coreTheologicalTerms;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF141210) : const Color(0xFFFAF8F5);
    final inkPrimary = isDark ? const Color(0xFFFAF5EF) : const Color(0xFF1C1917);
    final inkSecondary = isDark ? const Color(0xFF8E8881) : const Color(0xFF78716C);
    const accentRed = Color(0xFFE05638);
    const accentGold = Color(0xFFE5A93C);
    final dividerColor = isDark ? const Color(0xFF26221E) : const Color(0xFFE7E2DA);
    final chipBg = isDark ? const Color(0xFF1C1916) : const Color(0xFFF2EFEB);
    final chipBorder = isDark ? const Color(0xFF38322C) : const Color(0xFFD6CFC7);

    return SafeArea(
      child: Scaffold(
        backgroundColor: bg,
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study hub',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: inkPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Lexicon, plans and memorization',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: inkSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: accentGold,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: dividerColor, height: 1, thickness: 1),
              const SizedBox(height: 18),

              // Section 1: Active Reading Journey (The gospel of John)
              ValueListenableBuilder<ReadingPlanDetail?>(
                valueListenable: ReadingPlanService().activePlanNotifier,
                builder: (context, plan, _) {
                  if (plan == null) return const SizedBox.shrink();

                  final readingDay = plan.currentReadingDay;
                  final dayTitle = readingDay != null
                      ? 'Day ${readingDay.dayNumber}, ${readingDay.title.toLowerCase()}'
                      : 'Day ${plan.daysCompleted + 1}, the bread of life';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.category.toLowerCase(),
                            style: TextStyle(
                              fontSize: 13,
                              color: inkSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${plan.unlockedBadgeCount} of ${plan.badges.length} marks',
                            style: TextStyle(
                              fontSize: 13,
                              color: inkSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plan.title,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: inkPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.subtitle.toLowerCase(),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: inkSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.bookmark_rounded, size: 18, color: accentRed),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dayTitle,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: inkPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: plan.progressPercent,
                                backgroundColor: isDark ? const Color(0xFF2E2A27) : ext.line,
                                valueColor: const AlwaysStoppedAnimation<Color>(accentGold),
                                minHeight: 2.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '${plan.daysCompleted} of ${plan.durationDays} days',
                            style: TextStyle(fontSize: 13, color: inkSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => ReadingPlanDetailSheet.show(context),
                        child: const Text(
                          'Continue reading',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: accentRed,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Divider(color: dividerColor, height: 1, thickness: 1),
              const SizedBox(height: 18),

              // Section 2: Spaced Repetition (Scripture memorization)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spaced repetition',
                          style: TextStyle(fontSize: 13, color: inkSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scripture memorization',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '6 verses due for review today',
                          style: TextStyle(fontSize: 13.5, color: inkSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => MemorizationReviewScreen(
                            apiClient: widget.apiClient,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3D3833) : ext.line,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Practice',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: inkPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: dividerColor, height: 1, thickness: 1),
              const SizedBox(height: 18),

              // Section 3: Study journal
              ValueListenableBuilder<List<JournalEntryModel>>(
                valueListenable: StudyJournalService().entriesNotifier,
                builder: (context, entries, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Study journal',
                            style: TextStyle(fontSize: 13, color: inkSecondary),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => StudyJournalSheet.show(context),
                            child: const Text(
                              'Open journal',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: accentRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${entries.length} entries this month',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'Promises of God',
                          'Comfort and hope',
                          'Prophecy and glory',
                          'Doctrine and wisdom',
                          'Living and obedience',
                        ].map((themeLabel) {
                          return GestureDetector(
                            onTap: () => StudyJournalSheet.show(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                              decoration: BoxDecoration(
                                color: chipBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: chipBorder,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                themeLabel,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: inkPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Divider(color: dividerColor, height: 1, thickness: 1),
              const SizedBox(height: 18),

              // Section 4: Concordance Lookup
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Concordance',
                        style: TextStyle(fontSize: 13, color: inkSecondary),
                      ),
                      const Spacer(),
                      Text(
                        '8,674 OT · 5,624 NT',
                        style: TextStyle(fontSize: 12, color: inkSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Strong’s lookup',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: chipBorder),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.search, size: 18, color: accentGold),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lexiconSearchController,
                            style: TextStyle(fontSize: 13.5, color: inkPrimary),
                            onSubmitted: (_) => _openCustomStrongs(),
                            decoration: InputDecoration(
                              hintText: 'Enter Strong’s # (e.g. H430, G2316)...',
                              hintStyle: TextStyle(fontSize: 13, color: inkSecondary),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: accentRed),
                          onPressed: _openCustomStrongs,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text('Try: ', style: TextStyle(fontSize: 12, color: inkSecondary)),
                        const SizedBox(width: 4),
                        ...['H430 (God)', 'G26 (Love)', 'G3056 (Word)', 'H7965 (Peace)', 'G4102 (Faith)'].map((chip) {
                          final strongs = chip.split(' ').first;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => _openCustomStrongs(strongs),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: chipBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: chipBorder),
                                ),
                                child: Text(
                                  chip,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: inkPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: dividerColor, height: 1, thickness: 1),
              const SizedBox(height: 18),

              // Section 5: Original Languages (Hebrew & Greek Roots)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original languages',
                    style: TextStyle(fontSize: 13, color: inkSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Essential Hebrew & Greek roots',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any root word to inspect original lemma and biblical recurrences',
                    style: TextStyle(fontSize: 12.5, color: inkSecondary),
                  ),
                  const SizedBox(height: 12),
                  // Filter bar
                  Row(
                    children: [
                      _buildLanguageFilterChip('all', 'All roots (10)', inkPrimary, inkSecondary, chipBg, chipBorder, accentGold, isDark),
                      const SizedBox(width: 8),
                      _buildLanguageFilterChip('hebrew', 'Hebrew · OT (5)', inkPrimary, inkSecondary, chipBg, chipBorder, accentGold, isDark),
                      const SizedBox(width: 8),
                      _buildLanguageFilterChip('greek', 'Greek · NT (5)', inkPrimary, inkSecondary, chipBg, chipBorder, accentGold, isDark),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // List of items
                  ..._filteredTerms.map((term) {
                    final isHebrew = term['lang'] == 'hebrew';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: chipBorder),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openWordStudy(term),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    term['title'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: inkPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2E2720) : ext.goldSoft,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      term['strongs'],
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: accentGold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    term['lemma'],
                                    style: const TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: accentGold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${term['translit']})',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12.5,
                                      color: inkSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 11, color: inkSecondary),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                term['meaning'],
                                style: TextStyle(fontSize: 12, color: inkSecondary, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageFilterChip(
    String filterKey,
    String label,
    Color inkPrimary,
    Color inkSecondary,
    Color chipBg,
    Color chipBorder,
    Color accentGold,
    bool isDark,
  ) {
    final isSelected = _selectedLanguageFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLanguageFilter = filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF2E2720) : accentGold.withOpacity(0.15)) : chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentGold : chipBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? accentGold : inkSecondary,
          ),
        ),
      ),
    );
  }
}
