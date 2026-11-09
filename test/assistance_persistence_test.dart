import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';

import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;
import 'opponent_threats_test.dart' show MultiPvEngine;

void main() {
  for (final plans in [false, true]) {
    test(
      '${plans ? 'Plans' : 'Hints'} require a durable unrated autosave on every retry',
      () async {
        final repository = _ControlledSaveRepository();
        final engine = MultiPvEngine();
        var engineStarts = 0;
        final container = ProviderContainer(
          overrides: [
            gameRepositoryProvider.overrideWithValue(repository),
            maiaEngineFactoryProvider.overrideWithValue(
              () => FakeMaiaEngine(onMove: (_, _) async => 'e7e5'),
            ),
            maiaModelResolverProvider.overrideWithValue(
              () async => 'test.onnx',
            ),
            stockfishWarmupEnabledProvider.overrideWithValue(false),
            stockfishEngineFactoryProvider.overrideWithValue(() {
              engineStarts++;
              return engine;
            }),
          ],
        );
        final controller = container.read(gameControllerProvider.notifier);
        addTearDown(() async {
          await controller.shutdownEngines();
          container.dispose();
        });
        await controller.startVsAi(humanSide: Side.white, levelRating: 1100);
        Future<Object> request() =>
            plans ? controller.getOpponentThreats() : controller.getHint();

        repository.fail = true;
        for (var attempt = 0; attempt < 2; attempt++) {
          await expectLater(request(), throwsStateError);
          final state = container.read(gameControllerProvider);
          expect(state.evaluated, isFalse);
          expect(state.persistenceError, contains('disk unavailable'));
          expect(state.hintThinking, isFalse);
          expect(repository.games.values.single.evaluated, isTrue);
          expect(engineStarts, 0);
        }

        repository.fail = false;
        final gate = repository.gate = Completer<void>();
        // A second caller must not bypass a pending eligibility write merely
        // because the in-memory game is already unrated.
        final marking = controller.markAsNotEvaluated();
        final pending = request();
        await Future<void>.delayed(Duration.zero);
        expect(engineStarts, 0);
        expect(repository.games.values.single.evaluated, isTrue);
        gate.complete();
        await marking;
        await pending;

        expect(repository.games.values.single.evaluated, isFalse);
        expect(container.read(gameControllerProvider).persistenceError, isNull);
        expect(engineStarts, 1);
        expect(await controller.restoreActiveGame(), isTrue);
        expect(container.read(gameControllerProvider).evaluated, isFalse);
      },
    );
  }
}

class _ControlledSaveRepository extends FakeGameRepository {
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<void> saveOngoing(StoredGame game) async {
    await gate?.future;
    if (fail) throw StateError('disk unavailable');
    await super.saveOngoing(game);
  }
}
