import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/core/constants/piece_assets.dart';

/// O primeiro desenho de cada peça exige ler o asset e parsear o SVG. Se
/// isso só acontecesse quando o tabuleiro aparece, a decodificação cairia no
/// primeiro quadro da partida e no primeiro arraste, causando engasgo.
void main() {
  setUp(svg.cache.clear);
  tearDown(svg.cache.clear);

  testWidgets('pré-carrega os SVGs das 12 peças no cache do flutter_svg', (
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

    // 6 papéis × 2 cores, cada um com sua própria entrada de cache.
    expect(svg.cache.count, 12);
  });
}
