import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class MapStop {
  final String title;
  final String reference;
  final Offset position; // Normalized coordinates (0.0 to 1.0)

  const MapStop({
    required this.title,
    required this.reference,
    required this.position,
  });
}

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  int activeStopIndex = 0;

  final List<MapStop> stops = const [
    MapStop(title: 'Antioch', reference: 'Acts 15:36', position: Offset(0.12, 0.8)),
    MapStop(title: 'Philippi', reference: 'Acts 16:12', position: Offset(0.38, 0.4)),
    MapStop(title: 'Athens', reference: 'Acts 17:16', position: Offset(0.65, 0.58)),
    MapStop(title: 'Corinth', reference: 'Acts 18:1', position: Offset(0.9, 0.22)),
  ];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    return SafeArea(
      child: Scaffold(
        backgroundColor: ext.paper,
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Paul's 2nd journey",
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ext.ink,
                ),
              ),
              const SizedBox(height: 16),

              // Route Visualizer Box
              Container(
                height: 180,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ext.paperSecondary,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ext.line),
                ),
                child: CustomPaint(
                  painter: _RoutePainter(
                    stops: stops,
                    activeIndex: activeStopIndex,
                    tealColor: ext.teal,
                    goldColor: ext.gold,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Stops Horizontal List
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stops.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final stop = stops[index];
                    final isActive = activeStopIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() => activeStopIndex = index);
                      },
                      child: Container(
                        width: 124,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? ext.goldSoft : ext.paperSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isActive ? ext.gold : ext.line,
                            width: isActive ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stop.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ext.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stop.reference,
                              style: TextStyle(
                                fontSize: 11,
                                color: ext.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Stop Detail Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ext.paperSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ext.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stops[activeStopIndex].title,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ext.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Biblical Reference: ${stops[activeStopIndex].reference}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ext.teal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paul departed with Silas, traveling through Syria and Cilicia, strengthening the churches.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: ext.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<MapStop> stops;
  final int activeIndex;
  final Color tealColor;
  final Color goldColor;

  _RoutePainter({
    required this.stops,
    required this.activeIndex,
    required this.tealColor,
    required this.goldColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stops.isEmpty) return;

    final path = Path();
    final points = stops
        .map((s) => Offset(s.position.dx * size.width, s.position.dy * size.height))
        .toList();

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final midX = (prev.dx + cur.dx) / 2;
      path.quadraticBezierTo(midX, prev.dy - 20, cur.dx, cur.dy);
    }

    // Draw dashed connecting path
    final pathPaint = Paint()
      ..color = tealColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, pathPaint);

    // Draw pins
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isActive = i == activeIndex;

      final pinPaint = Paint()
        ..color = isActive ? goldColor : tealColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(p, isActive ? 7.5 : 5.5, pinPaint);

      // Inner white dot for active pin
      if (isActive) {
        final whitePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 2.5, whitePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex ||
        oldDelegate.tealColor != tealColor ||
        oldDelegate.goldColor != goldColor;
  }
}
