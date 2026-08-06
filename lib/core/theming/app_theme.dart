import 'package:flutter/material.dart';

/// Tema visual do app, centralizado aqui (ver AUDITORIA_TECNICA.md,
/// AUD-012) em vez de inline em `main.dart`, consistente com a
/// organização feature-first do resto do projeto.
abstract final class AppTheme {
  static const _seedColor = Colors.brown;

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
    useMaterial3: true,
  );

  static ThemeData get dark => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
