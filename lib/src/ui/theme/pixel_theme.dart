import 'package:flutter/material.dart';

import 'palette.dart';

/// Font families declared in pubspec.yaml.
class PixelFonts {
  const PixelFonts._();

  /// Arcade display face. Very wide, so it is only used at small sizes and
  /// for short strings.
  static const String display = 'PressStart2P';

  /// Compact bitmap face for body copy and data.
  static const String body = 'Silkscreen';
}

/// Text styles for the 8-bit look. Sizes are whole numbers because bitmap
/// faces look best at integer sizes.
class PixelText {
  const PixelText._();

  /// The verdict uses the body face, not the arcade one, on purpose:
  /// Press Start 2P squeezes accented capitals into the same box as the plain
  /// letter, so "PONT FERMÉ" — the single most important string in the app —
  /// came out looking like a typo. Silkscreen puts the accent above cap
  /// height where it belongs.
  static const TextStyle verdict = TextStyle(
    fontFamily: PixelFonts.body,
    fontSize: 32,
    height: 1.25,
    letterSpacing: 1,
  );

  static const TextStyle title = TextStyle(
    fontFamily: PixelFonts.display,
    fontSize: 12,
    height: 1.6,
  );

  static const TextStyle label = TextStyle(
    fontFamily: PixelFonts.display,
    fontSize: 8,
    height: 1.6,
    letterSpacing: 0.5,
  );

  static const TextStyle body = TextStyle(
    fontFamily: PixelFonts.body,
    fontSize: 16,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: PixelFonts.body,
    fontSize: 13,
    height: 1.5,
  );

  /// Times, dates and counters — the numbers people actually read.
  static const TextStyle data = TextStyle(
    fontFamily: PixelFonts.body,
    fontSize: 20,
    height: 1.3,
  );

  static const TextStyle dataLarge = TextStyle(
    fontFamily: PixelFonts.body,
    fontSize: 28,
    height: 1.2,
  );
}

ThemeData buildPixelTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    primary: PixelPalette.open,
    onPrimary: C64.black,
    secondary: C64.cyan,
    onSecondary: C64.black,
    error: PixelPalette.closed,
    onError: C64.black,
    surface: PixelPalette.panel,
    onSurface: PixelPalette.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PixelPalette.background,
    canvasColor: PixelPalette.background,
    fontFamily: PixelFonts.body,
    // Hard edges everywhere: no elevation, no ripples, no rounded corners.
    splashFactory: NoSplash.splashFactory,
    highlightColor: const Color(0x00000000),
    hoverColor: const Color(0x14FFFFFF),
    dividerTheme: const DividerThemeData(
      color: PixelPalette.panelBorder,
      thickness: 2,
      space: 2,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: PixelPalette.open,
      selectionColor: C64.lightBlue,
    ),
    textTheme: const TextTheme(
      displayLarge: PixelText.verdict,
      titleLarge: PixelText.title,
      titleMedium: PixelText.label,
      bodyLarge: PixelText.body,
      bodyMedium: PixelText.bodySmall,
      labelLarge: PixelText.label,
    ).apply(bodyColor: PixelPalette.ink, displayColor: PixelPalette.ink),
  );
}
