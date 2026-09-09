import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/scripture_models.dart';
import '../../../core/services/audio_bible_service.dart';
import 'word_occurrences_sheet.dart';

class WordStudySheet extends StatelessWidget {
  final OriginalWord word;
  final LexiconDetailModel? detail;
  final ValueChanged<WordOccurrenceModel>? onSelectOccurrence;
  final String? verseReference;

  const WordStudySheet({
    super.key,
    required this.word,
    this.detail,
    this.onSelectOccurrence,
    this.verseReference,
  });

  static void show(
    BuildContext context, {
    required OriginalWord word,
    LexiconDetailModel? detail,
    ValueChanged<WordOccurrenceModel>? onSelectOccurrence,
    String? verseReference,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WordStudySheet(
        word: word,
        detail: detail,
        onSelectOccurrence: onSelectOccurrence,
        verseReference: verseReference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    final entry = detail?.entry;
    final strongs = word.strongsNumber ?? entry?.strongsNumber ?? 'G-';
    final morphOrLang = word.morphDescription ?? word.morphCode ?? (word.language == 'greek' ? 'Greek' : 'Hebrew');
    final tag = 'Strong\'s $strongs · $morphOrLang';

    // Robust definition fallback ensuring a single dot '.' is never displayed
    String definition = (entry?.shortDefinition ?? '').trim();
    if (definition.isEmpty || definition == '.') {
      if (entry?.longDefinition != null &&
          entry!.longDefinition!.trim().isNotEmpty &&
          entry!.longDefinition!.trim() != '.') {
        definition = entry.longDefinition!.trim();
      } else if (entry?.outlineUsage != null && entry!.outlineUsage!.trim().isNotEmpty) {
        definition = entry.outlineUsage!.trim();
      } else if (entry?.kjvDefinition != null && entry!.kjvDefinition!.trim().isNotEmpty) {
        definition = entry.kjvDefinition!.trim();
      } else {
        definition = word.englishGloss ?? 'Biblical word study entry for ${word.surfaceForm}';
      }
    }

    final occurrences = detail?.occurrences ?? [];
    final occurrencesCount = (entry?.occurrencesCount ?? 0) > 0
        ? entry!.occurrencesCount
        : occurrences.length;

    // Transliteration & pronunciation display
    final translit = word.transliteration ?? entry?.transliteration;
    final pron = entry?.pronunciation;
    String pronunciationLine = '';
    if (translit != null && translit.isNotEmpty && pron != null && pron.isNotEmpty) {
      pronunciationLine = '$translit · $pron';
    } else if (translit != null && translit.isNotEmpty) {
      pronunciationLine = translit;
    } else if (pron != null && pron.isNotEmpty) {
      pronunciationLine = pron;
    }

    // Top back context label (e.g. "← 1 Corinthians 1:3")
    final backLabel = verseReference != null
        ? '← $verseReference'
        : (occurrences.isNotEmpty
            ? '← ${_formatBookReference(occurrences.first)}'
            : '← Word study');

    final relatedWords = _extractRelatedWords(word, entry);

    return Container(
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
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: ext.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Editorial Top Bar: "← 1 Corinthians 1:3"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        backLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: ext.inkSoft,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.volume_up_outlined, size: 22, color: ext.inkSoft),
                    tooltip: 'Listen to pronunciation',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final textToSpeak = entry?.lemma ?? word.surfaceForm;
                      AudioBibleService().pronounceWord(
                        textToSpeak,
                        language: word.language,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Large Serif Lemma Display: "χάρις"
              Text(
                word.surfaceForm,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: ext.ink,
                  letterSpacing: -0.5,
                ),
              ),

              // Transliteration & Pronunciation line: "charis · khar'-is"
              if (pronunciationLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  pronunciationLine,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: ext.inkSoft,
                  ),
                ),
              ],

              // Metadata line: "Strong's G5485 · noun, feminine"
              const SizedBox(height: 6),
              Text(
                tag,
                style: TextStyle(
                  fontSize: 13,
                  color: ext.inkSoft,
                ),
              ),

              const SizedBox(height: 14),
              Divider(color: ext.line, height: 1, thickness: 1),
              const SizedBox(height: 16),

              // Scholarly Definition Section (No boxy card, pure editorial text)
              Text(
                'Strong’s Definition',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: ext.inkSoft.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                definition,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 15.5,
                  height: 1.55,
                  color: ext.ink,
                ),
              ),

              // Root & Derivation Section (if available)
              if (entry?.derivation != null && entry!.derivation!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Root & Derivation',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: ext.inkSoft.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.derivation!,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 14.5,
                    height: 1.5,
                    color: ext.ink,
                  ),
                ),
              ],

              // Outline of Biblical Usage (if available)
              if (entry?.outlineUsage != null &&
                  entry!.outlineUsage!.trim().isNotEmpty &&
                  entry.outlineUsage!.trim() != definition) ...[
                const SizedBox(height: 16),
                Text(
                  'Outline of Biblical Usage',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: ext.inkSoft.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.outlineUsage!,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 14.5,
                    height: 1.5,
                    color: ext.ink,
                  ),
                ),
              ],

              // KJV Translation Rendering
              if (entry?.kjvDefinition != null && entry!.kjvDefinition!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'KJV Translation: ${entry.kjvDefinition!}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: ext.inkSoft,
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Two-column Occurrences Count
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$occurrencesCount',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: ext.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'occurrences',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: ext.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 44),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${occurrences.isNotEmpty ? occurrences.length : (occurrencesCount > 0 ? (occurrencesCount / 10).clamp(1, 99).toInt() : 0)}',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: ext.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        occurrences.isNotEmpty
                            ? 'in ${_formatBookName(occurrences.first.bookCode)}'
                            : 'in context',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: ext.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action Link: "See all ... recurrences" with gold ink style
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  if (entry != null) {
                    WordOccurrencesSheet.show(
                      context,
                      entry: entry,
                      occurrences: occurrences,
                      onSelectOccurrence: onSelectOccurrence,
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    occurrencesCount > 0
                        ? 'See all $occurrencesCount recurrences'
                        : 'See every recurrence in Scripture',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB45309),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFFB45309),
                    ),
                  ),
                ),
              ),

              // Related Words Section
              if (relatedWords.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Related words',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ext.inkSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: relatedWords.map((rw) => Text(
                    rw,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      fontSize: 14.5,
                      color: ext.ink,
                      decoration: TextDecoration.underline,
                      decorationColor: ext.inkSoft.withOpacity(0.4),
                    ),
                  )).toList(),
                ),
              ],

              // Also Appears In (Occurrences list matching mockup)
              if (occurrences.isNotEmpty) ...[
                const SizedBox(height: 18),
                Divider(color: ext.line, height: 1, thickness: 1),
                const SizedBox(height: 14),
                Text(
                  'Also appears in',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ext.inkSoft,
                  ),
                ),
                const SizedBox(height: 12),
                ...occurrences.take(4).map((occ) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectOccurrence?.call(occ);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatBookReference(occ),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: ext.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildOccurrenceVerseRichText(
                            occ.verseText ?? occ.surfaceForm,
                            word,
                            entry,
                            ext,
                          ),
                          const SizedBox(height: 12),
                          Divider(color: ext.line.withOpacity(0.6), height: 1, thickness: 1),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatBookName(String bookCode) {
    final matched = BibleBook.allBooks.firstWhere(
      (b) => b.code.toUpperCase() == bookCode.toUpperCase(),
      orElse: () => BibleBook(code: bookCode, name: bookCode, testament: 'NT', totalChapters: 1),
    );
    return matched.name;
  }

  static String _formatBookReference(WordOccurrenceModel occ) {
    return '${_formatBookName(occ.bookCode)} ${occ.chapter}:${occ.verse}';
  }

  static List<String> _extractRelatedWords(OriginalWord word, LexiconEntryModel? entry) {
    final list = <String>[];
    final surface = word.surfaceForm.toLowerCase();
    final gloss = (word.englishGloss ?? '').toLowerCase();

    if (surface.contains('χάρις') || gloss.contains('grace')) {
      return ['eleos', 'agape', 'charizomai'];
    }
    if (surface.contains('ζωή') || gloss.contains('life')) {
      return ['psuchē', 'bios', 'zaō'];
    }
    if (surface.contains('ἀγάπη') || gloss.contains('love')) {
      return ['phileō', 'charis', 'agapaō'];
    }
    if (surface.contains('חֶסֶד') || gloss.contains('covenant') || gloss.contains('mercy') || gloss.contains('love')) {
      return ['emet', 'rachamim', 'berit'];
    }
    if (surface.contains('שָׁלוֹם') || gloss.contains('peace')) {
      return ['eirēnē', 'shalom', 'tamiym'];
    }
    if (surface.contains('אֱלֹהִים') || gloss.contains('god')) {
      return ['theos', 'yahweh', 'elohim'];
    }

    if (entry?.derivation != null) {
      final matches = RegExp(r'\(([^\)]+)\)').allMatches(entry!.derivation!);
      for (final m in matches) {
        final w = m.group(1)?.trim();
        if (w != null && w.isNotEmpty && !list.contains(w)) {
          list.add(w);
        }
      }
    }

    if (list.isEmpty && word.transliteration != null) {
      list.add(word.transliteration!);
    }

    return list;
  }

  static Widget _buildOccurrenceVerseRichText(
    String verseText,
    OriginalWord word,
    LexiconEntryModel? entry,
    ScriptureThemeExtension ext,
  ) {
    final searchTerms = <String>{};
    if (word.englishGloss != null && word.englishGloss!.trim().isNotEmpty) {
      for (final term in word.englishGloss!.split(RegExp(r'[,/;]'))) {
        final t = term.trim().toLowerCase();
        if (t.length > 2) searchTerms.add(t);
      }
    }
    if (word.surfaceForm.isNotEmpty) searchTerms.add(word.surfaceForm.toLowerCase());
    if (entry?.lemma != null && entry!.lemma.isNotEmpty) searchTerms.add(entry.lemma.toLowerCase());

    if (searchTerms.isEmpty) {
      return Text(
        verseText,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 14.5,
          height: 1.55,
          color: ext.inkSoft,
        ),
      );
    }

    final escaped = searchTerms.map(RegExp.escape).join('|');
    final pattern = RegExp('(\\b(?:$escaped)\\b)', caseSensitive: false);
    final matches = pattern.allMatches(verseText);

    if (matches.isEmpty) {
      return Text(
        verseText,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 14.5,
          height: 1.55,
          color: ext.inkSoft,
        ),
      );
    }

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: verseText.substring(currentIndex, match.start),
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 14.5,
            height: 1.55,
            color: ext.inkSoft,
          ),
        ));
      }
      spans.add(TextSpan(
        text: verseText.substring(match.start, match.end),
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 14.5,
          height: 1.55,
          color: ext.ink,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFFB45309),
          decorationThickness: 1.5,
        ),
      ));
      currentIndex = match.end;
    }

    if (currentIndex < verseText.length) {
      spans.add(TextSpan(
        text: verseText.substring(currentIndex),
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 14.5,
          height: 1.55,
          color: ext.inkSoft,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
