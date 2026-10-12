import 'package:flutter/material.dart';

import 'board_theme.dart';

/// Shared spacing scale for screen padding and gaps.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Shared corner radii for cards, controls, and pill shapes.
abstract final class AppRadius {
  static const small = 12.0;
  static const medium = 16.0;
  static const large = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

/// Shared durations and curve: shorter for local feedback, longer for screen
/// transitions.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
  static const curve = Curves.easeOutCubic;
}

/// Serif accent for headings and prominent rating, level, and score values.
/// Keep labels, body text, and buttons in the default font.
abstract final class AppTypography {
  static const accentFontFamily = 'serif';
}

/// Centralised light and dark app themes, with board-dependent colours.
abstract final class AppTheme {
  static const _seedColor = Color(0xFF629924);

  static ThemeData get light => lightFor(BoardTheme.brown);

  static ThemeData get dark => darkFor(BoardTheme.brown);

  static ThemeData lightFor(BoardTheme boardTheme) =>
      _themeFor(Brightness.light, boardTheme);

  static ThemeData darkFor(BoardTheme boardTheme) =>
      _themeFor(Brightness.dark, boardTheme);

  static ThemeData _themeFor(Brightness brightness, BoardTheme boardTheme) {
    final dark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFF9BC95D) : const Color(0xFF4B751C),
          onPrimary: dark ? const Color(0xFF18240F) : Colors.white,
          surface: dark ? const Color(0xFF262421) : Colors.white,
          onSurface: dark ? const Color(0xFFBABABA) : const Color(0xFF4D4D4D),
          onSurfaceVariant: dark
              ? const Color(0xFFB0ACA5)
              : const Color(0xFF5E5A53),
          surfaceContainerLowest: dark ? const Color(0xFF161512) : Colors.white,
          surfaceContainerLow: dark
              ? const Color(0xFF211F1C)
              : const Color(0xFFF8F7F5),
          surfaceContainer: dark
              ? const Color(0xFF302E2B)
              : const Color(0xFFF2F0ED),
          surfaceContainerHigh: dark
              ? const Color(0xFF383633)
              : const Color(0xFFEAE7E2),
          surfaceContainerHighest: dark
              ? const Color(0xFF403D39)
              : const Color(0xFFE2DFD8),
        );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF161512)
          : const Color(0xFFEDEBE8),
      extensions: [BoardAppearance(boardTheme: boardTheme)],
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? const Color(0xFF161512)
            : const Color(0xFFEDEBE8),
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      // Neutral card surfaces with the shared app radius.
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
    );
  }
}
