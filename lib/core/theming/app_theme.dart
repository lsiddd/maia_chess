import 'package:flutter/material.dart';

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
  static const _seedColor = Colors.brown;

  static ThemeData get light => _themeFor(Brightness.light);

  static ThemeData get dark => _themeFor(Brightness.dark);

  static ThemeData _themeFor(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      // Raio único para os cards que não definem sua própria forma
      // (vários hoje ficam com o padrão do Material, outros já cravavam
      // 12-28 caso a caso); mantém elevação/cor default de cada Card.
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
    );
  }
}
