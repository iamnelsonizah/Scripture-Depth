import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/streak_service.dart';

class StreakSheet extends StatelessWidget {
  const StreakSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const StreakSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    final streakService = StreakService();
    final current = streakService.currentStreak.value;
    final longest = streakService.longestStreak.value;
    final studiedToday = streakService.studiedToday.value;

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: ext.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ext.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Flame Icon Badge
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A), width: 2),
            ),
            child: const Center(
              child: Text(
                '🔥',
                style: TextStyle(fontSize: 34),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            '$current-Day Study Streak',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
              color: ext.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            studiedToday
                ? "You've studied God's Word today. The flame is alive!"
                : "Complete a chapter reading or verse review to extend your streak!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: ext.inkSoft, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Weekly 7-Day Completion Tracker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ext.paperSecondary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ext.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final dayNum = index + 1;
                final dayName = weekdays[index];
                final isToday = dayNum == todayWeekday;
                final isPastOrToday = dayNum <= todayWeekday;
                final isCompleted = isPastOrToday && (dayNum < todayWeekday || studiedToday);

                return Column(
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                        color: isToday ? ext.teal : ext.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? const Color(0xFF059669)
                            : isToday
                                ? const Color(0xFFECFDF5)
                                : ext.paper,
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xFF059669)
                              : isToday
                                  ? const Color(0xFF10B981)
                                  : ext.line,
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                            : Text(
                                '${DateTime.now().subtract(Duration(days: todayWeekday - dayNum)).day}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isToday ? ext.teal : ext.inkSoft,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Milestone Stats Row
          Row(
            children: [
              Expanded(
                child: _statBox(
                  ext: ext,
                  title: 'Longest Streak',
                  value: '$longest days',
                  icon: Icons.emoji_events_outlined,
                  accent: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statBox(
                  ext: ext,
                  title: 'Study Habit',
                  value: 'Consistent',
                  icon: Icons.insights_rounded,
                  accent: ext.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Motivational Scripture Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ext.paperSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ext.line),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_stories_outlined, size: 18, color: ext.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '“Let the word of Christ dwell in you richly...” — Col 3:16',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      fontSize: 12.5,
                      color: ext.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required ScriptureThemeExtension ext,
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.paperSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, color: ext.inkSoft, fontWeight: FontWeight.w500),
              ),
              Icon(icon, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: ext.ink,
            ),
          ),
        ],
      ),
    );
  }
}
