import 'package:flutter/widgets.dart';

import '../theming/board_theme.dart';

/// Aquece os tabuleiros antes de abrir uma partida, como fazemos com as peças.
Future<void> precacheBoardImages(BuildContext context) => Future.wait(
  BoardTheme.values.map(
    (theme) => precacheImage(
      ResizeImage(AssetImage(theme.assetPath), width: 1024),
      context,
    ),
  ),
);
