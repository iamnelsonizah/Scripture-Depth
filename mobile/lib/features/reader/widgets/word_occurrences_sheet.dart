import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/scripture_models.dart';
import '../../../core/services/audio_bible_service.dart';

class WordOccurrencesSheet extends StatelessWidget {
  final LexiconEntryModel entry;
  final List<WordOccurrenceModel> occurrences;
  final ValueChanged<WordOccurrenceModel>? onSelectOccurrence;

  const WordOccurrencesSheet({
    super.key,
    required this.entry,
    required this.occurrences,
    this.onSelectOccurrence,
  });

  static void show(
    BuildContext context, {
    required LexiconEntryModel entry,
    required List<WordOccurrenceModel> occurrences,
    ValueChanged<WordOccurrenceModel>? onSelectOccurrence,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => WordOccurrencesSheet(
          entry: entry,
          occurrences: occurrences,
          onSelectOccurrence: onSelectOccurrence,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    final occurrencesCount = entry.occurrencesCount > 0
        ? entry.occurrencesCount
        : occurrences.length;

    return Container(
      decoration: BoxDecoration(
        color: ext.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: ext.line)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 25,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            decoration: BoxDecoration(
              color: ext.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            entry.lemma,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: ext.gold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.volume_up_rounded, size: 20, color: ext.teal),
                            tooltip: 'Pronounce original word',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              AudioBibleService().pronounceWord(
                                entry.lemma,
                                language: entry.language,
                              );
                            },
                          ),
                        ],
                      ),
                      Text(
                        '${entry.strongsNumber} · ${entry.transliteration ?? ""} · $occurrencesCount occurrences in Scripture',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: ext.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: ext.inkSoft),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(color: ext.line, height: 1),

          // Occurrences List
          Expanded(
            child: occurrences.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book, size: 36, color: ext.inkSoft),
                          const SizedBox(height: 12),
                          Text(
                            'Ingesting full Bible text for concordance.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: ext.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    itemCount: occurrences.length,
                    separatorBuilder: (_, __) => Divider(color: ext.line, height: 16),
                    itemBuilder: (context, index) {
                      final occ = occurrences[index];
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelectOccurrence?.call(occ);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ext.tealSoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      occ.reference,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: ext.teal,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    occ.surfaceForm,
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: ext.gold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                occ.verseText ?? 'Tap to read full context in Chapter.',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 14.5,
                                  height: 1.5,
                                  color: ext.ink,
                                ),
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
