// The look: the logo's navy and survey gold, light and dark, Inter for text and JetBrains Mono
// for versions and codes. Both fonts ship inside the app, so it looks the same offline.
import 'package:flutter/material.dart';

import '../brand.dart';

/// Colours the Material scheme has no name for.
@immutable
class ToolkitColors extends ThemeExtension<ToolkitColors> {
  const ToolkitColors({
    required this.background,
    required this.card,
    required this.cardSoft,
    required this.line,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.rise,
    required this.fall,
    required this.heroStart,
    required this.heroEnd,
  });

  final Color background;
  final Color card;

  /// Input tiles and table stripes
  final Color cardSoft;
  final Color line;
  final Color ink;
  final Color muted;

  /// Survey gold: step numbers, the selected interval, the slope line
  final Color accent;
  final Color onAccent;

  /// Rising and falling values
  final Color rise;
  final Color fall;

  /// The slope % card
  final Color heroStart;
  final Color heroEnd;

  static const light = ToolkitColors(
    background: Color(0xFFF3F5F9),
    card: Color(0xFFFFFFFF),
    cardSoft: Color(0xFFF6F8FB),
    line: Color(0xFFE1E6EF),
    ink: Color(0xFF0E1B33),
    muted: Color(0xFF5A6A85),
    accent: Color(0xFFE2AE34),
    onAccent: Color(0xFF1B1405),
    rise: Color(0xFF1C7C4A),
    fall: Color(0xFFB4442F),
    heroStart: BrandColors.navy,
    heroEnd: BrandColors.navyLight,
  );

  static const dark = ToolkitColors(
    background: Color(0xFF0A1322),
    card: Color(0xFF111D33),
    cardSoft: Color(0xFF16253F),
    line: Color(0xFF233657),
    ink: Color(0xFFEDF2FA),
    muted: Color(0xFF98A9C6),
    accent: BrandColors.gold,
    onAccent: Color(0xFF1B1405),
    rise: Color(0xFF5CCB8F),
    fall: Color(0xFFF08A73),
    heroStart: Color(0xFF17386B),
    heroEnd: Color(0xFF1F4C8F),
  );

  @override
  ToolkitColors copyWith() => this;

  @override
  ToolkitColors lerp(ToolkitColors? other, double t) => t < 0.5 || other == null ? this : other;
}

extension ToolkitTheme on BuildContext {
  ToolkitColors get colors => Theme.of(this).extension<ToolkitColors>()!;
}

const textFont = 'Inter';
const readingFont = 'JetBrainsMono';

/// Numbers that line up in columns
const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? ToolkitColors.light : ToolkitColors.dark;
  final scheme = ColorScheme.fromSeed(seedColor: BrandColors.navyLight, brightness: brightness).copyWith(
    primary: brightness == Brightness.light ? BrandColors.navyLight : const Color(0xFF8DB4F5),
    onPrimary: brightness == Brightness.light ? Colors.white : BrandColors.navy,
    secondary: c.accent,
    onSecondary: c.onAccent,
    surface: c.card,
    onSurface: c.ink,
    onSurfaceVariant: c.muted,
    outline: c.line,
    outlineVariant: c.line,
    error: c.fall,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: textFont, brightness: brightness);
  final text = base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink);
  final radius = BorderRadius.circular(12);

  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    extensions: [c],
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.cardSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.fall, width: 1.5),
      ),
      labelStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: textFont, fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: c.ink,
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: textFont, fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(44, 44))),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.cardSoft,
      selectedColor: c.accent,
      side: BorderSide(color: c.line),
      labelStyle: TextStyle(fontFamily: textFont, fontWeight: FontWeight.w600, color: c.ink),
      secondaryLabelStyle: TextStyle(fontFamily: textFont, fontWeight: FontWeight.w700, color: c.onAccent),
      shape: const StadiumBorder(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: BrandColors.navy,
      contentTextStyle: const TextStyle(fontFamily: textFont, color: Colors.white, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: BrandColors.navy, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontFamily: textFont, color: Colors.white, fontSize: 12.5),
    ),
  );
}
