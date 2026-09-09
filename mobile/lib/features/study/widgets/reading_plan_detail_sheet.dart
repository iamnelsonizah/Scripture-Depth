import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/reading_plan_service.dart';
import '../../../core/services/reader_navigation_service.dart';
import 'reading_plan_picker_sheet.dart';

class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  DashedCirclePainter({
    required this.color,
    this.strokeWidth = 1.4,
    this.dashCount = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    const totalAngle = 2 * 3.141592653589793;
    final segmentAngle = totalAngle / dashCount;
    final dashAngle = segmentAngle * 0.55;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * segmentAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashCount != dashCount;
}

class ReadingPlanDetailSheet extends StatefulWidget {
  final String? initialPlanId;

  const ReadingPlanDetailSheet({super.key, this.initialPlanId});

  static Future<void> show(BuildContext context, {String? initialPlanId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReadingPlanDetailSheet(initialPlanId: initialPlanId),
    );
  }

  @override
  State<ReadingPlanDetailSheet> createState() => _ReadingPlanDetailSheetState();
}

class _ReadingPlanDetailSheetState extends State<ReadingPlanDetailSheet> {
  int _selectedTabIndex = 0; // 0: Days checklist, 1: Milestone badges

  String _formatCategory(String cat) {
    if (cat.toLowerCase().contains('gospel')) {
      return 'Gospels and Christology';
    }
    if (cat.toLowerCase().contains('paul') || cat.toLowerCase().contains('epistle')) {
      return 'Pauline Epistles & Theology';
    }
    if (cat.toLowerCase().contains('wisdom')) {
      return 'Wisdom and Poetry';
    }
    if (cat.toLowerCase().contains('prophet')) {
      return 'Prophets and Revelation';
    }
    final cleaned = cat.replaceAll('_', ' ').replaceAll('&', 'and');
    if (cleaned.isEmpty) return 'Scripture Study Plan';
    return cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    return ValueListenableBuilder<ReadingPlanDetail?>(
      valueListenable: ReadingPlanService().activePlanNotifier,
      builder: (context, plan, _) {
        if (plan == null) {
          return const SizedBox(height: 200);
        }

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: ext.paper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: ext.line)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ext.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Editorial Header (No dark gradient, no floating shadow)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Eyebrow + Switch Plan Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatCategory(plan.category),
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                              fontSize: 15,
                              color: ext.inkSoft,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => ReadingPlanPickerSheet.show(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Switch plan',
                              style: TextStyle(
                                fontSize: 13.5,
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
                    const SizedBox(height: 8),

                    // Plan Title: "The Gospel of John"
                    Text(
                      plan.title,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: ext.ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Subtitle: "The living Word and divine signs"
                    Text(
                      plan.subtitle,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 15.5,
                        color: ext.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(color: ext.line, height: 1, thickness: 1),
                    const SizedBox(height: 14),

                    // Linear Metric & 2px Thin Line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${plan.daysCompleted} of ${plan.durationDays} days completed',
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
                          '${(plan.progressPercent * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 13.5,
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
                        final clamped = plan.progressPercent.clamp(0.0, 1.0);
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
                    const SizedBox(height: 10),

                    // Milestone badge stat
                    Text(
                      '${plan.unlockedBadgeCount} of ${plan.badges.length} milestone badges earned',
                      style: TextStyle(
                        fontSize: 13,
                        color: ext.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(color: ext.line, height: 1, thickness: 1),
                  ],
                ),
              ),

              // Underlined Tabs (Matching search screen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                child: Row(
                  children: [
                    _buildUnderlinedTab(
                      label: 'Day checklist',
                      count: plan.days.length,
                      isSelected: _selectedTabIndex == 0,
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      ext: ext,
                    ),
                    const SizedBox(width: 24),
                    _buildUnderlinedTab(
                      label: 'Milestone badges',
                      count: plan.badges.length,
                      isSelected: _selectedTabIndex == 1,
                      onTap: () => setState(() => _selectedTabIndex = 1),
                      ext: ext,
                    ),
                  ],
                ),
              ),
              Divider(color: ext.line, height: 1, thickness: 1),

              // Tab View Content
              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildDaysList(context, plan, ext)
                    : _buildBadgesList(context, plan, ext),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnderlinedTab({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required ScriptureThemeExtension ext,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? ext.ink : ext.inkSoft,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: isSelected ? 36 : 0,
            color: const Color(0xFFB45309),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysList(BuildContext context, ReadingPlanDetail plan, ScriptureThemeExtension ext) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      itemCount: plan.days.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Divider(color: ext.line.withOpacity(0.7), height: 1, thickness: 1),
      ),
      itemBuilder: (context, index) {
        final day = plan.days[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status, Day, Verse Span, and Read > Link
            Row(
              children: [
                // Status Checkmark (Inline check or dashed circle)
                GestureDetector(
                  onTap: () => ReadingPlanService().toggleDayCompleted(plan.id, day.dayNumber),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: day.isCompleted
                        ? const Icon(Icons.check, size: 17, color: Color(0xFF10B981))
                        : SizedBox(
                            width: 15,
                            height: 15,
                            child: CustomPaint(
                              painter: DashedCirclePainter(color: ext.inkSoft),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),

                // Day number
                Text(
                  'Day ${day.dayNumber}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ext.ink,
                  ),
                ),
                const SizedBox(width: 10),

                // Verse Span
                Expanded(
                  child: Text(
                    day.verseSpan,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      color: ext.inkSoft,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // Read > text link
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    ReaderNavigationService().navigateTo(
                      bookCode: day.bookCode,
                      bookName: day.bookName,
                      chapter: day.chapter,
                      verse: 1,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Read >',
                      style: TextStyle(
                        fontSize: 13.5,
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
            const SizedBox(height: 8),

            // Day Title
            Text(
              day.title,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ext.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),

            // Verse Preview Quote
            Text(
              '“${day.versePreview}”',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: ext.ink,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 6),

            // Reflection Commentary
            Text(
              day.reflection,
              style: TextStyle(
                fontSize: 13.5,
                color: ext.inkSoft,
                height: 1.45,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadgesList(BuildContext context, ReadingPlanDetail plan, ScriptureThemeExtension ext) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      itemCount: plan.badges.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(color: ext.line.withOpacity(0.7), height: 1, thickness: 1),
      ),
      itemBuilder: (context, index) {
        final badge = plan.badges[index];
        final isUnlocked = badge.isUnlocked;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isUnlocked ? badge.icon : Icons.lock_outline_rounded,
              color: isUnlocked ? const Color(0xFFB45309) : ext.inkSoft,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          badge.name,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ext.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isUnlocked
                            ? 'Earned'
                            : '${plan.daysCompleted}/${badge.dayRequirement} days',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 12.5,
                          color: isUnlocked ? const Color(0xFFB45309) : ext.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: ext.inkSoft,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
