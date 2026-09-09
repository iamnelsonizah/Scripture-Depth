import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/scripture_models.dart';
import '../../../../core/services/verse_word_parser.dart';

/// Aligned dual-translation comparison view for serious Scripture study.
/// Displays comparative stacked verses across two translations in an editorial stream.
class ParallelReaderView extends StatelessWidget {
  final ChapterData primaryChapter;
  final ChapterData? secondaryChapter;
  final String? primaryTranslationId;
  final String? primaryTranslationAbbr;
  final String secondaryTranslationId;
  final String secondaryTranslationAbbr;
  final List<Map<String, String>> availableTranslations;
  final ValueChanged<Map<String, String>> onSelectSecondaryTranslation;
  final VoidCallback onSwapTranslations;
  final VoidCallback? onSelectPrimaryTranslation;
  final Function(OriginalWord) onWordTapped;
  final Function(VerseModel) onVerseTapped;
  final int? activeAudioVerse;
  final int? selectedVerseNumber;
  final String fontFamily;
  final double fontSize;

  const ParallelReaderView({
    super.key,
    required this.primaryChapter,
    required this.secondaryChapter,
    this.primaryTranslationId,
    this.primaryTranslationAbbr,
    required this.secondaryTranslationId,
    required this.secondaryTranslationAbbr,
    required this.availableTranslations,
    required this.onSelectSecondaryTranslation,
    required this.onSwapTranslations,
    this.onSelectPrimaryTranslation,
    required this.onWordTapped,
    required this.onVerseTapped,
    this.activeAudioVerse,
    this.selectedVerseNumber,
    required this.fontFamily,
    required this.fontSize,
  });

  String get _primaryDisplayName {
    final targetId = primaryTranslationId ?? primaryChapter.translationId;
    final match = availableTranslations.where((t) => t['id'] == targetId).firstOrNull;
    if (match != null && match['name'] != null && match['name']!.isNotEmpty) {
      return match['name']!;
    }
    if (primaryChapter.translationName.length > 4) {
      return primaryChapter.translationName;
    }
    return primaryChapter.translationName;
  }

  String? _effectiveFont(String family) {
    if (family == 'Modern Sans') return null;
    return family;
  }

  void _openSecondaryTranslationPicker(BuildContext context, ScriptureThemeExtension ext) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ext.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ext.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compare Translation',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ext.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose second version to align stacked comparison',
                            style: TextStyle(fontSize: 12, color: ext.inkSoft),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 20, color: ext.inkSoft),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: availableTranslations.length,
                      separatorBuilder: (_, __) => Divider(color: ext.line, height: 1),
                      itemBuilder: (context, index) {
                        final t = availableTranslations[index];
                        final isSelected = t['id'] == secondaryTranslationId;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(ctx).pop();
                            onSelectSecondaryTranslation(t);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    t['abbr'] ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSelected ? const Color(0xFFB45309) : ext.ink,
                                      decoration: isSelected ? TextDecoration.underline : null,
                                      decorationColor: const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t['name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: ext.ink,
                                        ),
                                      ),
                                      if (t['desc'] != null && t['desc']!.isNotEmpty)
                                        Text(
                                          t['desc']!,
                                          style: TextStyle(fontSize: 12, color: ext.inkSoft),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check, color: Color(0xFFB45309), size: 18),
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    // Build secondary verse lookup map
    final secondaryMap = <int, VerseModel>{};
    if (secondaryChapter != null) {
      for (final v in secondaryChapter!.verses) {
        secondaryMap[v.verse] = v;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comparison Header Line: "Amplified Bible ⇆ AMP"
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onSelectPrimaryTranslation,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      _primaryDisplayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: ext.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSwapTranslations();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Icon(
                        Icons.compare_arrows_rounded,
                        size: 20,
                        color: ext.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openSecondaryTranslationPicker(context, ext),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      secondaryTranslationAbbr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: ext.ink,
                        decoration: TextDecoration.underline,
                        decorationColor: ext.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: ext.line, height: 1, thickness: 1),
            ],
          ),
        ),

        // Stacked Comparative Verses (Identically treated, continuous divided stream)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: primaryChapter.verses.map((primaryVerse) {
            final secondaryVerse = secondaryMap[primaryVerse.verse];
            final isAudioActive = activeAudioVerse == primaryVerse.verse;

            return Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Small italic verse label: "Verse 1"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Verse ${primaryVerse.verse}',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          color: isAudioActive ? const Color(0xFFB45309) : ext.inkSoft,
                        ),
                      ),
                      if (isAudioActive)
                        const Row(
                          children: [
                            Icon(Icons.volume_up_outlined, size: 14, color: Color(0xFFB45309)),
                            SizedBox(width: 4),
                            Text(
                              'Reading aloud',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Translation 1 Name (e.g. "Amplified Bible" on its own line)
                  Text(
                    _primaryDisplayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: ext.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Translation 1 Verse Text (Hero serif text with amber underline on original words)
                  GestureDetector(
                    onTap: () => onVerseTapped(primaryVerse),
                    behavior: HitTestBehavior.opaque,
                    child: _buildPrimaryVerseContent(primaryVerse, ext),
                  ),
                  const SizedBox(height: 14),

                  // Translation 2 Name (e.g. "AMP" on its own line)
                  Text(
                    secondaryTranslationAbbr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: ext.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Translation 2 Verse Text (Stacked below)
                  Text(
                    secondaryVerse?.text ?? 'Loading translation...',
                    style: TextStyle(
                      fontFamily: _effectiveFont(fontFamily),
                      fontSize: fontSize * 0.96,
                      height: 1.5,
                      color: ext.ink.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: ext.line, height: 1, thickness: 1),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrimaryVerseContent(VerseModel verse, ScriptureThemeExtension ext) {
    final tokens = VerseWordParser.parseVerse(verse.text, primaryChapter.bookCode, verse.originalWords);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: tokens.map((token) {
        if (token.isInteractive && token.word != null) {
          return GestureDetector(
            onTap: () => onWordTapped(token.word!),
            child: Text(
              token.text,
              style: TextStyle(
                fontFamily: _effectiveFont(fontFamily),
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: ext.ink,
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFFB45309),
                decorationThickness: 1.6,
              ),
            ),
          );
        } else {
          return Text(
            token.text,
            style: TextStyle(
              fontFamily: _effectiveFont(fontFamily),
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              height: 1.48,
              color: ext.ink,
            ),
          );
        }
      }).toList(),
    );
  }
}
