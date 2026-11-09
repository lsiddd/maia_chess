import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support_game_settings.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/application/game_clock.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_state.dart';
import 'package:maia_chess/features/game/application/time_control.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;

void main() {
  late MemorySettings settings;
  setUp(() => settings = MemorySettings());
  tearDown(() => settings.close());

  test('AI retry survives inference and shutdown failures together', () async {
    final repository = FakeGameRepository();
    final failedEngine = _ShutdownFailureMaiaEngine();
    final replacement = FakeMaiaEngine(onMove: (_, _) async => 'e7e5');
    var engineCount = 0;
    var now = 0;
    final container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repository),
        clockNowMsProvider.overrideWithValue(() => now),
        maiaModelResolverProvider.overrideWithValue(() async => 'test.onnx'),
        maiaEngineFactoryProvider.overrideWithValue(
          () => engineCount++ == 0 ? failedEngine : replacement,
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(gameControllerProvider.notifier);
    expect(
      await controller.startVsAi(
        humanSide: Side.white,
        levelRating: 1100,
        timeControl: const TimeControl(enabled: true, minutes: 1),
      ),
      isTrue,
    );
    final original = container.read(gameControllerProvider);
    now = 2000;
    await controller.attemptDragMove(
      Square.e2,
      Square.e4,
      onPromotion: () async => null,
    );

    final failed = container.read(gameControllerProvider);
    expect(failed.engineError, contains('inference failed'));
    expect(failed.engineError, contains('shutdown failed'));
    expect(failed.aiThinking, isFalse);
    expect(failed.isAiTurn, isTrue);
    expect(failed.gameId, original.gameId);
    expect(failed.uciHistory, ['e2e4']);
    expect(container.read(gameClockProvider)!.runningSide, isNull);
    expect(failedEngine.disposeCount, 1);
    expect(repository.games.values.single.moves.single.uci, 'e2e4');

    now += 10000;
    await controller.retryAiMove();

    final recovered = container.read(gameControllerProvider);
    expect(engineCount, 2);
    expect(replacement.requestedFens, [failed.position.fen]);
    expect(recovered.engineError, isNull);
    expect(recovered.aiThinking, isFalse);
    expect(recovered.gameId, original.gameId);
    expect(recovered.uciHistory, ['e2e4', 'e7e5']);
    expect(recovered.whiteTimeMs, 58000);
    expect(recovered.blackTimeMs, 60000);
    expect(repository.games.values.single.moves.map((move) => move.uci), [
      'e2e4',
      'e7e5',
    ]);
  });

  testWidgets(
    'autosave errors offer a direct retry without leaving the board',
    (tester) async {
      final repository = FakeGameRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          gameRepositoryProvider.overrideWithValue(repository),
          gameControllerProvider.overrideWith(_UnsavedGame.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final original = container.read(gameControllerProvider).position.fen;
      await tester.tap(find.byTooltip('Retry save'));
      await tester.pumpAndSettle();
      expect(container.read(gameControllerProvider).persistenceError, isNull);
      expect(container.read(gameControllerProvider).position.fen, original);
      expect(repository.games, hasLength(1));
      expect(find.byTooltip('Retry save'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Try again preserves the game and retries the AI move', (
    tester,
  ) async {
    final repository = FakeGameRepository();
    final engines = <FakeMaiaEngine>[];
    final answer = Completer<String>();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        gameRepositoryProvider.overrideWithValue(repository),
        gameIdFactoryProvider.overrideWithValue(() => 'retry-game'),
        maiaModelResolverProvider.overrideWithValue(
          () async => 'assets/maia3/maia3-79m-fp32.onnx',
        ),
        maiaEngineFactoryProvider.overrideWithValue(() {
          final attempt = engines.length;
          final engine = FakeMaiaEngine(
            onMove: (_, _) async {
              if (attempt < 2) throw StateError('search failed');
              return answer.future;
            },
          );
          engines.add(engine);
          return engine;
        }),
      ],
    );
    final controller = container.read(gameControllerProvider.notifier);
    addTearDown(container.dispose);
    await controller.startVsAi(
      humanSide: Side.white,
      levelRating: 1100,
      campaignMode: true,
    );
    await controller.attemptDragMove(
      Square.e2,
      Square.e4,
      onPromotion: () async => null,
    );
    final before = container.read(gameControllerProvider);
    expect(before.engineError, contains('search failed'));

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Another failure must preserve the position and allow retry.
    await tester.tap(find.byTooltip('Try again'));
    await tester.pumpAndSettle();
    final failedAgain = container.read(gameControllerProvider);
    expect(failedAgain.position.fen, before.position.fen);
    expect(failedAgain.uciHistory, ['e2e4']);
    expect(failedAgain.engineError, contains('search failed'));
    expect(engines, hasLength(2));
    expect(engines.take(2).every((engine) => engine.disposeCount == 1), isTrue);

    // Two taps before rebuilding must not start two searches.
    await tester.tap(find.byTooltip('Try again'));
    await tester.tap(find.byTooltip('Try again'));
    await tester.pump();
    expect(container.read(gameControllerProvider).aiThinking, isTrue);
    expect(find.byTooltip('Try again'), findsNothing);
    expect(find.text('Maia-3 to move'), findsOneWidget);
    expect(engines, hasLength(3));
    expect(engines.last.requestedFens, [before.position.fen]);

    answer.complete('e7e5');
    await tester.pumpAndSettle();
    final after = container.read(gameControllerProvider);
    expect(after.uciHistory, ['e2e4', 'e7e5']);
    expect(after.sanHistory, ['e4', 'e5']);
    expect(after.positionHistory.last.fen, before.position.fen);
    expect(after.gameId, before.gameId);
    expect(after.startedAtUtc, before.startedAtUtc);
    expect(after.campaignMode, before.campaignMode);
    expect(after.levelRating, before.levelRating);
    expect(after.evaluated, before.evaluated);
    expect(after.aiSide, before.aiSide);
    expect(after.engineError, isNull);
    expect(after.aiThinking, isFalse);
    final stored = await repository.getActiveGame();
    expect(stored!.id, before.gameId);
    expect(stored.moves.map((move) => move.uci), ['e2e4', 'e7e5']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.shutdownEngines();
  });
}

class _UnsavedGame extends GameController {
  @override
  GameState build() =>
      super.build().copyWith(persistenceError: 'Autosave failed.');
}

class _ShutdownFailureMaiaEngine extends FakeMaiaEngine {
  _ShutdownFailureMaiaEngine()
    : super(onMove: (_, _) async => throw StateError('inference failed'));

  @override
  Future<void> dispose() async {
    await super.dispose();
    throw StateError('shutdown failed');
  }
}
