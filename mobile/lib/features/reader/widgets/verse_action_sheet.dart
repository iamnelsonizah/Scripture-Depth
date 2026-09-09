import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/scripture_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/audio_bible_service.dart';
import '../../../core/services/study_journal_service.dart';
import 'verse_connections_sheet.dart';

class VerseActionSheet extends StatefulWidget {
  final String bookCode;
  final String bookName;
  final int chapter;
  final int verse;
  final String verseText;
  final ApiClient apiClient;
  final ValueChanged<String>? onNoteSaved;
  final ValueChanged<Color>? onHighlightSelected;
  final VoidCallback? onOpenDeepStudy;
  final VoidCallback? onOpenConnections;

  const VerseActionSheet({
    super.key,
    required this.bookCode,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.verseText,
    required this.apiClient,
    this.onNoteSaved,
    this.onHighlightSelected,
    this.onOpenDeepStudy,
    this.onOpenConnections,
  });

  static void show(
    BuildContext context, {
    required String bookCode,
    required String bookName,
    required int chapter,
    required int verse,
    required String verseText,
    required ApiClient apiClient,
    ValueChanged<String>? onNoteSaved,
    ValueChanged<Color>? onHighlightSelected,
    VoidCallback? onOpenDeepStudy,
    VoidCallback? onOpenConnections,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: VerseActionSheet(
          bookCode: bookCode,
          bookName: bookName,
          chapter: chapter,
          verse: verse,
          verseText: verseText,
          apiClient: apiClient,
          onNoteSaved: onNoteSaved,
          onHighlightSelected: onHighlightSelected,
          onOpenDeepStudy: onOpenDeepStudy,
          onOpenConnections: onOpenConnections,
        ),
      ),
    );
  }

  @override
  State<VerseActionSheet> createState() => _VerseActionSheetState();
}

class _VerseActionSheetState extends State<VerseActionSheet> {
  bool isEditingNote = false;
  final TextEditingController _noteController = TextEditingController();
  bool isSaving = false;

  Future<void> _saveNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    setState(() => isSaving = true);
    StudyJournalService().addOrUpdateNote(
      bookCode: widget.bookCode,
      bookName: widget.bookName,
      chapter: widget.chapter,
      verse: widget.verse,
      verseText: widget.verseText,
      noteText: text,
    );
    final created = await widget.apiClient.createNote(
      bookCode: widget.bookCode,
      chapter: widget.chapter,
      verse: widget.verse,
      text: text,
    );
    if (!mounted) return;

    if (created != null) {
      widget.onNoteSaved?.call(text);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note saved to ${widget.bookName} ${widget.chapter}:${widget.verse}'),
        ),
      );
    } else {
      setState(() => isSaving = false);
    }
  }

  Future<void> _bookmark() async {
    await widget.apiClient.createBookmark(
      bookCode: widget.bookCode,
      chapter: widget.chapter,
      verse: widget.verse,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bookmarked ${widget.bookName} ${widget.chapter}:${widget.verse}')),
    );
  }

  void _copyVerse() {
    final full = '${widget.bookName} ${widget.chapter}:${widget.verse} — "${widget.verseText}"';
    Clipboard.setData(ClipboardData(text: full));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verse copied to clipboard')),
    );
  }

  void _openConnections() {
    Navigator.of(context).pop();
    widget.onOpenConnections?.call();
  }

  void _listenVerse() {
    Navigator.of(context).pop();
    AudioBibleService().speakSingleVerse(
      VerseModel(verse: widget.verse, text: widget.verseText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    final refString = '${widget.bookName} ${widget.chapter}:${widget.verse}';

    return Container(
      decoration: BoxDecoration(
        color: ext.paperSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: ext.line)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: ext.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (!isEditingNote) ...[
            // Top Row: Highlight Swatches (matching screenshot) + Action Buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Color Swatches Container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: ext.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ext.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _colorDot(AppColors.highlightOrange, 'Orange'),
                        const SizedBox(width: 8),
                        _colorDot(AppColors.highlightYellow, 'Yellow'),
                        const SizedBox(width: 8),
                        _colorDot(AppColors.highlightGreen, 'Green'),
                        const SizedBox(width: 8),
                        _colorDot(AppColors.highlightCyan, 'Cyan'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Actions: Save, Note, Copy, Share, Listen
                  _actionCapsule(
                    icon: Icons.bookmark_border_rounded,
                    label: 'Save',
                    onTap: _bookmark,
                    ext: ext,
                  ),
                  const SizedBox(width: 8),
                  _actionCapsule(
                    icon: Icons.description_outlined,
                    label: 'Note',
                    onTap: () => setState(() => isEditingNote = true),
                    ext: ext,
                  ),
                  const SizedBox(width: 8),
                  _actionCapsule(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: _copyVerse,
                    ext: ext,
                  ),
                  const SizedBox(width: 8),
                  _actionCapsule(
                    icon: Icons.volume_up_rounded,
                    label: 'Listen',
                    onTap: _listenVerse,
                    ext: ext,
                  ),
                  const SizedBox(width: 8),
                  _actionCapsule(
                    icon: Icons.hub_outlined,
                    label: 'Links',
                    onTap: _openConnections,
                    ext: ext,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // "Swipe up for more / Deep study" prompt matching screenshot
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                widget.onOpenDeepStudy?.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: ext.inkSoft),
                    const SizedBox(width: 4),
                    Text(
                      'Deep study & concordance',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ext.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // In-place Note Writer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Note on $refString',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ext.ink,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: ext.inkSoft),
                  onPressed: () => setState(() => isEditingNote = false),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: ext.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ext.line),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: TextField(
                controller: _noteController,
                maxLines: 3,
                autofocus: true,
                style: TextStyle(fontSize: 14.5, color: ext.ink),
                decoration: InputDecoration(
                  hintText: 'Add your reflections or study insights...',
                  hintStyle: TextStyle(color: ext.inkSoft, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => isEditingNote = false),
                  child: Text('Cancel', style: TextStyle(color: ext.inkSoft)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isSaving ? null : _saveNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Note'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _colorDot(Color color, String label) {
    return GestureDetector(
      onTap: () {
        final theme = TheologicalThemes.fromColor(color);
        StudyJournalService().addOrUpdateHighlight(
          bookCode: widget.bookCode,
          bookName: widget.bookName,
          chapter: widget.chapter,
          verse: widget.verse,
          verseText: widget.verseText,
          color: color,
          theologicalKey: theme.key,
        );
        widget.onHighlightSelected?.call(color);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Highlighted in $label'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
      ),
    );
  }

  Widget _actionCapsule({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ScriptureThemeExtension ext,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ext.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ext.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: ext.ink),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ext.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
