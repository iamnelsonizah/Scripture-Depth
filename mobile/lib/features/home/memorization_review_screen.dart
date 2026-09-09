import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/scripture_models.dart';
import '../../core/network/api_client.dart';
import '../../core/services/streak_service.dart';
import 'widgets/share_verse_sheet.dart';

class MemorizationReviewScreen extends StatefulWidget {
  final ApiClient apiClient;

  const MemorizationReviewScreen({super.key, required this.apiClient});

  @override
  State<MemorizationReviewScreen> createState() =>
      _MemorizationReviewScreenState();
}

class _MemorizationReviewScreenState extends State<MemorizationReviewScreen>
    with TickerProviderStateMixin {
  List<MemorizationCardModel> cards = [];
  int currentIndex = 0;
  bool isLoading = true;
  bool isCompleted = false;

  // Gesture drag tracking
  Offset _dragOffset = Offset.zero;

  // Swipe animation controller
  late AnimationController _swipeAnimController;
  late Animation<Offset> _swipeAnimation;

  // 3D Card Flip Animation
  late AnimationController _flipAnimController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;

  // History stack for undo
  final List<({int index, int rating})> _reviewHistory = [];

  // Atmospheric gradient palettes that dynamically cycle per card
  static const List<List<Color>> cardGradients = [
    [Color(0xFF064E3B), Color(0xFF059669)], // Emerald Dawn
    [Color(0xFF0F172A), Color(0xFF1E3A8A)], // Twilight Sapphire
    [Color(0xFF2E1065), Color(0xFF581C87)], // Royal Amethyst
    [Color(0xFF451A03), Color(0xFFB45309)], // Golden Shekinah
    [Color(0xFF4C0519), Color(0xFF9F1239)], // Rose of Sharon
    [Color(0xFF042F2E), Color(0xFF0F766E)], // Celestial Teal
  ];

  @override
  void initState() {
    super.initState();

    _swipeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _flipAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipAnimController, curve: Curves.easeInOutCubic),
    );

    _loadCards();
  }

  @override
  void dispose() {
    _swipeAnimController.dispose();
    _flipAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    final items = await widget.apiClient.getDueMemorization();
    if (mounted) {
      setState(() {
        cards = items;
        isLoading = false;
      });
    }
  }

  void _flipCard() {
    HapticFeedback.lightImpact();
    if (_isFlipped) {
      _flipAnimController.reverse();
    } else {
      _flipAnimController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _animateSwipe({required bool isRight}) {
    HapticFeedback.mediumImpact();
    final endX = isRight ? 500.0 : -500.0;
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(endX, _dragOffset.dy * 1.5),
    ).animate(CurvedAnimation(parent: _swipeAnimController, curve: Curves.easeOut));

    _swipeAnimController.forward(from: 0.0).then((_) {
      _submitReview(rating: isRight ? 5 : 1);
    });
  }

  void _springBack() {
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _swipeAnimController, curve: Curves.easeOutBack));

    _swipeAnimController.forward(from: 0.0).then((_) {
      setState(() {
        _dragOffset = Offset.zero;
      });
    });
  }

  void _submitReview({required int rating}) async {
    if (currentIndex >= cards.length) return;
    final current = cards[currentIndex];

    _reviewHistory.add((index: currentIndex, rating: rating));
    widget.apiClient.reviewMemorization(current.id, rating);

    // Record activity in live streak engine
    StreakService().recordActivity(cardsReviewed: 1);

    if (_isFlipped) {
      _flipAnimController.reset();
      _isFlipped = false;
    }

    if (currentIndex + 1 < cards.length) {
      setState(() {
        currentIndex++;
        _dragOffset = Offset.zero;
      });
    } else {
      setState(() {
        isCompleted = true;
        _dragOffset = Offset.zero;
      });
    }
  }

  void _undoPrevious() {
    if (_reviewHistory.isEmpty || currentIndex == 0) return;
    HapticFeedback.lightImpact();
    final last = _reviewHistory.removeLast();
    setState(() {
      currentIndex = last.index;
      isCompleted = false;
      _dragOffset = Offset.zero;
      if (_isFlipped) {
        _flipAnimController.reset();
        _isFlipped = false;
      }
    });
  }

  void _openShareSheet() {
    if (currentIndex >= cards.length) return;
    final current = cards[currentIndex];
    final colors = cardGradients[currentIndex % cardGradients.length];
    ShareVerseSheet.show(context, card: current, gradientColors: colors);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    return Scaffold(
      backgroundColor: ext.paper,
      appBar: AppBar(
        backgroundColor: ext.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ext.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'Verse Memorization',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: ext.ink,
              ),
            ),
            if (!isLoading && cards.isNotEmpty && !isCompleted)
              Text(
                '${currentIndex + 1} of ${cards.length} due today',
                style: TextStyle(fontSize: 11.5, color: ext.inkSoft, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (!isLoading && cards.isNotEmpty && !isCompleted)
            IconButton(
              icon: Icon(Icons.share_outlined, size: 20, color: ext.inkSoft),
              tooltip: 'Share verse',
              onPressed: _openShareSheet,
            ),
          if (_reviewHistory.isNotEmpty && !isCompleted)
            IconButton(
              icon: Icon(Icons.undo_rounded, size: 20, color: ext.inkSoft),
              tooltip: 'Undo last swipe',
              onPressed: _undoPrevious,
            ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: ext.teal))
          : isCompleted
              ? _buildCompletedView(ext)
              : cards.isEmpty
                  ? _buildEmptyState(ext)
                  : _buildDeckView(ext),
    );
  }

  Widget _buildEmptyState(ScriptureThemeExtension ext) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ext.tealSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_stories_outlined, color: ext.teal, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'All Caught Up!',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ext.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No verses are currently due for memory review.\nYou can add more verses while studying in the reader.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: ext.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: ext.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Return to Reader'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckView(ScriptureThemeExtension ext) {
    final progress = (currentIndex + 1) / cards.length;
    final dragNormalized = (_dragOffset.dx / 120).clamp(-1.0, 1.0);

    return SafeArea(
      child: Column(
        children: [
          // Top Sleek Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: ext.line,
                valueColor: AlwaysStoppedAnimation<Color>(ext.teal),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stacked Card Deck Area
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 3rd card in background
                      if (currentIndex + 2 < cards.length)
                        _buildBackgroundCard(
                          cards[currentIndex + 2],
                          cardIndex: currentIndex + 2,
                          depth: 2,
                          ext: ext,
                        ),

                      // 2nd card in background
                      if (currentIndex + 1 < cards.length)
                        _buildBackgroundCard(
                          cards[currentIndex + 1],
                          cardIndex: currentIndex + 1,
                          depth: 1,
                          ext: ext,
                          dragProgress: dragNormalized.abs(),
                        ),

                      // Active top card with swipe & 3D flip & dynamic gradient
                      _buildInteractiveTopCard(cards[currentIndex], ext),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Control Bar (OpenSourceUI aesthetic)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: _buildControlBar(ext),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundCard(
    MemorizationCardModel card, {
    required int cardIndex,
    required int depth,
    required ScriptureThemeExtension ext,
    double dragProgress = 0.0,
  }) {
    final colors = cardGradients[cardIndex % cardGradients.length];

    final scaleBase = depth == 1 ? 0.94 : 0.88;
    final scaleTarget = depth == 1 ? 1.0 : 0.94;
    final scale = scaleBase + (scaleTarget - scaleBase) * dragProgress;

    final yOffsetBase = depth == 1 ? 16.0 : 30.0;
    final yOffsetTarget = depth == 1 ? 0.0 : 16.0;
    final yOffset = yOffsetBase - (yOffsetBase - yOffsetTarget) * dragProgress;

    final opacity = (depth == 1 ? 0.85 : 0.55) + (0.15 * dragProgress);

    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    card.reference,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveTopCard(
    MemorizationCardModel card,
    ScriptureThemeExtension ext,
  ) {
    final colors = cardGradients[currentIndex % cardGradients.length];

    return AnimatedBuilder(
      animation: _swipeAnimController,
      builder: (context, child) {
        final currentOffset = _swipeAnimController.isAnimating
            ? _swipeAnimation.value
            : _dragOffset;

        final rotationAngle = (currentOffset.dx / 350) * 0.22;

        return Transform.translate(
          offset: currentOffset,
          child: Transform.rotate(
            angle: rotationAngle,
            child: GestureDetector(
              onPanStart: (_) {
                _swipeAnimController.stop();
              },
              onPanUpdate: (details) {
                setState(() {
                  _dragOffset += details.delta;
                });
              },
              onPanEnd: (details) {
                final vx = details.velocity.pixelsPerSecond.dx;
                if (_dragOffset.dx > 110 || vx > 650) {
                  _animateSwipe(isRight: true);
                } else if (_dragOffset.dx < -110 || vx < -650) {
                  _animateSwipe(isRight: false);
                } else {
                  _springBack();
                }
              },
              onTap: _flipCard,
              child: Stack(
                children: [
                  // 3D Flippable Card Surface
                  AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, _) {
                      final val = _flipAnimation.value;
                      final isUnder = val > 0.5;

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // perspective
                          ..rotateY(val * math.pi),
                        child: isUnder
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(math.pi),
                                child: _buildCardBack(card, colors, ext),
                              )
                            : _buildCardFront(card, colors, ext),
                      );
                    },
                  ),

                  // Dynamic Swipe Stamps
                  if (currentOffset.dx > 20)
                    Positioned(
                      top: 24,
                      right: 24,
                      child: Transform.rotate(
                        angle: 0.15,
                        child: Opacity(
                          opacity: ((currentOffset.dx - 20) / 90).clamp(0.0, 1.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF10B981), width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF059669)),
                                SizedBox(width: 6),
                                Text(
                                  'REMEMBERED',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (currentOffset.dx < -20)
                    Positioned(
                      top: 24,
                      left: 24,
                      child: Transform.rotate(
                        angle: -0.15,
                        child: Opacity(
                          opacity: ((-currentOffset.dx - 20) / 90).clamp(0.0, 1.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF43F5E), width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 18, color: Color(0xFFE11D48)),
                                SizedBox(width: 6),
                                Text(
                                  'REVIEW AGAIN',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardFront(
    MemorizationCardModel card,
    List<Color> colors,
    ScriptureThemeExtension ext,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top pill & interval info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'SCRIPTURE MEMORY',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Interval: ${card.intervalDays}d',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Scripture Reference Header in Georgia serif
          Text(
            card.reference,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          // Seamless Recitation Prompt on Card Gradient
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Recite this verse silently or aloud from memory,\nthen tap to reveal the full scripture.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 14.5,
                color: Colors.white.withOpacity(0.88),
                height: 1.55,
              ),
            ),
          ),

          const Spacer(),

          // Tap to flip hint - Frosted Glass Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined, size: 15, color: Colors.white),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Tap card to reveal verse',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildCardBack(
    MemorizationCardModel card,
    List<Color> colors,
    ScriptureThemeExtension ext,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[1].withOpacity(0.95),
            colors[0],
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with small reference pill & flip/share buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  card.reference,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _openShareSheet,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined, size: 15, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _flipCard,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flip_to_back_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Full Verse Text
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  '“${card.verseText}”',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.68,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bottom swipe instruction
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFFFB7185)),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Left: Again',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Color(0xFFFB7185), fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          'Right: Know it',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Color(0xFF34D399), fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF34D399)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(ScriptureThemeExtension ext) {
    return Row(
      children: [
        // Again / Hard Button
        Expanded(
          child: _circularActionButton(
            icon: Icons.refresh_rounded,
            label: 'Again',
            color: const Color(0xFFF43F5E),
            backgroundColor: const Color(0xFFFFF1F2),
            borderColor: const Color(0xFFFECDD3),
            onTap: () => _animateSwipe(isRight: false),
          ),
        ),
        const SizedBox(width: 8),

        // Flip Card Button
        Expanded(
          child: _circularActionButton(
            icon: Icons.flip_to_back_rounded,
            label: 'Flip',
            color: ext.ink,
            backgroundColor: ext.paperSecondary,
            borderColor: ext.line,
            onTap: _flipCard,
          ),
        ),
        const SizedBox(width: 8),

        // Share Button
        Expanded(
          child: _circularActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            color: const Color(0xFF0284C7),
            backgroundColor: const Color(0xFFF0F9FF),
            borderColor: const Color(0xFFBAE6FD),
            onTap: _openShareSheet,
          ),
        ),
        const SizedBox(width: 8),

        // Remembered / Easy Button
        Expanded(
          child: _circularActionButton(
            icon: Icons.check_rounded,
            label: 'Know It',
            color: const Color(0xFF059669),
            backgroundColor: const Color(0xFFECFDF5),
            borderColor: const Color(0xFFA7F3D0),
            onTap: () => _animateSwipe(isRight: true),
          ),
        ),
      ],
    );
  }

  Widget _circularActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedView(ScriptureThemeExtension ext) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFECFDF5),
                border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              'Session Complete!',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ext.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "You've reviewed all ${cards.length} due verses for today.\nYour SuperMemo memory intervals have updated in the database.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ext.inkSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ext.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
