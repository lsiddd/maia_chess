import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Fase 4 etapa A: cria autosave durável', (tester) async {
    final container = ProviderContainer();
    final controller = container.read(gameControllerProvider.notifier);
    try {
      await controller.startTwoPlayers();
      await controller.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: () async => null,
      );
      await controller.attemptDragMove(
        Square.e7,
        Square.e5,
        onPromotion: () async => null,
      );
      await controller.markAsNotEvaluated();
      await controller.flushPersistence();

      final stored = await container
          .read(gameRepositoryProvider)
          .getActiveGame();
      expect(stored, isNotNull);
      expect(stored!.moves.map((move) => move.uci), ['e2e4', 'e7e5']);
      expect(stored.evaluated, isFalse);
      expect(
        stored.currentFen,
        container.read(gameControllerProvider).position.fen,
      );
    } finally {
      await controller.shutdownEngines();
      container.dispose();
    }
  });

  testWidgets('Fase 4 etapa B: restaura autosave após recriar o container', (
    tester,
  ) async {
    final container = ProviderContainer();
    final controller = container.read(gameControllerProvider.notifier);
    try {
      expect(await controller.restoreActiveGame(), isTrue);
      final restored = container.read(gameControllerProvider);
      expect(restored.uciHistory, ['e2e4', 'e7e5']);
      expect(restored.sanHistory, ['e4', 'e5']);
      expect(restored.evaluated, isFalse);
      expect(restored.position.turn, Side.white);

      final repository = container.read(gameRepositoryProvider);
      final game = await repository.getActiveGame();
      expect(game, isNotNull);
      final exported = const PgnService().export(game!);
      final imported = const PgnService().parseImport(
        pgn: exported,
        id: 'android-roundtrip',
        importedAtUtc: DateTime.now().toUtc(),
      );
      expect(imported.moves.map((move) => move.uci), ['e2e4', 'e7e5']);

      await repository.deleteGame(game.id);
    } finally {
      await controller.shutdownEngines();
      container.dispose();
    }
  });
}
