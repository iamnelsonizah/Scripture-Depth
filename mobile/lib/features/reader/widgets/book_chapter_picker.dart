import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/scripture_models.dart';

class BookChapterSelection {
  final BibleBook book;
  final int chapter;

  const BookChapterSelection({required this.book, required this.chapter});
}

class BookChapterPickerSheet extends StatefulWidget {
  final String currentBookCode;
  final int currentChapter;

  const BookChapterPickerSheet({
    super.key,
    required this.currentBookCode,
    required this.currentChapter,
  });

  static Future<BookChapterSelection?> show(
    BuildContext context, {
    required String currentBookCode,
    required int currentChapter,
  }) {
    return showModalBottomSheet<BookChapterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookChapterPickerSheet(
        currentBookCode: currentBookCode,
        currentChapter: currentChapter,
      ),
    );
  }

  @override
  State<BookChapterPickerSheet> createState() => _BookChapterPickerSheetState();
}

class _BookChapterPickerSheetState extends State<BookChapterPickerSheet> {
  String selectedTestament = 'NT'; // 'NT' or 'OT'
  BibleBook? selectedBook;
  String searchQuery = '';
  final TextEditingController _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final current = BibleBook.allBooks.firstWhere(
      (b) => b.code == widget.currentBookCode,
      orElse: () => BibleBook.allBooks.firstWhere((b) => b.code == 'JHN'),
    );
    selectedTestament = current.testament;
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    return Material(
      color: ext.paper,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: ext.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Modern Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (selectedBook != null)
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, size: 18, color: ext.ink),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => selectedBook = null),
                    )
                  else
                    const SizedBox(width: 40),
                  Text(
                    selectedBook == null ? 'Select Scripture' : selectedBook!.name,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: ext.ink,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: ext.inkSoft),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            if (selectedBook == null) ...[
              // Modern Testament Switcher
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: ext.paperSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ext.line),
                  ),
                  child: Row(
                    children: [
                      _testamentTab('New Testament', 'NT', ext),
                      _testamentTab('Old Testament', 'OT', ext),
                    ],
                  ),
                ),
              ),

              // Search filter field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: ext.paperSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ext.line),
                  ),
                  child: TextField(
                    controller: _filterController,
                    onChanged: (val) => setState(() => searchQuery = val.trim().toLowerCase()),
                    style: TextStyle(fontSize: 13.5, color: ext.ink),
                    decoration: InputDecoration(
                      hintText: 'Filter books (e.g., Romans, John, Genesis)...',
                      hintStyle: TextStyle(fontSize: 13, color: ext.inkSoft),
                      prefixIcon: Icon(Icons.search, size: 18, color: ext.inkSoft),
                      suffixIcon: searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _filterController.clear();
                                setState(() => searchQuery = '');
                              },
                              child: Icon(Icons.clear, size: 16, color: ext.inkSoft),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),

              // Books List
              Expanded(
                child: _buildBooksList(ext),
              ),
            ] else ...[
              // Chapter Grid for selected book
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Chapter (1 - ${selectedBook!.totalChapters})',
                      style: TextStyle(
                        fontSize: 13,
                        color: ext.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${selectedBook!.totalChapters} chapters total',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ext.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildChaptersGrid(selectedBook!, ext),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _testamentTab(String title, String key, ScriptureThemeExtension ext) {
    final isSelected = selectedTestament == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          selectedTestament = key;
        }),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? ext.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : ext.inkSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBooksList(ScriptureThemeExtension ext) {
    final books = BibleBook.allBooks.where((b) {
      if (searchQuery.isNotEmpty) {
        return b.name.toLowerCase().contains(searchQuery) ||
            b.code.toLowerCase().contains(searchQuery);
      }
      return b.testament == selectedTestament;
    }).toList();

    if (books.isEmpty) {
      return Center(
        child: Text(
          'No books matching "$searchQuery"',
          style: TextStyle(color: ext.inkSoft, fontSize: 13.5),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final isCurrent = book.code == widget.currentBookCode;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: () {
              setState(() => selectedBook = book);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isCurrent ? ext.tealSoft : ext.paperSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent ? ext.teal.withOpacity(0.5) : ext.line,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: isCurrent ? ext.teal : ext.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      book.code,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : ext.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      book.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                        color: isCurrent ? ext.teal : ext.ink,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ext.paper,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ext.line),
                    ),
                    child: Text(
                      '${book.totalChapters} ch',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: ext.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 16, color: ext.inkSoft),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChaptersGrid(BibleBook book, ScriptureThemeExtension ext) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: book.totalChapters,
      itemBuilder: (context, index) {
        final chNum = index + 1;
        final isSelected = book.code == widget.currentBookCode && chNum == widget.currentChapter;

        return InkWell(
          onTap: () {
            Navigator.of(context).pop(
              BookChapterSelection(book: book, chapter: chNum),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? ext.teal : ext.paperSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? ext.teal : ext.line,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: ext.teal.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$chNum',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : ext.ink,
              ),
            ),
          ),
        );
      },
    );
  }
}
