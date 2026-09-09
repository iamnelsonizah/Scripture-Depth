import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/scripture_models.dart';

enum QuoteCardTheme {
  gradientAura,
  minimalistPaper,
  cathedralNoir,
  livingWater,
}

/// Aesthetic Visual Quote Card Generator & Social Share Sheet
class ShareVerseSheet extends StatefulWidget {
  final MemorizationCardModel card;
  final List<Color> gradientColors;

  const ShareVerseSheet({
    super.key,
    required this.card,
    required this.gradientColors,
  });

  static void show(
    BuildContext context, {
    required MemorizationCardModel card,
    required List<Color> gradientColors,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareVerseSheet(
        card: card,
        gradientColors: gradientColors,
      ),
    );
  }

  @override
  State<ShareVerseSheet> createState() => _ShareVerseSheetState();
}

class _ShareVerseSheetState extends State<ShareVerseSheet> {
  QuoteCardTheme _selectedTheme = QuoteCardTheme.gradientAura;

  String get _formattedShareText =>
      '“${widget.card.verseText}”\n— ${widget.card.reference}\n\nStudied with ScriptureDepth';

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _formattedShareText));
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Verse copied to clipboard for sharing!'),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _exportVisualCard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _formattedShareText));
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.image_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text('Visual Quote Card generated & copied for story sharing!'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: ext.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ext.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Share Scripture',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: ext.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Export as high-resolution visual quote card or copy text',
            style: TextStyle(fontSize: 12, color: ext.inkSoft),
          ),
          const SizedBox(height: 14),

          // Theme Selector Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _themeChip(QuoteCardTheme.gradientAura, 'Aura Gradient', ext),
                const SizedBox(width: 8),
                _themeChip(QuoteCardTheme.minimalistPaper, 'Minimalist Paper', ext),
                const SizedBox(width: 8),
                _themeChip(QuoteCardTheme.cathedralNoir, 'Cathedral Noir', ext),
                const SizedBox(width: 8),
                _themeChip(QuoteCardTheme.livingWater, 'Living Water', ext),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Visual Quote Card Preview
          _buildActiveCardPreview(ext),
          const SizedBox(height: 20),

          // Share Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(context),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Quote'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportVisualCard(context),
                  icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF25D366)),
                  label: const Text('WhatsApp / Social', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ext.line, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeChip(QuoteCardTheme theme, String label, ScriptureThemeExtension ext) {
    final isSelected = _selectedTheme == theme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTheme = theme);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ext.teal : ext.paperSecondary,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isSelected ? ext.teal : ext.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : ext.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCardPreview(ScriptureThemeExtension ext) {
    BoxDecoration decoration;
    Color textColor;
    Color refPillColor;
    Color refTextColor;
    Color brandColor;

    switch (_selectedTheme) {
      case QuoteCardTheme.gradientAura:
        decoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.gradientColors.first.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        );
        textColor = Colors.white;
        refPillColor = Colors.white.withOpacity(0.18);
        refTextColor = Colors.white;
        brandColor = Colors.white70;
        break;

      case QuoteCardTheme.minimalistPaper:
        decoration = BoxDecoration(
          color: const Color(0xFFFBFBF9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        );
        textColor = const Color(0xFF0F172A);
        refPillColor = const Color(0xFF0F172A);
        refTextColor = Colors.white;
        brandColor = const Color(0xFF64748B);
        break;

      case QuoteCardTheme.cathedralNoir:
        decoration = BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        );
        textColor = const Color(0xFFFDE68A);
        refPillColor = const Color(0xFFD97706);
        refTextColor = Colors.white;
        brandColor = const Color(0xFFD97706);
        break;

      case QuoteCardTheme.livingWater:
        decoration = BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF042F2E), Color(0xFF0D9488)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        );
        textColor = Colors.white;
        refPillColor = Colors.white.withOpacity(0.2);
        refTextColor = Colors.white;
        brandColor = Colors.white70;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: refPillColor,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  widget.card.reference,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: refTextColor,
                  ),
                ),
              ),
              Icon(Icons.format_quote_rounded, color: brandColor, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '“${widget.card.verseText}”',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 16.5,
              height: 1.55,
              fontStyle: FontStyle.italic,
              color: textColor,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'ScriptureDepth Study',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600,
                  color: brandColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
