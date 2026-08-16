import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual identity for the app: Aeolus, Greek keeper of the winds. A stormy,
/// nocturnal palette (deep indigo/violet sky) with an antique-gold accent
/// for actions and a cyan "wind" accent for secondary emphasis, paired with
/// a classical inscription-style display face for headings.
class AeolusPalette {
  const AeolusPalette({
    required this.skyTop,
    required this.skyBottom,
    required this.glassTint,
    required this.gold,
    required this.onGold,
    required this.wind,
    required this.storm,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color glassTint;
  final Color gold;
  final Color onGold;
  final Color wind;
  final Color storm;
  final Color textPrimary;
  final Color textSecondary;

  static const dark = AeolusPalette(
    skyTop: Color(0xFF0A0E1E),
    skyBottom: Color(0xFF1B1440),
    glassTint: Color(0xFF181C36),
    gold: Color(0xFFD9A441),
    onGold: Color(0xFF1A1206),
    wind: Color(0xFF3FD3C7),
    storm: Color(0xFF8B7FE8),
    textPrimary: Color(0xFFEEF0F9),
    textSecondary: Color(0xFFAFB6D6),
  );

  static const light = AeolusPalette(
    skyTop: Color(0xFFEEF3FA),
    skyBottom: Color(0xFFD6E1F0),
    glassTint: Color(0xFFFFFFFF),
    gold: Color(0xFF9C6B18),
    onGold: Color(0xFFFFFFFF),
    wind: Color(0xFF0E7C82),
    storm: Color(0xFF6A5ACD),
    textPrimary: Color(0xFF141A26),
    textSecondary: Color(0xFF4B5568),
  );
}

class AeolusTheme {
  AeolusTheme._();

  static ThemeData light() => _build(AeolusPalette.light, Brightness.light);
  static ThemeData dark() => _build(AeolusPalette.dark, Brightness.dark);

  static ThemeData _build(AeolusPalette p, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.gold,
      onPrimary: p.onGold,
      secondary: p.wind,
      onSecondary: p.onGold,
      tertiary: p.storm,
      onTertiary: p.onGold,
      error: const Color(0xFFE05A4E),
      onError: Colors.white,
      surface: p.glassTint,
      onSurface: p.textPrimary,
      outline: p.gold.withValues(alpha: 0.4),
    );

    final textTheme = _textTheme(p);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.skyTop,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: p.wind),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: p.textPrimary,
        iconTheme: IconThemeData(color: p.gold),
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.gold,
          foregroundColor: p.onGold,
          disabledBackgroundColor: p.gold.withValues(alpha: 0.25),
          disabledForegroundColor: p.onGold.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge,
          elevation: 6,
          shadowColor: p.gold.withValues(alpha: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.wind,
          side: BorderSide(color: p.wind.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.wind),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.gold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.glassTint.withValues(alpha: 0.5),
        labelStyle: TextStyle(color: p.textSecondary),
        hintStyle: TextStyle(color: p.textSecondary.withValues(alpha: 0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.gold.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.gold.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.wind, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: p.glassTint.withValues(alpha: 0.55),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.gold.withValues(alpha: 0.3)),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.gold.withValues(alpha: 0.2)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.onGold : p.textSecondary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.gold : Colors.transparent,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.gold.withValues(alpha: 0.5))),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.skyBottom,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.glassTint,
        contentTextStyle: TextStyle(color: p.textPrimary),
        actionTextColor: p.gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextTheme _textTheme(AeolusPalette p) {
    final display = GoogleFonts.cinzelTextTheme();
    final body = GoogleFonts.manropeTextTheme();

    TextStyle? goldDisplay(TextStyle? style, {double spacing = 1.5}) =>
        style?.copyWith(color: p.textPrimary, letterSpacing: spacing, fontWeight: FontWeight.w600);

    return body.copyWith(
      displayLarge: goldDisplay(display.displayLarge, spacing: 3),
      displayMedium: goldDisplay(display.displayMedium, spacing: 2.5),
      displaySmall: goldDisplay(display.displaySmall, spacing: 2),
      headlineLarge: goldDisplay(display.headlineLarge, spacing: 2),
      headlineMedium: goldDisplay(display.headlineMedium, spacing: 1.5),
      headlineSmall: goldDisplay(display.headlineSmall, spacing: 1.2),
      titleLarge: goldDisplay(display.titleLarge, spacing: 1.5),
      titleMedium: body.titleMedium?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w700),
      titleSmall: body.titleSmall?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(color: p.textPrimary),
      bodyMedium: body.bodyMedium?.copyWith(color: p.textSecondary),
      bodySmall: body.bodySmall?.copyWith(color: p.textSecondary.withValues(alpha: 0.85)),
      labelLarge: body.labelLarge?.copyWith(
        color: p.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}
