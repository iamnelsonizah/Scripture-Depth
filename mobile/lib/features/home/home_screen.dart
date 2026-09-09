import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/models/scripture_models.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/audio_bible_service.dart';
import '../reader/widgets/word_study_sheet.dart';
import 'memorization_review_screen.dart';
import 'widgets/streak_sheet.dart';
import '../study/widgets/reading_plan_detail_sheet.dart';
import '../../core/network/supabase_service.dart';
import '../../core/services/app_settings_service.dart';

class HomeScreen extends StatefulWidget {
  final ApiClient apiClient;
  final SupabaseService? supabaseService;
  final VoidCallback onNavigateToRead;
  final VoidCallback onNavigateToStudy;

  const HomeScreen({
    super.key,
    required this.apiClient,
    this.supabaseService,
    required this.onNavigateToRead,
    required this.onNavigateToStudy,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DailyStudyModel? _dailyStudy;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    StreakService().init(widget.apiClient);
    StreakService().loadLocalStreak();
    _fetchDailyStudy();
  }

  Future<void> _fetchDailyStudy() async {
    final data = await widget.apiClient.getDailyStudy();
    if (mounted) {
      setState(() {
        _dailyStudy = data;
        _isLoading = false;
      });
    }
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'Good evening';
    } else {
      return 'Late night reflection';
    }
  }

  String _getUserGreeting(String greeting) {
    final authName = widget.supabaseService?.currentDisplayName;
    if (authName != null && authName.trim().isNotEmpty) {
      return '$greeting, $authName';
    }
    final customName = AppSettingsService().userName;
    if (customName.trim().isNotEmpty) {
      return '$greeting, $customName';
    }
    return greeting;
  }

  void _openWordOfTheDay(BuildContext context) async {
    final wotd = _dailyStudy?.wordOfTheDay;
    final strongs = wotd?.strongsNumber ?? 'G26';
    final lemma = wotd?.lemma ?? 'ἀγάπη';
    final xlit = wotd?.transliteration ?? 'agapē';
    final gloss = wotd?.shortDefinition ?? 'divine love';
    final lang = wotd?.language ?? 'greek';

    final word = OriginalWord(
      wordPosition: 1,
      surfaceForm: lemma,
      lemma: lemma,
      transliteration: xlit,
      strongsNumber: strongs,
      language: lang,
      englishGloss: gloss,
      morphDescription: 'Key biblical theological root',
    );

    final detail = await widget.apiClient.getLexiconDetail(strongs);
    if (context.mounted) {
      WordStudySheet.show(context, word: word, detail: detail);
    }
  }

  void _openMemorization(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MemorizationReviewScreen(apiClient: widget.apiClient),
      ),
    );
    _fetchDailyStudy();
    StreakService().loadLocalStreak();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    final plan = _dailyStudy?.readingPlan;
    final wotd = _dailyStudy?.wordOfTheDay;
    final vod = _dailyStudy?.verseOfTheDay;
    final memCount = _dailyStudy?.memorizationDueCount ?? 6;

    final streakService = StreakService();
    final streak = streakService.currentStreak.value;
    final studiedToday = streakService.studiedToday.value;

    final currentDay = plan?.currentDay ?? 12;
    final greeting = _getTimeBasedGreeting();
    final progressVal = plan != null ? plan.progressPercent : 0.40;

    return SafeArea(
      child: Scaffold(
        backgroundColor: ext.paper,
        body: RefreshIndicator(
          onRefresh: _fetchDailyStudy,
          color: const Color(0xFFB45309),
          backgroundColor: ext.paper,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Italic Greeting + Bold Serif Title
                Text(
                  _getUserGreeting(greeting),
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 18,
                    color: ext.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Continue your study',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: ext.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: ext.line, height: 1, thickness: 1),
                const SizedBox(height: 16),

                // Reading Plan Editorial Block (Hairline rules, no gradient, no floating shadow)
                GestureDetector(
                  onTap: () => ReadingPlanDetailSheet.show(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linear Metric & Percentage Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Reading plan · day $currentDay of ${plan?.durationDays ?? 30}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: ext.inkSoft,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progressVal * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ext.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Thin 2px Linear Progress Bar
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final clamped = progressVal.clamp(0.0, 1.0);
                          return Stack(
                            children: [
                              Container(
                                height: 2,
                                width: constraints.maxWidth,
                                color: ext.line,
                              ),
                              Container(
                                height: 2,
                                width: constraints.maxWidth * clamped,
                                color: const Color(0xFFB45309),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // Plan Title
                      Text(
                        plan?.title ?? 'The gospel of John',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: ext.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Verse Quote (Carries the emotional work)
                      Text(
                        '“${plan?.versePreview ?? "I am the vine; you are the branches. Whoever abides in me and I in him, he it is that bears much fruit."}”',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                          color: ext.ink,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bottom Metadata + Underlined Link: "Continue →"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${plan?.nextReading ?? "John 15:1-8"} · next up',
                              style: TextStyle(
                                fontSize: 13,
                                color: ext.inkSoft,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: widget.onNavigateToRead,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Continue →',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: ext.ink,
                                  decoration: TextDecoration.underline,
                                  decorationColor: ext.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: ext.line, height: 1, thickness: 1),

                // Plain Action Rows (Outline icons at rest, no colored bubbles, continuous list)
                _buildEditorialActionRow(
                  ext: ext,
                  icon: Icons.sync_alt,
                  title: '$memCount verses due for review',
                  subtitle: 'Swipe deck · spaced repetition',
                  onTap: () => _openMemorization(context),
                ),
                Divider(color: ext.line, height: 1, thickness: 1),
                _buildEditorialActionRow(
                  ext: ext,
                  icon: Icons.auto_stories_outlined,
                  title: 'Scripture connections and roots',
                  subtitle: 'Explore the web of truth · 12,800+ roots',
                  onTap: widget.onNavigateToStudy,
                ),
                Divider(color: ext.line, height: 1, thickness: 1),
                _buildEditorialActionRow(
                  ext: ext,
                  icon: Icons.local_fire_department_outlined,
                  title: '$streak-day streak',
                  subtitle: studiedToday
                      ? 'Studied today · tap to view weekly habit'
                      : 'Study today to maintain your streak',
                  onTap: () => StreakSheet.show(context),
                ),
                Divider(color: ext.line, height: 1, thickness: 1),
                const SizedBox(height: 18),

                // Word of the Day Section (Outline / Italic tag + Amber ink Greek display)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Word of the day',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: ext.inkSoft,
                        ),
                      ),
                    ),
                    Text(
                      wotd?.strongsNumber ?? 'G26',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 13.5,
                        color: ext.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: ext.line, height: 1, thickness: 1),
                const SizedBox(height: 18),

                // Full display treatment on the Greek word itself in amber ink with spoken pronunciation
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _openWordOfTheDay(context),
                      child: Text(
                        wotd?.lemma ?? 'ἀγάπη',
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309), // Amber ink
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Tooltip(
                      message: 'Pronounce ancient root',
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final lemma = wotd?.lemma ?? 'ἀγάπη';
                          final lang = (wotd?.strongsNumber?.startsWith('H') ?? false) ? 'hebrew' : 'greek';
                          AudioBibleService().pronounceWord(lemma, language: lang);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ext.paperSecondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: ext.line),
                          ),
                          child: Icon(
                            Icons.volume_up_outlined,
                            size: 20,
                            color: ext.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _openWordOfTheDay(context),
                  child: Text(
                    'agapē · divine unconditional love · tap to explore root depth ›',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: ext.inkSoft,
                    ),
                  ),
                ),

                // Verse of the Day Section (Quiet editorial styling)
                const SizedBox(height: 24),
                Divider(color: ext.line, height: 1, thickness: 1),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Verse of the day',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: ext.inkSoft,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${vod?.reference ?? "John 3:16"} · ${vod?.translationId ?? "ESV"}',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 13.5,
                        color: ext.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: widget.onNavigateToRead,
                  child: Text(
                    '“${vod?.text ?? "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life."}”',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: ext.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorialActionRow({
    required ScriptureThemeExtension ext,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: ext.inkSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: ext.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: ext.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: ext.inkSoft),
          ],
        ),
      ),
    );
  }
}
