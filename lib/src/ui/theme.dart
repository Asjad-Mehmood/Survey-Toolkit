// The look: a calm desktop program, like Windows 11. Grey page, white panels, thin lines, 13 px
// Inter text, 32 px controls; the logo's navy for actions and its gold only for updates. JetBrains Mono
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

  // Calm desktop surfaces, like Windows 11: grey page, white panels, thin lines. Navy is the one
  // action colour; gold only marks an update.
  static const light = ToolkitColors(
    background: Color(0xFFF6F7FB),
    card: Color(0xFFFFFFFF),
    cardSoft: Color(0xFFEFF2F7),
    line: Color(0xFFE4E7EE),
    ink: Color(0xFF1A1D23),
    muted: Color(0xFF5E6573),
    accent: Color(0xFFD9A62E),
    onAccent: Color(0xFF1B1405),
    rise: Color(0xFF1E7B47),
    fall: Color(0xFFB3402A),
    heroStart: BrandColors.navy,
    heroEnd: BrandColors.navyLight,
  );

  static const dark = ToolkitColors(
    background: Color(0xFF16181D),
    card: Color(0xFF1E2128),
    cardSoft: Color(0xFF262A32),
    line: Color(0xFF30343D),
    ink: Color(0xFFE7E9ED),
    muted: Color(0xFF9AA0AB),
    accent: BrandColors.gold,
    onAccent: Color(0xFF1B1405),
    rise: Color(0xFF5BC48B),
    fall: Color(0xFFEE8670),
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

/// The navy of buttons and the selected item (lighter in dark mode, to read on dark grey)
Color actionColour(Brightness b) => b == Brightness.light ? BrandColors.navyLight : const Color(0xFF8DB4F5);

/// Sizes every screen uses: a desktop program for a mouse, not a phone
abstract final class Sizes {
  static const control = 32.0;
  static const radius = 8.0;
  static const panelRadius = 12.0;
  static const header = 48.0;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? ToolkitColors.light : ToolkitColors.dark;
  final action = actionColour(brightness);
  final scheme = ColorScheme.fromSeed(seedColor: BrandColors.navyLight, brightness: brightness).copyWith(
    primary: action,
    onPrimary: brightness == Brightness.light ? Colors.white : BrandColors.navy,
    secondary: c.accent,
    onSecondary: c.onAccent,
    surface: c.card,
    onSurface: c.ink,
    onSurfaceVariant: c.muted,
    surfaceContainerHighest: c.cardSoft,
    outline: c.line,
    outlineVariant: c.line,
    error: c.fall,
  );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: textFont,
    brightness: brightness,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    // a mouse program: a quiet hover, no ink ripples
    splashFactory: NoSplash.splashFactory,
    hoverColor: c.ink.withValues(alpha: 0.05),
    highlightColor: c.ink.withValues(alpha: 0.08),
    focusColor: action.withValues(alpha: 0.14),
  );
  TextStyle t(double size, FontWeight w, {double? height, double spacing = 0}) => TextStyle(
    fontFamily: textFont,
    fontSize: size,
    fontWeight: w,
    height: height,
    letterSpacing: spacing,
    color: c.ink,
  );
  final text = base.textTheme
      .copyWith(
        headlineSmall: t(20, FontWeight.w600, spacing: -0.2),
        titleLarge: t(17, FontWeight.w600, spacing: -0.1),
        titleMedium: t(14, FontWeight.w600),
        titleSmall: t(13, FontWeight.w600),
        bodyLarge: t(14, FontWeight.w400, height: 1.45),
        bodyMedium: t(13, FontWeight.w400, height: 1.45),
        bodySmall: t(12, FontWeight.w400, height: 1.4),
        labelLarge: t(13, FontWeight.w500),
        labelMedium: t(12, FontWeight.w500),
        labelSmall: t(11, FontWeight.w500),
      )
      .apply(bodyColor: c.ink, displayColor: c.ink);
  final radius = BorderRadius.circular(Sizes.radius);
  final shape = RoundedRectangleBorder(borderRadius: radius);
  const buttonText = TextStyle(fontFamily: textFont, fontWeight: FontWeight.w500, fontSize: 13);
  const buttonSize = Size(32, Sizes.control);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 12);

  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    extensions: [c],
    textTheme: text,
    iconTheme: IconThemeData(color: c.ink, size: 18),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.panelRadius),
        side: BorderSide(color: c.line),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.card,
      foregroundColor: c.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: Sizes.header,
      titleTextStyle: t(14, FontWeight.w600),
      iconTheme: IconThemeData(color: c.ink, size: 18),
      actionsIconTheme: IconThemeData(color: c.ink, size: 18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
        borderSide: BorderSide(color: action, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.fall),
      ),
      labelStyle: TextStyle(color: c.muted, fontSize: 13),
      floatingLabelStyle: TextStyle(color: c.ink, fontSize: 13, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: c.muted, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: shape,
        textStyle: buttonText,
        iconSize: 16,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        foregroundColor: c.ink,
        backgroundColor: c.card,
        side: BorderSide(color: c.line),
        shape: shape,
        textStyle: buttonText,
        iconSize: 16,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: buttonSize,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: c.ink,
        shape: shape,
        textStyle: buttonText,
        iconSize: 16,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: buttonSize,
        fixedSize: buttonSize,
        padding: EdgeInsets.zero,
        iconSize: 18,
        foregroundColor: c.ink,
        shape: shape,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(32, 30),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontFamily: textFont, fontSize: 12.5, fontWeight: FontWeight.w500),
        foregroundColor: c.ink,
        selectedForegroundColor: brightness == Brightness.light ? Colors.white : BrandColors.navy,
        selectedBackgroundColor: action,
        side: BorderSide(color: c.line),
        shape: shape,
        visualDensity: VisualDensity.compact,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : c.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? action : c.cardSoft),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? action : c.line),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      titleTextStyle: t(13, FontWeight.w500),
      subtitleTextStyle: TextStyle(fontFamily: textFont, fontSize: 12, color: c.muted, height: 1.4),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.cardSoft,
      selectedColor: action,
      side: BorderSide(color: c.line),
      labelStyle: TextStyle(fontFamily: textFont, fontSize: 12.5, fontWeight: FontWeight.w500, color: c.ink),
      secondaryLabelStyle: const TextStyle(
        fontFamily: textFont,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      shape: shape,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.panelRadius),
        side: BorderSide(color: c.line),
      ),
      textStyle: t(13, FontWeight.w400),
      labelTextStyle: WidgetStatePropertyAll(t(13, FontWeight.w400)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      titleTextStyle: t(16, FontWeight.w600),
      contentTextStyle: TextStyle(fontFamily: textFont, fontSize: 13, height: 1.5, color: c.ink),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: action, linearTrackColor: c.cardSoft),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(c.muted.withValues(alpha: 0.35)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.light ? const Color(0xFF23272F) : const Color(0xFF3A3F49),
      contentTextStyle: const TextStyle(fontFamily: textFont, color: Colors.white, fontSize: 13),
      shape: shape,
      width: 420,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: brightness == Brightness.light ? const Color(0xFF23272F) : const Color(0xFF3A3F49),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      textStyle: const TextStyle(fontFamily: textFont, color: Colors.white, fontSize: 12),
    ),
  );
}
