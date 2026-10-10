import 'package:flutter/material.dart';

import 'board_theme.dart';

/// Escala de espaçamento compartilhada por todas as telas, para que o
/// padding/gap entre elementos siga a mesma progressão em vez de cada
/// widget escolher seu próprio valor (ver relatório de UI/UX, item
/// "design system").
abstract final class AppSpacing {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Escala de raio de borda compartilhada. Os valores espelham os que já
/// predominavam no app (12/16/20/28/pill) antes de existir um lugar único
/// para eles.
abstract final class AppRadius {
  static const small = 12.0;
  static const medium = 16.0;
  static const large = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

/// Duração e curva únicas para as microinterações do app, alinhadas ao
/// Material Motion (durações curtas para feedback local, mais longas para
/// transições entre telas).
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
  static const curve = Curves.easeOutCubic;
}

/// Acento tipográfico usado nos títulos de tela/seção (`headlineSmall`) e
/// nos números de destaque (rating estimado, nível, placar) em
/// CampaignScreen/StatsScreen/HomeScreen — nunca em rótulo, corpo de texto
/// ou botão. Decisão registrada aqui (em vez de repetir o literal em cada
/// `copyWith`) para não ficar implícita nem divergir entre telas.
abstract final class AppTypography {
  static const accentFontFamily = 'serif';
}

/// Tema visual do app, centralizado aqui (ver AUDITORIA_TECNICA.md,
/// AUD-012) em vez de inline em `main.dart`, consistente com a
/// organização feature-first do resto do projeto.
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
      // Cards com superfícies neutras e o raio compartilhado do app.
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
