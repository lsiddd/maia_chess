import 'package:flutter/widgets.dart';

import '../theming/board_theme.dart';

/// Precache board images before opening a game, as with piece SVGs.
Future<void> precacheBoardImages(BuildContext context) => Future.wait(
  BoardTheme.values.map(
    (theme) => precacheImage(
      ResizeImage(AssetImage(theme.assetPath), width: 1024),
      context,
    ),
  ),
);
