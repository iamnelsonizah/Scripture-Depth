import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/audio_bible_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Slide 2 & Slide 4 audio player simulation state
  bool _isPlayingSlide2 = false;
  double _audioProgressSlide2 = 0.38;

  bool _isPlayingSlide4 = false;
  double _audioProgressSlide4 = 0.38;

  // Slide 3 translation selector state
  String _selectedTranslation = 'ESV';

  final Map<String, Map<String, String>> _translationPreviews = {
    'KJV': {
      'name': 'King James Version',
      'text':
          'In the beginning God created the heaven and the earth. And the earth was without form, and void; and darkness was upon the face of the deep.',
    },
    'ESV': {
      'name': 'English Standard Version',
      'text':
          'In the beginning, God created the heavens and the earth. The earth was without form and void, and darkness was over the face of the deep.',
    },
    'NIV': {
      'name': 'New International Version',
      'text':
          'In the beginning God created the heavens and the earth. Now the earth was formless and empty, darkness was over the surface of the deep.',
    },
    'NASB': {
      'name': 'New American Standard Bible',
      'text':
          'In the beginning God created the heavens and the earth. And the earth was a formless and desolate emptiness, and darkness was over the surface of the deep.',
    },
    'AMP': {
      'name': 'Amplified Bible',
      'text':
          'In the beginning God created [by forming from nothing] the heavens and the earth. The earth was without form and void, and darkness was upon the face of the deep.',
    },
  };

  @override
  void initState() {
    super.initState();
    final currentAbbr = AppSettingsService().selectedTranslation.toUpperCase();
    if (_translationPreviews.containsKey(currentAbbr)) {
      _selectedTranslation = currentAbbr;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    await AppSettingsService().setTranslation(_selectedTranslation);
    await AppSettingsService().setHasCompletedOnboarding(true);
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkSlide = _currentPage == 3;
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    // Palette: Screens 1-3 use light editorial paper; Screen 4 showcases dark sanctuary
    final bgColor = isDarkSlide ? const Color(0xFF11171E) : const Color(0xFFFAF7F2);
    final inkColor = isDarkSlide ? const Color(0xFFF5F2EB) : const Color(0xFF1C2228);
    final inkSoftColor = isDarkSlide ? const Color(0xFF98A3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Chrome: Brand + Subtitle tag + Skip button
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 19,
                    color: isDarkSlide ? const Color(0xFFD4AF37) : const Color(0xFF8C7A53),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ScriptureDepth',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: inkColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (isDarkSlide) ...[
                    const SizedBox(width: 10),
                    Text(
                      'Reading — Genesis 1',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 12.5,
                        color: inkSoftColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: _finishOnboarding,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: inkSoftColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Segmented Progress Bar (4 hairline segments)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
              child: Row(
                children: List.generate(4, (index) {
                  final isActive = index <= _currentPage;
                  final isCurrent = index == _currentPage;
                  return Expanded(
                    child: Container(
                      height: 2.2,
                      margin: EdgeInsets.only(right: index < 3 ? 5 : 0),
                      decoration: BoxDecoration(
                        color: isDarkSlide
                            ? (isActive ? const Color(0xFFD4AF37) : const Color(0xFF263442))
                            : (isActive
                                ? (isCurrent ? const Color(0xFF3B1D22) : const Color(0xFF8C7A53))
                                : const Color(0xFFE2DBD0)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 10),

            // Page View with the 4 Editorial Slides
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                children: [
                  _buildSlide1(inkColor, inkSoftColor),
                  _buildSlide2(inkColor, inkSoftColor),
                  _buildSlide3(inkColor, inkSoftColor),
                  _buildSlide4(inkColor, inkSoftColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SLIDE 1: A translation, and a voice to read it in.
  // ===========================================================================
  Widget _buildSlide1(Color ink, Color inkSoft) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Headline
                  Text(
                    'A translation,\nand a voice to\nread it in.',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.16,
                      color: ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'Every passage is narrated by a human reader and synced line by line with the text, so you can follow along without losing your place.',
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: inkSoft,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quote Card with Amber Vertical Left Rule
                  Container(
                    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFFC49A45), width: 2.2),
                      ),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Text(
                                '¹',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC49A45),
                                ),
                              ),
                            ),
                          ),
                          TextSpan(
                            text: 'In the beginning God created the heaven and the earth. ',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                              fontSize: 16,
                              height: 1.55,
                              color: ink,
                            ),
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 5, left: 2),
                              child: Text(
                                '²',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC49A45),
                                ),
                              ),
                            ),
                          ),
                          TextSpan(
                            text: 'And the earth was without form, and void.',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                              fontSize: 16,
                              height: 1.55,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Light Parchment Rounded Button: "Continue"
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _nextPage,
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFEFE9DC),
                foregroundColor: const Color(0xFF1C2228),
                side: const BorderSide(color: Color(0xFFDCD2C3), width: 1.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SLIDE 2: Words you can hear as well as read.
  // ===========================================================================
  Widget _buildSlide2(Color ink, Color inkSoft) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Headline
                  Text(
                    'Words you can\nhear as well as\nread.',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.16,
                      color: ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'Tap play and the narration follows the text at your pace — pause anywhere, and your place is kept.',
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: inkSoft,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Parchment Reader Card with Drop-Cap "I" & Audio Scrubber
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EDE2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2D8C7)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Verse 1 with Burgundy Drop Cap "I"
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'I',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 40,
                                height: 0.88,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF591C27), // Deep burgundy drop cap
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'n the beginning God created the heaven and the earth.',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  color: _isPlayingSlide2 ? const Color(0xFF591C27) : ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Verse 2
                        Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Text(
                                    '²',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF591C27),
                                    ),
                                  ),
                                ),
                              ),
                              TextSpan(
                                text:
                                    'And the earth was without form, and void; and darkness was upon the face of the deep.',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 14.5,
                                  height: 1.45,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Audio Scrubber Bar Inside Card
                        Row(
                          children: [
                            // Play/Pause circular button (Olive/golden)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isPlayingSlide2 = !_isPlayingSlide2;
                                });
                                if (_isPlayingSlide2) {
                                  AudioBibleService().pronounceWord('In the beginning God created the heaven and the earth', language: 'english');
                                }
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8C7A53),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlayingSlide2 ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 19,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Progress Track Line + Handle
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return GestureDetector(
                                    onHorizontalDragUpdate: (details) {
                                      final fraction = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                      setState(() => _audioProgressSlide2 = fraction);
                                    },
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        // Background track
                                        Container(
                                          height: 2.5,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD8CEBF),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        // Filled progress
                                        Container(
                                          height: 2.5,
                                          width: constraints.maxWidth * _audioProgressSlide2,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8C7A53),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        // Handle thumb
                                        Positioned(
                                          left: (constraints.maxWidth * _audioProgressSlide2) - 5,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF8C7A53),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Caption
                        Text(
                          'Genesis 1, King James Version',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                            fontSize: 11.5,
                            color: inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Light Parchment Rounded Button: "Continue"
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _nextPage,
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFEFE9DC),
                foregroundColor: const Color(0xFF1C2228),
                side: const BorderSide(color: Color(0xFFDCD2C3), width: 1.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SLIDE 3: Choose the translation you'll live in.
  // ===========================================================================
  Widget _buildSlide3(Color ink, Color inkSoft) {
    final previewData = _translationPreviews[_selectedTranslation] ?? _translationPreviews['ESV']!;
    final railPills = ['KJV', 'ESV', 'NIV', 'NASB', 'AMP'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Headline
                  Text(
                    "Choose the\ntranslation you'll\nlive in.",
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.16,
                      color: ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'Switch anytime — this just sets where you start.',
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: inkSoft,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Split Translation Card: Left Text Preview + Right Selector Rail
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EDE2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2D8C7)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Preview Area
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  previewData['name']!,
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF591C27), // Burgundy title
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  previewData['text']!,
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Right Side Rail: Vertical Translation Pills
                        Container(
                          width: 62,
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Color(0xFFE2D8C7)),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Column(
                            children: railPills.map((abbr) {
                              final isSelected = _selectedTranslation == abbr;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedTranslation = abbr);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF8C7A53) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      abbr,
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 11.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : inkSoft,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Deep Burgundy Button: "Get started"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A1521), // Deep rich burgundy
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Get started',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SLIDE 4: Same voice, quieter room. (Dark Room Showcase)
  // ===========================================================================
  Widget _buildSlide4(Color ink, Color inkSoft) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Headline
                  Text(
                    'Same voice,\nquieter room.',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.16,
                      color: ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'Night reading dims the page and warms the text so late sessions stay easy on the eyes.',
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: inkSoft,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Deep Dark Parchment Reader Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16212B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF243444)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Verse 1 with Warm Amber Drop Cap "I"
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'I',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 40,
                                height: 0.88,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD4AF37), // Warm amber gold drop cap
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'n the beginning God created the heaven and the earth.',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  color: _isPlayingSlide4 ? const Color(0xFFD4AF37) : ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Verse 2
                        Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Text(
                                    '²',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                                ),
                              ),
                              TextSpan(
                                text:
                                    'And the earth was without form, and void; and darkness was upon the face of the deep.',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 14.5,
                                  height: 1.45,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Audio Scrubber Bar Inside Dark Card
                        Row(
                          children: [
                            // Play/Pause circular button (Golden)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isPlayingSlide4 = !_isPlayingSlide4;
                                });
                                if (_isPlayingSlide4) {
                                  AudioBibleService().pronounceWord('In the beginning God created the heaven and the earth', language: 'english');
                                }
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8C7A53),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlayingSlide4 ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 19,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Progress Track Line + Handle
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return GestureDetector(
                                    onHorizontalDragUpdate: (details) {
                                      final fraction = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                      setState(() => _audioProgressSlide4 = fraction);
                                    },
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        // Background track
                                        Container(
                                          height: 2.5,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF283A4C),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        // Filled progress
                                        Container(
                                          height: 2.5,
                                          width: constraints.maxWidth * _audioProgressSlide4,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8C7A53),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        // Handle thumb
                                        Positioned(
                                          left: (constraints.maxWidth * _audioProgressSlide4) - 5,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF8C7A53),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Caption
                        Text(
                          'Genesis 1, King James Version',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                            fontSize: 11.5,
                            color: inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Deep Burgundy Action Button: "Get started"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finishOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A1521), // Deep rich burgundy
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Get started',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
