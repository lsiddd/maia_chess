import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/core/constants/piece_assets.dart';

/// Precache SVGs so first rendering does not decode assets on the first game
/// frame or drag.
void main() {
  setUp(svg.cache.clear);
  tearDown(svg.cache.clear);

  testWidgets('precaches SVGs for all 12 pieces in the flutter_svg cache', (
    tester,
  ) async {
    expect(svg.cache.count, 0);

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await precachePieceSvgs(capturedContext);

    // Six roles in two colours, each with its own cache entry.
    expect(svg.cache.count, 12);
  });
}
