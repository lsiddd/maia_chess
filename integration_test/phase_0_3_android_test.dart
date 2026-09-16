import 'dart:io' as io;

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:maia_chess/engine_ffi/lc0_engine/lc0_service.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android real: 1100 -> dica -> jogar -> 1900 -> dica', (
    tester,
  ) async {
    final container = ProviderContainer();
    final controller = container.read(gameControllerProvider.notifier);

    try {
      expect(
        await controller.startVsAi(humanSide: Side.white, levelRating: 1100),
        isTrue,
        reason: container.read(gameControllerProvider).engineError,
      );

      final hint1100 = await controller.getHint(stockfishMovetimeMs: 1000);
      expect(hint1100.levelRating, 1100);
      expect(hint1100.maiaSan, isNotEmpty);
      expect(hint1100.stockfishSan, isNotEmpty);

      await controller.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: () async => null,
      );
      final afterMove = container.read(gameControllerProvider);
      expect(afterMove.sanHistory, hasLength(2));
      expect(afterMove.position.turn, Side.white);
      expect(afterMove.engineError, isNull);

      expect(
        await controller.startVsAi(humanSide: Side.white, levelRating: 1900),
        isTrue,
        reason: container.read(gameControllerProvider).engineError,
      );

      final hint1900 = await controller.getHint(stockfishMovetimeMs: 1000);
      expect(hint1900.levelRating, 1900);
      expect(hint1900.maiaSan, isNotEmpty);
      expect(hint1900.stockfishSan, isNotEmpty);
    } finally {
      await controller.shutdownEngines();
      container.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('Android real: lc0 recupera após falha nativa de peso', (
    tester,
  ) async {
    final engine = Lc0Service();
    final temporaryDirectory = await getTemporaryDirectory();
    final invalidWeights = io.File(
      '${temporaryDirectory.path}/maia-corrompido.pb.gz',
    );
    await invalidWeights.writeAsBytes([0x6e, 0x61, 0x6f, 0x2d, 0x67, 0x7a]);
    try {
      await engine.init(invalidWeights.path);
      await expectLater(
        engine.getBestMove(Chess.initial.fen, nodes: 1),
        throwsA(anything),
      );
      expect(engine.isReady, isFalse);

      final validWeights = await Lc0Service.extractWeightsAsset(
        'assets/maia_weights/maia-1100.pb.gz',
      );
      await engine.init(validWeights);
      expect(engine.isReady, isTrue);

      final move = await engine.getBestMove(Chess.initial.fen, nodes: 1);
      expect(Move.parse(move), isNotNull);
    } finally {
      await engine.dispose();
      if (await invalidWeights.exists()) {
        await invalidWeights.delete();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
