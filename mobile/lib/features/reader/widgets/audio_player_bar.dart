import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/audio_bible_service.dart';

/// Refined editorial floating audio player for Scripture narration.
/// Features a typographic hierarchy, animated soundwave indicator,
/// and responsive controls designed in the app's warm book aesthetic.
class AudioPlayerBar extends StatelessWidget {
  final VoidCallback onClose;

  const AudioPlayerBar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;
    final audioService = AudioBibleService();

    return ValueListenableBuilder<bool>(
      valueListenable: audioService.isPlaying,
      builder: (context, isPlaying, _) {
        return ValueListenableBuilder<int?>(
          valueListenable: audioService.currentVerseNumber,
          builder: (context, currentVerse, _) {
            if (!isPlaying && currentVerse == null) {
              return const SizedBox.shrink();
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                return ValueListenableBuilder<String?>(
                  valueListenable: audioService.currentReference,
                  builder: (context, currentRef, _) {
                    final displayTitle = currentRef ??
                        (currentVerse != null ? 'Verse $currentVerse' : 'Audio Bible');

                    return Container(
                      margin: EdgeInsets.fromLTRB(isNarrow ? 6 : 14, 0, isNarrow ? 6 : 14, 12),
                      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: ext.paperSecondary,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: ext.line, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: ext.ink.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                  child: Row(
                    children: [
                      // Minimalist animated soundwave indicator
                      _EditorialSoundWave(
                        isPlaying: isPlaying,
                        color: isPlaying ? const Color(0xFFB45309) : ext.inkSoft,
                      ),
                      const SizedBox(width: 10),

                      // Scripture Title & Subtitle (Single-line, non-wrapping)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayTitle,
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: ext.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            ValueListenableBuilder<String>(
                              valueListenable: audioService.fidelityLabel,
                              builder: (context, fidelity, _) {
                                return ValueListenableBuilder<bool>(
                                  valueListenable: audioService.isCachedOffline,
                                  builder: (context, isCached, _) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable: audioService.playbackSpeed,
                                      builder: (context, speed, _) {
                                        final speedStr = speed.toStringAsFixed(speed.truncateToDouble() == speed ? 0 : 2);
                                        final statusPrefix = isPlaying
                                            ? (isCached ? 'Alexander Scourby · Cached · ${speedStr}×' : '$fidelity · ${speedStr}×')
                                            : 'Paused';
                                        return Text(
                                          statusPrefix,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: ext.inkSoft,
                                            fontStyle: isPlaying ? FontStyle.normal : FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Previous Verse
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          audioService.previousVerse();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(Icons.skip_previous_rounded, size: 20, color: ext.ink),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // Play / Pause Toggle Button (Solid editorial ink button)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (isPlaying) {
                            audioService.pause();
                          } else {
                            audioService.resume();
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ext.ink,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 19,
                            color: ext.paper,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // Next Verse
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          audioService.nextVerse();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(Icons.skip_next_rounded, size: 20, color: ext.ink),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // 1-Tap Offline Cache Button
                      ValueListenableBuilder<bool>(
                        valueListenable: audioService.isCachedOffline,
                        builder: (context, isCached, _) {
                          return Tooltip(
                            message: isCached ? 'Cached offline' : 'Download for offline listening',
                            child: InkWell(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                if (!isCached) {
                                  final ok = await audioService.cacheCurrentChapter();
                                  if (context.mounted && ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Chapter audio downloaded for offline study.'),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  isCached ? Icons.download_done_rounded : Icons.arrow_circle_down_outlined,
                                  size: 17,
                                  color: isCached ? const Color(0xFF15803D) : ext.inkSoft,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 2),

                      if (!isNarrow) ...[
                        // Synchronized Manuscript / Grk/Heb Interlinear Toggle
                        ValueListenableBuilder<bool>(
                          valueListenable: audioService.isManuscriptMode,
                          builder: (context, isManuscript, _) {
                            return Tooltip(
                              message: isManuscript ? 'Manuscript mode active' : 'Show Greek/Hebrew lemmas',
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  audioService.isManuscriptMode.value = !isManuscript;
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isManuscript ? const Color(0xFFB45309).withValues(alpha: 0.15) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isManuscript ? const Color(0xFFB45309) : ext.line,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'Grk/Heb',
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 9.5,
                                      fontWeight: isManuscript ? FontWeight.bold : FontWeight.w600,
                                      color: isManuscript ? const Color(0xFFB45309) : ext.inkSoft,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 2),
                      ],

                      // Speed Multiplier Menu (Understated editorial link)
                      ValueListenableBuilder<double>(
                        valueListenable: audioService.playbackSpeed,
                        builder: (context, speed, _) {
                          final speedLabel = '${speed.toStringAsFixed(speed.truncateToDouble() == speed ? 0 : 2)}×';
                          return PopupMenuButton<double>(
                            initialValue: speed,
                            tooltip: 'Playback Speed',
                            color: ext.paper,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: ext.line),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                              child: Text(
                                speedLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ext.ink,
                                  decoration: TextDecoration.underline,
                                  decorationColor: const Color(0xFFB45309),
                                  decorationThickness: 1.5,
                                ),
                              ),
                            ),
                            onSelected: (newSpeed) {
                              HapticFeedback.lightImpact();
                              audioService.setSpeed(newSpeed);
                            },
                            itemBuilder: (context) => [
                              _buildSpeedMenuItem(0.75, '0.75× Slower', ext),
                              _buildSpeedMenuItem(1.0, '1.0× Normal', ext),
                              _buildSpeedMenuItem(1.25, '1.25× Faster', ext),
                              _buildSpeedMenuItem(1.5, '1.5× Brisk', ext),
                              _buildSpeedMenuItem(2.0, '2.0× Fast', ext),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 4),

                      // Stop / Close Button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          audioService.stop();
                          onClose();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(Icons.close_rounded, size: 18, color: ext.inkSoft),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  },
);
  }

  PopupMenuItem<double> _buildSpeedMenuItem(double value, String label, ScriptureThemeExtension ext) {
    return PopupMenuItem<double>(
      value: value,
      child: Text(
        label,
        style: TextStyle(fontSize: 13, color: ext.ink, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Dynamic 4-bar soundwave indicator that moves when audio is active.
class _EditorialSoundWave extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const _EditorialSoundWave({
    required this.isPlaying,
    required this.color,
  });

  @override
  State<_EditorialSoundWave> createState() => _EditorialSoundWaveState();
}

class _EditorialSoundWaveState extends State<_EditorialSoundWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    final isTesting = Platform.environment.containsKey('FLUTTER_TEST');
    if (widget.isPlaying && !isTesting) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _EditorialSoundWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      final isTesting = Platform.environment.containsKey('FLUTTER_TEST');
      if (widget.isPlaying && !isTesting) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.animateTo(0.0, duration: const Duration(milliseconds: 250));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final h1 = widget.isPlaying ? 7.0 + 8.0 * (0.5 + 0.5 * sin(t * 2 * pi)) : 5.0;
        final h2 = widget.isPlaying ? 7.0 + 11.0 * (0.5 + 0.5 * sin(t * 2 * pi + pi / 2.5)) : 8.0;
        final h3 = widget.isPlaying ? 7.0 + 9.0 * (0.5 + 0.5 * sin(t * 2 * pi + 2 * pi / 2.5)) : 6.0;
        final h4 = widget.isPlaying ? 5.0 + 7.0 * (0.5 + 0.5 * sin(t * 2 * pi + pi)) : 4.0;

        return SizedBox(
          width: 20,
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [h1, h2, h3, h4].map((h) {
              return Container(
                width: 2.5,
                height: h,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
