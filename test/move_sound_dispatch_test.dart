import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/move_feedback.dart';

import 'game_controller_test.dart' show FakeGameRepository, FakeLc0Engine;

class _FailingGameRepository extends FakeGameRepository {
  @override
  Future<void> beginGame(StoredGame game, {bool Function()? canCommit}) async {
    throw StateError('Could not save game');
  }
}

void main() {
  ProviderContainer createContainer(
    List<String> sounds, {
    FakeGameRepository? repository,
  }) {
    final container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(
          repository ?? FakeGameRepository(),
        ),
        lc0EngineFactoryProvider.overrideWithValue(
          () => FakeLc0Engine(
            onMove: (fen, _) async =>
                fen == Chess.initial.fen ? 'e2e4' : 'e4d5',
          ),
        ),
        maiaWeightsResolverProvider.overrideWithValue(
          (level) async => level.weightsAsset,
        ),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
        moveSoundPlayerProvider.overrideWithValue((san) async {
          sounds.add(san);
        }),
      ],
    );
    addTearDown(() async {
      await container.read(gameControllerProvider.notifier).shutdownEngines();
      container.dispose();
    });
    return container;
  }

  test('sounds dispatch once per accepted player or Maia move', () async {
    final sounds = <String>[];
    final controller = createContainer(
      sounds,
    ).read(gameControllerProvider.notifier);

    expect(
      await controller.startVsAi(humanSide: Side.black, levelRating: 1100),
      isTrue,
    );
    expect(sounds, ['e4']);
    await controller.attemptDragMove(
      Square.d7,
      Square.d4,
      onPromotion: () async => null,
    );
    expect(sounds, ['e4']);

    await controller.attemptDragMove(
      Square.d7,
      Square.d5,
      onPromotion: () async => null,
    );
    expect(sounds, ['e4', 'd5', 'exd5']);
    expect(await controller.restoreActiveGame(), isTrue);
    await controller.undo();
    expect(sounds, ['e4', 'd5', 'exd5']);
  });

  test('an opening rejected by autosave does not dispatch sound', () async {
    final sounds = <String>[];
    final controller = createContainer(
      sounds,
      repository: _FailingGameRepository(),
    ).read(gameControllerProvider.notifier);

    expect(
      await controller.startVsAi(humanSide: Side.black, levelRating: 1100),
      isFalse,
    );
    expect(sounds, isEmpty);
  });
}
