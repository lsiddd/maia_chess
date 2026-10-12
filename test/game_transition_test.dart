import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';

import 'game_controller_test.dart' show FakeGameRepository, FakeLc0Engine;

void main() {
  for (final response in ['saved', 'error', 'missing']) {
    test('delayed restore ($response) preserves the new game', () async {
      final repository = _DelayedReadRepository();
      var nextId = 0;
      final container = ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(repository),
          gameIdFactoryProvider.overrideWithValue(() => 'game-${nextId++}'),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startTwoPlayers();
      await controller.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: () async => null,
      );
      final oldGame = repository.games.values.single;
      final restoring = controller.restoreActiveGame();
      await repository.readStarted.future;
      await controller.startTwoPlayers();
      final newer = container.read(gameControllerProvider);

      switch (response) {
        case 'saved':
          repository.delayedRead.complete(oldGame);
        case 'error':
          repository.delayedRead.completeError(StateError('read failed'));
        case 'missing':
          repository.delayedRead.complete(null);
      }
      expect(await restoring, isFalse);
      expect(container.read(gameControllerProvider), same(newer));
      expect(repository.games.values.single.id, newer.gameId);
      await controller.attemptDragMove(
        Square.d2,
        Square.d4,
        onPromotion: () async => null,
      );
      expect(repository.games.values.single.moves.single.uci, 'd2d4');
    });
  }

  test(
    'a Maia response after disposal does not persist another move',
    () async {
      final answer = Completer<String>();
      final searchStarted = Completer<void>();
      final repository = FakeGameRepository();
      final engine = FakeLc0Engine(
        onMove: (_, _) {
          searchStarted.complete();
          return answer.future;
        },
      );
      final container = ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(repository),
          maiaWeightsResolverProvider.overrideWithValue(
            (level) async => level.weightsAsset,
          ),
          lc0EngineFactoryProvider.overrideWithValue(() => engine),
          stockfishWarmupEnabledProvider.overrideWithValue(false),
        ],
      );
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startVsAi(humanSide: Side.white, levelRating: 1100);
      final pending = controller.attemptDragMove(
        Square.e2,
        Square.e4,
        onPromotion: () async => null,
      );
      await searchStarted.future;
      container.dispose();
      answer.complete('e7e5');
      await pending;
      expect(repository.games.values.single.moves.map((move) => move.uci), [
        'e2e4',
      ]);
      expect(engine.disposeCount, 1);
    },
  );
}

class _DelayedReadRepository extends FakeGameRepository {
  final readStarted = Completer<void>();
  final delayedRead = Completer<StoredGame?>();
  @override
  Future<StoredGame?> getActiveGame() {
    readStarted.complete();
    return delayedRead.future;
  }
}
