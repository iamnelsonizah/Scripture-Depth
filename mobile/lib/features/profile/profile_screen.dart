import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/supabase_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/streak_service.dart';
import '../auth/auth_modal.dart';
import '../home/memorization_review_screen.dart';
import '../home/widgets/streak_sheet.dart';
import 'widgets/profile_preference_sheets.dart';
import '../../core/services/ambient_soundscape_service.dart';
import '../onboarding/onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final SupabaseService supabaseService;
  final ApiClient? apiClient;

  const ProfileScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.supabaseService,
    this.apiClient,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ApiClient _apiClient;
  late final AppSettingsService _settings;
  int _streakDays = 1;
  int _memorizedCount = 6;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _settings = AppSettingsService();
    _settings.addListener(_onSettingsChanged);
    _loadDynamicStats();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDynamicStats() async {
    // 1. Get streak from local cache & backend
    await StreakService().loadLocalStreak();
    int activeStreak = StreakService().currentStreak.value;
    try {
      final streakData = await _apiClient.getStudyStreak();
      if (streakData != null && streakData['streak'] != null) {
        activeStreak = (streakData['streak'] as num).toInt();
      }
    } catch (_) {}

    // 2. Get memorization count
    int memorized = 6;
    try {
      final memStats = await _apiClient.getMemorizationStats();
      memorized = memStats['memorized_count'] ?? 6;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _streakDays = activeStreak > 0 ? activeStreak : 1;
        _memorizedCount = memorized;
        _isLoadingStats = false;
      });
      _settings.updateStats(streak: _streakDays, memorized: _memorizedCount);
    }
  }

  void _openAuthModal() {
    AuthModal.show(
      context,
      supabaseService: widget.supabaseService,
      onAuthSuccess: () {
        setState(() {}); // Refresh account state
        _loadDynamicStats();
      },
    );
  }

  void _signOut() async {
    await widget.supabaseService.signOut();
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Switched back to Guest Mode.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openStreakDetail() {
    HapticFeedback.lightImpact();
    StreakSheet.show(context);
  }

  void _openMemorizationDetail() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemorizationReviewScreen(apiClient: _apiClient),
      ),
    ).then((_) => _loadDynamicStats());
  }

  String get _translationDisplayName {
    switch (_settings.defaultTranslationId.toLowerCase()) {
      case 'amp':
        return 'Amplified';
      case 'kjv':
        return 'King James';
      case 'asv':
        return 'American Standard';
      case 'web':
        return 'World English';
      case 'esv':
        return 'ESV';
      case 'niv':
        return 'NIV';
      case 'nlt':
        return 'NLT';
      case 'nkjv':
        return 'NKJV';
      default:
        return _settings.defaultTranslationAbbr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    final isAuthenticated = widget.supabaseService.isAuthenticated;
    final userEmail = widget.supabaseService.currentUserEmail;

    return Scaffold(
      backgroundColor: ext.paper,
      body: Column(
        children: [
          // Dark Forest Hero Header
          Container(
            width: double.infinity,
            color: const Color(0xFF16251E),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Profile',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFDFBF7),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$_memorizedCount verses carried this year',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15.5,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reading as a guest / Sync Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: ext.isDark ? const Color(0xFF16251E) : const Color(0xFFF4EFE6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ext.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: ext.isDark ? const Color(0xFF24362C) : const Color(0xFF16251E),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isAuthenticated
                                ? Text(
                                    userEmail != null && userEmail.isNotEmpty
                                        ? userEmail[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Color(0xFFFDFBF7),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : const Text(
                                    '?',
                                    style: TextStyle(
                                      color: Color(0xFFFDFBF7),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAuthenticated ? (userEmail ?? 'Signed In') : 'Reading as a guest',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: ext.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAuthenticated
                                    ? 'All highlights, notes & streaks backed up'
                                    : 'Sign in and your progress follows you to every device.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ext.inkSoft,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: isAuthenticated ? _signOut : _openAuthModal,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: ext.ink.withOpacity(0.35), width: 1.0),
                            ),
                            child: Text(
                              isAuthenticated ? 'Sign out' : 'Sign in',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: ext.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Unified Dark Forest Stat Card
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16251E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Row(
                      children: [
                        // Streak Column
                        Expanded(
                          child: GestureDetector(
                            onTap: _openStreakDetail,
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$_streakDays',
                                      style: const TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFDFBF7),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'day${_streakDays == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 16,
                                        color: Color(0xFFD4AF37),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Current streak',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFFD4AF37).withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Vertical Hairline Divider
                        Container(
                          height: 48,
                          width: 1,
                          color: const Color(0xFF2D4035),
                        ),

                        // Memorized Column
                        Expanded(
                          child: GestureDetector(
                            onTap: _openMemorizationDetail,
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$_memorizedCount',
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFDFBF7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Verses memorized',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFFD4AF37).withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Appearance Section Title
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ext.ink,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Appearance: Underlined Tabs
                  Column(
                    children: [
                      Row(
                        children: [
                          _buildUnderlinedThemeTab('System', ThemeMode.system, ext),
                          _buildUnderlinedThemeTab('Light', ThemeMode.light, ext),
                          _buildUnderlinedThemeTab('Dark', ThemeMode.dark, ext),
                        ],
                      ),
                      Divider(color: ext.line, height: 1, thickness: 1),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Reading Preferences Section Title
                  Text(
                    'Reading preferences',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ext.ink,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Continuous Divided Preferences Stream
                  Column(
                    children: [
                      // 1. Default Translation
                      _buildEditorialPreferenceRow(
                        iconWidget: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF5B7065)),
                        label: 'Default translation',
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _translationDisplayName,
                              style: TextStyle(fontSize: 13.5, color: ext.inkSoft),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 16, color: ext.inkSoft),
                          ],
                        ),
                        onTap: () => ProfilePreferenceSheets.showTranslationSheet(context),
                        ext: ext,
                      ),
                      Divider(color: ext.line, height: 1),

                      // 2. Reading Font
                      _buildEditorialPreferenceRow(
                        iconWidget: const Text(
                          'A',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF5B7065),
                          ),
                        ),
                        label: 'Reading font',
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _settings.readerFontFamily,
                              style: TextStyle(fontSize: 13.5, color: ext.inkSoft),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 16, color: ext.inkSoft),
                          ],
                        ),
                        onTap: () => ProfilePreferenceSheets.showTypographySheet(context),
                        ext: ext,
                      ),
                      Divider(color: ext.line, height: 1),

                      // 3. Text Size
                      _buildEditorialPreferenceRow(
                        iconWidget: const Text(
                          'T',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF5B7065),
                          ),
                        ),
                        label: 'Text size',
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_settings.readerFontSize.round()} pt',
                              style: TextStyle(fontSize: 13.5, color: ext.inkSoft),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 16, color: ext.inkSoft),
                          ],
                        ),
                        onTap: () => ProfilePreferenceSheets.showTypographySheet(context),
                        ext: ext,
                      ),
                      Divider(color: ext.line, height: 1),

                      // 4. Audio Narration
                      _buildEditorialPreferenceRow(
                        iconWidget: const Icon(Icons.music_note_outlined, size: 18, color: Color(0xFF5B7065)),
                        label: 'Audio narration',
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_settings.audioVoice.split(' ').first}, ${_settings.audioSpeed}×',
                              style: TextStyle(fontSize: 13.5, color: ext.inkSoft),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 16, color: ext.inkSoft),
                          ],
                        ),
                        onTap: () => ProfilePreferenceSheets.showAudioVoiceSheet(context),
                        ext: ext,
                      ),
                      Divider(color: ext.line, height: 1),

                      // 5. Offline Downloads
                      _buildEditorialPreferenceRow(
                        iconWidget: const Icon(Icons.arrow_downward_rounded, size: 18, color: Color(0xFF5B7065)),
                        label: 'Offline downloads',
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF5B7065),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '12 translations ready',
                              style: TextStyle(fontSize: 13.5, color: ext.inkSoft),
                            ),
                          ],
                        ),
                        onTap: () => ProfilePreferenceSheets.showOfflineDownloadsSheet(context),
                        ext: ext,
                      ),
                      Divider(color: ext.line, height: 1),

                      // 6. Ambient Soundscape
                      _buildEditorialPreferenceRow(
                        iconWidget: const Icon(Icons.water_drop_outlined, size: 18, color: Color(0xFF5B7065)),
                        label: 'Ambient soundscape',
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AmbientSoundscapeService().activeSoundscapeId == 'none'
                                  ? 'Pure Voice'
                                  : AmbientSoundscapeService().activeSoundscapeId == 'rain'
                                      ? 'Monastery Rain'
                                      : 'Ancient Library',
                              style: TextStyle(fontSize: 13.5, color: ext.inkSoft),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 16, color: ext.inkSoft),
                          ],
                        ),
                        onTap: () => ProfilePreferenceSheets.showAmbientSoundscapesSheet(context),
                        ext: ext,
                      ),
                      Divider(color: ext.line, height: 1),

                      // 7. Welcome Tour & Features
                      _buildEditorialPreferenceRow(
                        iconWidget: const Icon(Icons.explore_outlined, size: 18, color: Color(0xFF5B7065)),
                        label: 'Welcome tour & features',
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Explore guide',
                              style: TextStyle(fontSize: 13.5, color: ext.teal, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 16, color: ext.teal),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OnboardingScreen(
                                onComplete: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          );
                        },
                        ext: ext,
                      ),
                    ],
                  ),
                  if (isAuthenticated) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton.icon(
                        onPressed: _signOut,
                        icon: Icon(Icons.logout_rounded, size: 16, color: ext.inkSoft),
                        label: Text(
                          'Sign out of this device',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ext.inkSoft,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const SizedBox(height: 32),
                  ],

                  // App Version Info
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'ScriptureDepth v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ext.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Universal Original Language Study & Concordance Engine',
                          style: TextStyle(
                            fontSize: 11,
                            color: ext.inkSoft.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnderlinedThemeTab(String label, ThemeMode mode, ScriptureThemeExtension ext) {
    final isSelected = widget.themeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onThemeModeChanged(mode);
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? ext.ink : ext.inkSoft,
                ),
              ),
            ),
            Container(
              height: 2.5,
              color: isSelected ? const Color(0xFFB45309) : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorialPreferenceRow({
    required Widget iconWidget,
    required String label,
    required Widget valueWidget,
    required VoidCallback onTap,
    required ScriptureThemeExtension ext,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Center(child: iconWidget),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: ext.ink,
                ),
              ),
            ),
            valueWidget,
          ],
        ),
      ),
    );
  }
}
