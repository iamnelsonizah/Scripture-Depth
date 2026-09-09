import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/scripture_models.dart';
import '../../core/network/api_client.dart';
import '../reader/widgets/word_study_sheet.dart';

bool get _isTesting => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

class SearchScreen extends StatefulWidget {
  final ApiClient apiClient;
  final void Function(String bookCode, int chapter, int verse)? onNavigateToPassage;

  const SearchScreen({
    super.key,
    required this.apiClient,
    this.onNavigateToPassage,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController(text: 'grace');
  String activeScope = 'All';
  String activeTranslation = 'kjv';
  List<SearchResultModel> results = [];
  bool isLoading = false;
  Timer? _debounce;
  late AnimationController _shimmerController;

  final List<String> scopes = ['All', 'Old testament', 'New testament', 'Strong’s'];

  final List<String> popularKeywords = [
    'Love',
    'Grace',
    'Faith',
    'Peace',
    'Light',
    'Holy Spirit',
    'H430',
    'G25',
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _performSearch('grace');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _shimmerController.stop();
    _shimmerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      _shimmerController.stop();
      setState(() {
        results = [];
        isLoading = false;
      });
      return;
    }

    setState(() => isLoading = true);
    if (!_isTesting && !_shimmerController.isAnimating) {
      _shimmerController.repeat(reverse: true);
    }
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => isLoading = true);
    if (!_isTesting && !_shimmerController.isAnimating) {
      _shimmerController.repeat(reverse: true);
    }

    String? testamentParam;
    if (activeScope == 'Old testament' || activeScope == 'Old Testament') testamentParam = 'OT';
    if (activeScope == 'New testament' || activeScope == 'New Testament') testamentParam = 'NT';

    try {
      final hits = await widget.apiClient.searchVerses(
        query,
        translationId: activeTranslation,
        testament: testamentParam,
      );

      if (mounted) {
        _shimmerController.stop();
        setState(() {
          results = hits;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        _shimmerController.stop();
        setState(() => isLoading = false);
      }
    }
  }

  void _selectTopic(String topic) {
    _searchController.text = topic;
    _onSearchChanged(topic);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    return SafeArea(
      child: Scaffold(
        backgroundColor: ext.paper,
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Header Title
              Text(
                'Search scripture',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ext.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Divider(color: ext.line, height: 1, thickness: 1),
              const SizedBox(height: 12),

              // Search Input Row (Quieter Chrome)
              Row(
                children: [
                  Icon(Icons.search, size: 20, color: ext.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(
                        fontSize: 16,
                        color: ext.ink,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by word or theme (e.g. grace)...',
                        hintStyle: TextStyle(
                          color: ext.inkSoft.withOpacity(0.7),
                          fontSize: 14.5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 18, color: ext.inkSoft),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: ext.line, height: 1, thickness: 1),
              const SizedBox(height: 14),

              // Pill filters → Underlined Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: scopes.map((scope) {
                    final isSelected = activeScope == scope;
                    return GestureDetector(
                      onTap: () {
                        setState(() => activeScope = scope);
                        if (_searchController.text.isNotEmpty) {
                          _performSearch(_searchController.text);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              scope,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                                color: isSelected ? ext.ink : ext.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 2,
                              width: isSelected ? 24 : 0,
                              color: isSelected ? const Color(0xFFB45309) : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Italic Serif Topic Keywords
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: popularKeywords.map((topic) {
                    final isCurrent = _searchController.text.toLowerCase() == topic.toLowerCase();
                    return GestureDetector(
                      onTap: () => _selectTopic(topic),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          topic,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                            fontSize: 14.5,
                            color: isCurrent ? ext.ink : ext.inkSoft,
                            decoration: isCurrent ? TextDecoration.underline : TextDecoration.none,
                            decorationColor: const Color(0xFFB45309),
                            decorationThickness: 1.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Results Count Banner
              if (!isLoading && results.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      '${results.length} results',
                      style: TextStyle(
                        fontSize: 13,
                        color: ext.inkSoft,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      activeTranslation.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: ext.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: ext.line, height: 1, thickness: 1),
              ],

              // Results or Skeleton Loading
              if (isLoading)
                Column(
                  children: List.generate(4, (_) => _buildSkeletonCard(ext)),
                )
              else if (results.isEmpty && _searchController.text.isNotEmpty)
                _buildEmptyState(ext)
              else
                ...results.map((item) => _buildResultCard(item, ext)),
            ],
          ),
        ),
      ),
    );
  }

  /// Minimal skeleton hairline items while loading
  Widget _buildSkeletonCard(ScriptureThemeExtension ext) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = _isTesting ? 0.6 : (0.35 + (_shimmerController.value * 0.45));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Opacity(
            opacity: opacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    color: ext.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: ext.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: ext.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: ext.line, height: 1, thickness: 0.8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Continuous Verse Result Flow with hairline divider (NO cards, NO pills!)
  Widget _buildResultCard(SearchResultModel item, ScriptureThemeExtension ext) {
    final isNT = _isNewTestament(item.bookCode);
    final refString = '${item.book} ${item.chapter}:${item.verse}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reference + quiet italic testament tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                refString,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ext.ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isNT ? 'nt' : 'ot',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: ext.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Matching verse text with warm gold ink underline
          _renderHighlightedText(item.highlightedText ?? item.text, ext),
          const SizedBox(height: 8),

          // Plain text action links: Copy · Word study
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: '$refString — "${item.text}"'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied $refString to clipboard'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  'Copy',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: ext.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('·', style: TextStyle(color: ext.inkSoft, fontSize: 13)),
              ),
              GestureDetector(
                onTap: () => _openWordStudyForVerse(item),
                child: Text(
                  'Word study',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: ext.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: ext.line, height: 1, thickness: 0.8),
        ],
      ),
    );
  }

  /// Yellow highlight box → underline in warm gold ink
  Widget _renderHighlightedText(String text, ScriptureThemeExtension ext) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'<mark>(.*?)</mark>');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 15.5,
            height: 1.48,
            color: ext.ink,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 15.5,
          height: 1.48,
          fontWeight: FontWeight.w600,
          color: ext.ink,
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFFB45309), // warm gold ink underline
          decorationThickness: 1.5,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 15.5,
          height: 1.48,
          color: ext.ink,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildEmptyState(ScriptureThemeExtension ext) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: ext.inkSoft.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              'No matching scriptures found',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ext.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting spelling or searching another translation',
              style: TextStyle(fontSize: 13, color: ext.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  void _openWordStudyForVerse(SearchResultModel item) async {
    final isNT = _isNewTestament(item.bookCode);
    final fallbackWord = isNT
        ? const OriginalWord(
            wordPosition: 1,
            surfaceForm: 'ἀγάπη',
            lemma: 'ἀγάπη',
            transliteration: 'agápē',
            strongsNumber: 'G26',
            language: 'greek',
            englishGloss: 'love / charity',
          )
        : const OriginalWord(
            wordPosition: 1,
            surfaceForm: 'חֶסֶד',
            lemma: 'חֶסֶד',
            transliteration: 'ḥesed',
            strongsNumber: 'H2617',
            language: 'hebrew',
            englishGloss: 'steadfast covenant love',
          );

    final detail = await widget.apiClient.getLexiconDetail(fallbackWord.strongsNumber ?? 'G26');
    if (!mounted) return;

    WordStudySheet.show(
      context,
      word: fallbackWord,
      detail: detail,
      verseReference: '${item.book} ${item.chapter}:${item.verse}',
      onSelectOccurrence: (occ) {
        widget.onNavigateToPassage?.call(occ.bookCode, occ.chapter, occ.verse);
      },
    );
  }

  bool _isNewTestament(String bookCode) {
    const ntCodes = {
      'MAT', 'MRK', 'LUK', 'JHN', 'ACT', 'ROM', '1CO', '2CO', 'GAL',
      'EPH', 'PHP', 'COL', '1TH', '2TH', '1TI', '2TI', 'TIT', 'PHM',
      'HEB', 'JAS', '1PE', '2PE', '1JN', '2JN', '3JN', 'JUD', 'REV',
    };
    return ntCodes.contains(bookCode.toUpperCase());
  }
}
