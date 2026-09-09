import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/study_journal_service.dart';
import '../../../core/services/reader_navigation_service.dart';

class StudyJournalSheet extends StatefulWidget {
  const StudyJournalSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StudyJournalSheet(),
    );
  }

  @override
  State<StudyJournalSheet> createState() => _StudyJournalSheetState();
}

class _StudyJournalSheetState extends State<StudyJournalSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // 'all', 'notes_only', or theologicalKey

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyMarkdownExport() {
    final md = StudyJournalService().exportToMarkdown();
    Clipboard.setData(ClipboardData(text: md));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Study Journal exported as Markdown to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _editNote(JournalEntryModel entry) {
    final noteCtrl = TextEditingController(text: entry.noteText ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        final ext = Theme.of(ctx).extension<ScriptureThemeExtension>() ??
            ScriptureThemeExtension.light;

        return AlertDialog(
          backgroundColor: ext.paper,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Study Reflection for ${entry.reference}',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 17, color: ext.ink),
          ),
          content: TextField(
            controller: noteCtrl,
            maxLines: 4,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: ext.ink),
            decoration: InputDecoration(
              hintText: 'Add your exegetical observations, prayers, or insights...',
              hintStyle: TextStyle(color: ext.inkSoft, fontSize: 13),
              filled: true,
              fillColor: ext.paperSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ext.line),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: ext.inkSoft)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ext.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await StudyJournalService().addOrUpdateNote(
                  bookCode: entry.bookCode,
                  bookName: entry.bookName,
                  chapter: entry.chapter,
                  verse: entry.verse,
                  verseText: entry.verseText,
                  noteText: noteCtrl.text.trim(),
                  color: entry.color,
                  theologicalKey: entry.theologicalKey,
                  translationId: entry.translationId,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    return ValueListenableBuilder<List<JournalEntryModel>>(
      valueListenable: StudyJournalService().entriesNotifier,
      builder: (context, allEntries, _) {
        // Filter by tag and search query
        final query = _searchController.text.trim().toLowerCase();
        final filteredEntries = allEntries.where((e) {
          // Tag filter
          if (_selectedFilter == 'notes_only') {
            if (!e.hasNote) return false;
          } else if (_selectedFilter != 'all') {
            if (e.theologicalKey != _selectedFilter) return false;
          }

          // Text query filter
          if (query.isNotEmpty) {
            final matchesRef = e.reference.toLowerCase().contains(query);
            final matchesVerse = e.verseText.toLowerCase().contains(query);
            final matchesNote = (e.noteText ?? '').toLowerCase().contains(query);
            final matchesTheme = e.theme.label.toLowerCase().contains(query);
            return matchesRef || matchesVerse || matchesNote || matchesTheme;
          }

          return true;
        }).toList();

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: ext.paper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
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

              // Title & Export Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theological Study Journal',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ext.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${allEntries.length} saved highlights & personal study notes',
                            style: TextStyle(fontSize: 12, color: ext.inkSoft),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ext.teal,
                        side: BorderSide(color: ext.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text('Export MD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _copyMarkdownExport,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Search Input Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ext.paperSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ext.line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18, color: ext.inkSoft),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(fontSize: 13.5, color: ext.ink),
                          decoration: InputDecoration(
                            hintText: 'Search verses, topics, notes, or references...',
                            hintStyle: TextStyle(fontSize: 13, color: ext.inkSoft),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          child: Icon(Icons.close_rounded, size: 16, color: ext.inkSoft),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Theological Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _filterChip(label: 'All (${allEntries.length})', filterKey: 'all', ext: ext),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'Promises',
                      filterKey: TheologicalThemes.promises.key,
                      dotColor: TheologicalThemes.promises.color,
                      ext: ext,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'Living',
                      filterKey: TheologicalThemes.living.key,
                      dotColor: TheologicalThemes.living.color,
                      ext: ext,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'Comfort',
                      filterKey: TheologicalThemes.comfort.key,
                      dotColor: TheologicalThemes.comfort.color,
                      ext: ext,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'Prophecy',
                      filterKey: TheologicalThemes.prophecy.key,
                      dotColor: TheologicalThemes.prophecy.color,
                      ext: ext,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'Doctrine',
                      filterKey: TheologicalThemes.doctrine.key,
                      dotColor: TheologicalThemes.doctrine.color,
                      ext: ext,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'Notes Only',
                      filterKey: 'notes_only',
                      icon: Icons.edit_note_rounded,
                      ext: ext,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),

              // Journal Entries List
              Expanded(
                child: filteredEntries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book_outlined, size: 40, color: ext.inkSoft.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No matching journal entries found',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: ext.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Highlight verses or write notes in the Reader to populate your journal.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: ext.inkSoft),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        itemCount: filteredEntries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = filteredEntries[index];
                          return _buildJournalCard(context, entry, ext);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip({
    required String label,
    required String filterKey,
    Color? dotColor,
    IconData? icon,
    required ScriptureThemeExtension ext,
  }) {
    final isSelected = _selectedFilter == filterKey;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ext.teal : ext.paperSecondary,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? ext.teal : ext.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : ext.inkSoft),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : ext.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${dt.month}/${dt.day}';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildJournalCard(
    BuildContext context,
    JournalEntryModel entry,
    ScriptureThemeExtension ext,
  ) {
    final theme = entry.theme;

    return Container(
      decoration: BoxDecoration(
        color: ext.paperSecondary,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.color.withOpacity(0.06),
            ext.paperSecondary,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.color.withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category tag with glowing jewel dot + Timestamp + Action menu
            Row(
              children: [
                // Theological theme badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: BoxDecoration(
                          color: theme.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.color.withOpacity(0.6),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        theme.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: theme.color,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimeAgo(entry.createdAt),
                  style: TextStyle(fontSize: 11, color: ext.inkSoft),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz_rounded, size: 18, color: ext.inkSoft),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _editNote(entry);
                    } else if (val == 'delete') {
                      StudyJournalService().deleteEntry(entry.id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Reflection', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Entry', style: TextStyle(fontSize: 13, color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Scripture Reference & Translation Link
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                ReaderNavigationService().navigateTo(
                  bookCode: entry.bookCode,
                  bookName: entry.bookName,
                  chapter: entry.chapter,
                  verse: entry.verse,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ext.paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ext.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.reference,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: ext.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: ext.tealSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.translationId.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: ext.teal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.open_in_new_rounded, size: 11.5, color: ext.teal),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Verse Text Quote
            Text(
              '“${entry.verseText}”',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 14.5,
                fontStyle: FontStyle.italic,
                color: ext.ink,
                height: 1.48,
                letterSpacing: 0.1,
              ),
            ),

            // Personal Exegetical Reflection Notebook Callout
            if (entry.hasNote) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ext.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ext.line.withOpacity(0.7)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 3.5,
                          color: theme.color,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.auto_stories_outlined, size: 12, color: theme.color),
                                    const SizedBox(width: 5),
                                    Text(
                                      'STUDY REFLECTION',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.6,
                                        color: theme.color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  entry.noteText!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: ext.ink,
                                    height: 1.42,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
