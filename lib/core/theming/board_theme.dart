import 'package:flutter/material.dart';

/// Original Lichess boards bundled for offline use.
enum BoardTheme {
  brown('Brown'),
  blue('Blue'),
  green('Green'),
  purple('Purple');

  const BoardTheme(this.label);

  final String label;

  String get assetPath => 'assets/chess_boards/$name.png';
}

class BoardAppearance extends ThemeExtension<BoardAppearance> {
  const BoardAppearance({this.boardTheme = BoardTheme.brown});

  final BoardTheme boardTheme;

  static BoardAppearance of(BuildContext context) =>
      Theme.of(context).extension<BoardAppearance>() ?? const BoardAppearance();

  @override
  BoardAppearance copyWith({BoardTheme? boardTheme}) =>
      BoardAppearance(boardTheme: boardTheme ?? this.boardTheme);

  @override
  BoardAppearance lerp(covariant BoardAppearance? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
