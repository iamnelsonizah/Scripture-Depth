import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/reading_plan_service.dart';

class ReadingPlanPickerSheet extends StatelessWidget {
  const ReadingPlanPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReadingPlanPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;
    final plans = ReadingPlanService().getAllPlans();
    final activeId = ReadingPlanService().activePlanId;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: ext.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Curated Reading Journeys',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ext.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select an active guided plan with milestone badges',
                        style: TextStyle(fontSize: 12.5, color: ext.inkSoft),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: ext.inkSoft),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Plans List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final plan = plans[index];
                final isSelected = plan.id == activeId;

                return GestureDetector(
                  onTap: () async {
                    await ReadingPlanService().setActivePlan(plan.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ext.paperSecondary,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? ext.teal : ext.line,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ext.tealSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                plan.category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: ext.teal,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ext.paper,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: ext.line),
                              ),
                              child: Text(
                                '${plan.durationDays} Days',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: ext.inkSoft,
                                ),
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_circle_rounded, color: ext.teal, size: 18),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          plan.title,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: ext.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.subtitle,
                          style: TextStyle(fontSize: 13, color: ext.inkSoft),
                        ),
                        const SizedBox(height: 12),
                        // Progress line
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: plan.progressPercent,
                                  backgroundColor: ext.line,
                                  valueColor: AlwaysStoppedAnimation<Color>(ext.teal),
                                  minHeight: 5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${plan.daysCompleted}/${plan.durationDays} completed',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: ext.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
