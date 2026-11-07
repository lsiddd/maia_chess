import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';

import 'board_theme.dart';

/// A four-point rhythm shared by screens and controls.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const small = 12.0;
  static const medium = 16.0;
  static const large = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
  static const curve = Curves.easeOutCubic;

  static Duration duration(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Serif is reserved for editorial headings and prominent chess ratings.
abstract final class AppTypography {
  static const accentFontFamily = 'serif';
}

/// Forest ink, warm paper, and quiet surfaces keep the board in focus.
/// Board colours remain independently customisable.
abstract final class AppTheme {
  static ThemeData get light => lightFor(BoardTheme.brown);
  static ThemeData get dark => darkFor(BoardTheme.brown);
  static ThemeData lightFor(BoardTheme boardTheme) =>
      _themeFor(Brightness.light, boardTheme);
  static ThemeData darkFor(BoardTheme boardTheme) =>
      _themeFor(Brightness.dark, boardTheme);

  static ThemeData _themeFor(Brightness brightness, BoardTheme boardTheme) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF285C4D),
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFA5D5BC) : const Color(0xFF285C4D),
          onPrimary: dark ? const Color(0xFF10382B) : const Color(0xFFFFFFFF),
          primaryContainer: dark
              ? const Color(0xFF244D3E)
              : const Color(0xFFDCEBE1),
          onPrimaryContainer: dark
              ? const Color(0xFFDDEFE3)
              : const Color(0xFF183E30),
          secondary: dark ? const Color(0xFFCEC4A7) : const Color(0xFF665D42),
          secondaryContainer: dark
              ? const Color(0xFF423F31)
              : const Color(0xFFEDE6D5),
          onSecondaryContainer: dark
              ? const Color(0xFFF1E7CA)
              : const Color(0xFF433C28),
          surface: dark ? const Color(0xFF17221D) : const Color(0xFFFFFEF9),
          onSurface: dark ? const Color(0xFFE7EDE7) : const Color(0xFF202D26),
          onSurfaceVariant: dark
              ? const Color(0xFFB1BDB4)
              : const Color(0xFF57645B),
          surfaceContainerLowest: dark
              ? const Color(0xFF101914)
              : const Color(0xFFFFFEF9),
          surfaceContainerLow: dark
              ? const Color(0xFF17221D)
              : const Color(0xFFF7F6EF),
          surfaceContainer: dark
              ? const Color(0xFF1E2A23)
              : const Color(0xFFEFEEE6),
          surfaceContainerHigh: dark
              ? const Color(0xFF28362D)
              : const Color(0xFFE7E8DE),
          surfaceContainerHighest: dark
              ? const Color(0xFF344238)
              : const Color(0xFFDFE3D8),
          outline: dark ? const Color(0xFF7D8F81) : const Color(0xFF78877B),
          outlineVariant: dark
              ? const Color(0xFF36483C)
              : const Color(0xFFD4DACF),
        );
    final background = dark ? const Color(0xFF101914) : const Color(0xFFF7F6EF);
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    final text = base.textTheme.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.small),
    );
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(shape),
      textStyle: WidgetStatePropertyAll(
        text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      animationDuration: AppMotion.fast,
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [BoardAppearance(boardTheme: boardTheme)],
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontFamily: AppTypography.accentFontFamily,
          fontSize: 36,
          height: 1.15,
          letterSpacing: -0.8,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontFamily: AppTypography.accentFontFamily,
          fontSize: 30,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontFamily: AppTypography.accentFontFamily,
          fontSize: 26,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.l,
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle.copyWith(
          side: WidgetStatePropertyAll(BorderSide(color: colors.outline)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: buttonStyle.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStatePropertyAll(shape),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return states.contains(WidgetState.selected)
                ? colors.primaryContainer
                : colors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return states.contains(WidgetState.selected)
                ? colors.onPrimaryContainer
                : colors.onSurface;
          }),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.xs,
        ),
        iconColor: colors.primary,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        minVerticalPadding: AppSpacing.m,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.all(AppSpacing.l),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        titleTextStyle: text.headlineSmall?.copyWith(
          fontFamily: AppTypography.accentFontFamily,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        shape: shape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        selectedColor: colors.primaryContainer,
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.s,
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 450),
        showDuration: Duration(seconds: 3),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
