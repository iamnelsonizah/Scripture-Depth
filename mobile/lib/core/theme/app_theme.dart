import 'package:flutter/material.dart';

class AppColors {
  // Highlight Swatches (matching reference image)
  static const Color highlightOrange = Color(0xFFF59E0B);
  static const Color highlightYellow = Color(0xFFEAB308);
  static const Color highlightGreen = Color(0xFF22C55E);
  static const Color highlightCyan = Color(0xFF06B6D4);
  static const Color highlightPurple = Color(0xFFA855F7);

  // Modern Light Palette (Crisp White Canvas & Vibrant Mint)
  static const Color lightPaper = Color(0xFFFFFFFF);
  static const Color lightPaper2 = Color(0xFFF8FAFC);
  static const Color lightElevated = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF0F172A);
  static const Color lightInkSoft = Color(0xFF64748B);
  static const Color lightTeal = Color(0xFF059669);      // Vibrant emerald mint
  static const Color lightTealSoft = Color(0xFFECFDF5);  // Delicate mint tint
  static const Color lightGold = Color(0xFFD97706);
  static const Color lightGoldSoft = Color(0xFFFFFBEB);
  static const Color lightLine = Color(0xFFE2E8F0);      // Crisp 1px card stroke

  // Modern Dark Palette (Obsidian Canvas & Luminous Mint)
  static const Color darkPaper = Color(0xFF090A0C);
  static const Color darkPaper2 = Color(0xFF121417);
  static const Color darkElevated = Color(0xFF1B1E23);
  static const Color darkInk = Color(0xFFF8FAFC);
  static const Color darkInkSoft = Color(0xFF94A3B8);
  static const Color darkTeal = Color(0xFF34D399);      // Luminous mint
  static const Color darkTealSoft = Color(0xFF064E3B);
  static const Color darkGold = Color(0xFFFBBF24);
  static const Color darkGoldSoft = Color(0xFF451A03);
  static const Color darkLine = Color(0xFF262A30);
}

class ScriptureThemeExtension extends ThemeExtension<ScriptureThemeExtension> {
  final Color paper;
  final Color paperSecondary;
  final Color surfaceElevated;
  final Color ink;
  final Color inkSoft;
  final Color teal;
  final Color tealSoft;
  final Color gold;
  final Color goldSoft;
  final Color line;
  final bool isDark;

  const ScriptureThemeExtension({
    required this.paper,
    required this.paperSecondary,
    required this.surfaceElevated,
    required this.ink,
    required this.inkSoft,
    required this.teal,
    required this.tealSoft,
    required this.gold,
    required this.goldSoft,
    required this.line,
    required this.isDark,
  });

  @override
  ThemeExtension<ScriptureThemeExtension> copyWith({
    Color? paper,
    Color? paperSecondary,
    Color? surfaceElevated,
    Color? ink,
    Color? inkSoft,
    Color? teal,
    Color? tealSoft,
    Color? gold,
    Color? goldSoft,
    Color? line,
    bool? isDark,
  }) {
    return ScriptureThemeExtension(
      paper: paper ?? this.paper,
      paperSecondary: paperSecondary ?? this.paperSecondary,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      teal: teal ?? this.teal,
      tealSoft: tealSoft ?? this.tealSoft,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      line: line ?? this.line,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  ThemeExtension<ScriptureThemeExtension> lerp(
    ThemeExtension<ScriptureThemeExtension>? other,
    double t,
  ) {
    if (other is! ScriptureThemeExtension) return this;
    return ScriptureThemeExtension(
      paper: Color.lerp(paper, other.paper, t)!,
      paperSecondary: Color.lerp(paperSecondary, other.paperSecondary, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealSoft: Color.lerp(tealSoft, other.tealSoft, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      line: Color.lerp(line, other.line, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }

  static const ScriptureThemeExtension light = ScriptureThemeExtension(
    paper: AppColors.lightPaper,
    paperSecondary: AppColors.lightPaper2,
    surfaceElevated: AppColors.lightElevated,
    ink: AppColors.lightInk,
    inkSoft: AppColors.lightInkSoft,
    teal: AppColors.lightTeal,
    tealSoft: AppColors.lightTealSoft,
    gold: AppColors.lightGold,
    goldSoft: AppColors.lightGoldSoft,
    line: AppColors.lightLine,
    isDark: false,
  );

  static const ScriptureThemeExtension dark = ScriptureThemeExtension(
    paper: AppColors.darkPaper,
    paperSecondary: AppColors.darkPaper2,
    surfaceElevated: AppColors.darkElevated,
    ink: AppColors.darkInk,
    inkSoft: AppColors.darkInkSoft,
    teal: AppColors.darkTeal,
    tealSoft: AppColors.darkTealSoft,
    gold: AppColors.darkGold,
    goldSoft: AppColors.darkGoldSoft,
    line: AppColors.darkLine,
    isDark: true,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightPaper,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightTeal,
        secondary: AppColors.lightGold,
        surface: AppColors.lightPaper,
        onSurface: AppColors.lightInk,
      ),
      extensions: const [ScriptureThemeExtension.light],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkPaper,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkTeal,
        secondary: AppColors.darkGold,
        surface: AppColors.darkPaper,
        onSurface: AppColors.darkInk,
      ),
      extensions: const [ScriptureThemeExtension.dark],
    );
  }
}
