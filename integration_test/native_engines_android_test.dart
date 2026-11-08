import 'dart:io' as io;

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:maia_chess/engine_ffi/maia_engine/maia_service.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_model_asset.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native Android: 1100 -> hint -> play -> 1900 -> hint', (
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
      expect(hint1100.stockfishSan, isNotEmpty);

      // Cancelling a pending hint must allow the next move to proceed with
      // Maia. A different time budget prevents reuse of the cached hint
      // above.
      final pendingHint = controller.getHint(stockfishMovetimeMs: 1500);
      final cancellation = expectLater(
        pendingHint,
        throwsA(isA<HintCancelledException>()),
      );
      await controller.cancelHint();
      await cancellation;
      expect(container.read(gameControllerProvider).hintThinking, isFalse);

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
      expect(hint1900.stockfishSan, isNotEmpty);
    } finally {
      await controller.shutdownEngines();
      container.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('native Android: Maia-3 recovers after a native model failure', (
    tester,
  ) async {
    final engine = MaiaService();
    final temporaryDirectory = await getTemporaryDirectory();
    final invalidWeights = io.File(
      '${temporaryDirectory.path}/maia-invalid.onnx',
    );
    await invalidWeights.writeAsBytes([0x6e, 0x61, 0x6f, 0x2d, 0x67, 0x7a]);
    try {
      await expectLater(engine.init(invalidWeights.path), throwsA(anything));
      await engine.dispose();
      expect(engine.isReady, isFalse);

      final validWeights = await MaiaModelAsset.resolve();
      await engine.init(validWeights);
      expect(engine.isReady, isTrue);

      final move = await engine.getMove(
        [Chess.initial],
        selfElo: 600,
        opponentElo: 600,
      );
      expect(Move.parse(move), isNotNull);
    } finally {
      await engine.dispose();
      if (await invalidWeights.exists()) {
        await invalidWeights.delete();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
