import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/scripture_models.dart';

class VerseConnectionsSheet extends StatelessWidget {
  final String sourceBookName;
  final int sourceChapter;
  final int sourceVerse;
  final String sourceVerseText;
  final List<CrossReferenceModel> connections;
  final void Function(String bookCode, int chapter, int verse)? onNavigateToPassage;

  const VerseConnectionsSheet({
    super.key,
    required this.sourceBookName,
    required this.sourceChapter,
    required this.sourceVerse,
    required this.sourceVerseText,
    required this.connections,
    this.onNavigateToPassage,
  });

  static void show(
    BuildContext context, {
    required String sourceBookName,
    required int sourceChapter,
    required int sourceVerse,
    required String sourceVerseText,
    required List<CrossReferenceModel> connections,
    void Function(String bookCode, int chapter, int verse)? onNavigateToPassage,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (_, scrollController) => VerseConnectionsSheet(
          sourceBookName: sourceBookName,
          sourceChapter: sourceChapter,
          sourceVerse: sourceVerse,
          sourceVerseText: sourceVerseText,
          connections: connections,
          onNavigateToPassage: onNavigateToPassage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    final sourceRef = '$sourceBookName $sourceChapter:$sourceVerse';

    return Container(
      decoration: BoxDecoration(
        color: ext.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: ext.line)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4.5,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            decoration: BoxDecoration(
              color: ext.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hub_outlined, size: 20, color: ext.teal),
                          const SizedBox(width: 8),
                          Text(
                            'Scripture Connections',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ext.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Passages connected to $sourceRef',
                        style: TextStyle(
                          fontSize: 12.5,
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

          // Selected Verse Quote banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ext.paperSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ext.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sourceRef,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ext.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sourceVerseText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                      color: ext.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(color: ext.line, height: 1),

          // Connections List
          Expanded(
            child: connections.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link, size: 36, color: ext.inkSoft),
                          const SizedBox(height: 12),
                          Text(
                            'Connecting related theological passages...',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, color: ext.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: connections.length,
                    separatorBuilder: (_, __) => Divider(color: ext.line, height: 16),
                    itemBuilder: (context, index) {
                      final conn = connections[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ext.paperSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ext.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reference Tag & Theme
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ext.tealSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    conn.reference,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: ext.teal,
                                    ),
                                  ),
                                ),
                                if (conn.refType != null)
                                  Text(
                                    conn.refType!,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: ext.gold,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Verse Text
                            Text(
                              conn.verseText ?? 'Tap Jump to read passage in full context.',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 14.5,
                                height: 1.5,
                                color: ext.ink,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Jump action button
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  onNavigateToPassage?.call(
                                    conn.toBookCode,
                                    conn.toChapter,
                                    conn.toVerse,
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: ext.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: ext.line),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Jump to Passage',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: ext.teal,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_rounded, size: 14, color: ext.teal),
                                    ],
                                  ),
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
    );
  }
}
