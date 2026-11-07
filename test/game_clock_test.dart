import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_clock.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_state.dart';
import 'package:maia_chess/features/game/application/time_control.dart';

import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;

void main() {
  late ProviderContainer container;
  late GameController controller;
  late FakeGameRepository repository;
  var now = 0;

  void createGame() {
    now = 0;
    repository = FakeGameRepository();
    container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repository),
        clockNowMsProvider.overrideWithValue(() => now),
      ],
    );
    controller = container.read(gameControllerProvider.notifier);
  }

  tearDown(() => container.dispose());

  Future<void> play(String uci) {
    final move = NormalMove.fromUci(uci);
    return controller.attemptDragMove(
      move.from,
      move.to,
      onPromotion: () async => null,
    );
  }

  testWidgets('unlimited games never start a clock', (tester) async {
    createGame();
    await controller.startTwoPlayers();
    now += 3600000;
    await tester.pump(const Duration(seconds: 1));
    await play('e2e4');
    expect(container.read(gameClockProvider), isNull);
    expect(container.read(gameControllerProvider).isGameOver, isFalse);
    expect(repository.games.values.single.clockEnabled, isFalse);
  });

  testWidgets(
    'only the active side loses time; legal moves add increment once',
    (tester) async {
      createGame();
      await controller.startTwoPlayers(
        timeControl: const TimeControl(
          enabled: true,
          minutes: 1,
          incrementSeconds: 2,
        ),
      );
      final beforeTick = container.read(gameControllerProvider);
      now = 1500;
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        container.read(gameControllerProvider),
        same(beforeTick),
        reason: 'Ticks must not rebuild the chessboard.',
      );
      expect(container.read(gameClockProvider)!.whiteMs, 58500);
      expect(container.read(gameClockProvider)!.blackMs, 60000);
      await play('e2e4');
      expect(container.read(gameControllerProvider).whiteTimeMs, 60500);
      now = 4000;
      await play('e7e5');
      expect(container.read(gameControllerProvider).blackTimeMs, 59500);
      await play('e4e6'); // Illegal: no increment, no turn change.
      expect(container.read(gameControllerProvider).whiteTimeMs, 60500);
      expect(repository.games.values.single.incrementMs, 2000);
      expect(
        repository.games.values.single.pgn,
        contains('[TimeControl "60+2"]'),
      );
      controller.setClockPaused(true);
    },
  );

  testWidgets('pause persists exact balances and restore excludes time away', (
    tester,
  ) async {
    createGame();
    await controller.startTwoPlayers(
      timeControl: const TimeControl(
        enabled: true,
        minutes: 5,
        incrementSeconds: 3,
      ),
    );
    now = 1234;
    controller.setClockPaused(true);
    await controller.flushPersistence();
    expect(repository.games.values.single.whiteTimeMs, 298766);
    now += 3600000;
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(gameClockProvider)!.whiteMs, 298766);
    expect(container.read(gameClockProvider)!.runningSide, isNull);
    expect(await controller.restoreActiveGame(), isTrue);
    controller.setClockPaused(false);
    now += 1000;
    await play('e2e4');
    expect(container.read(gameControllerProvider).whiteTimeMs, 300766);
    expect(container.read(gameControllerProvider).incrementMs, 3000);
    controller.setClockPaused(true);
  });

  testWidgets('flag fall completes and saves the game without another move', (
    tester,
  ) async {
    createGame();
    await controller.startTwoPlayers(
      timeControl: const TimeControl(
        enabled: true,
        minutes: 0,
        incrementSeconds: 1,
      ),
    );
    now = 1000;
    await tester.pump(const Duration(milliseconds: 100));
    await controller.flushPersistence();
    final game = container.read(gameControllerProvider);
    expect(game.isGameOver, isTrue);
    expect(game.result, GameResult.vitoriaPretas);
    expect(game.termination, GameTermination.timeout);
    expect(game.whiteTimeMs, 0);
    expect(container.read(gameClockProvider)!.runningSide, isNull);
    expect(repository.games.values.single.status, StoredGameStatus.completed);
    expect(
      repository.games.values.single.pgn,
      contains('[Termination "time forfeit"]'),
    );
    await play('e2e4');
    expect(container.read(gameControllerProvider).sanHistory, isEmpty);
  });

  testWidgets(
    'a move after the deadline cannot rescue the clock between ticks',
    (tester) async {
      createGame();
      await controller.startTwoPlayers(
        timeControl: const TimeControl(
          enabled: true,
          minutes: 0,
          incrementSeconds: 2,
        ),
      );
      now = 2001;
      await play('e2e4');
      await controller.flushPersistence();
      expect(container.read(gameControllerProvider).sanHistory, isEmpty);
      expect(
        container.read(gameControllerProvider).termination,
        GameTermination.timeout,
      );
    },
  );

  testWidgets(
    'zero minutes starts with one increment and reset keeps the control',
    (tester) async {
      createGame();
      await controller.startTwoPlayers(
        timeControl: const TimeControl(
          enabled: true,
          minutes: 0,
          incrementSeconds: 90,
        ),
      );
      expect(container.read(gameControllerProvider).whiteTimeMs, 90000);
      now = 1000;
      await play('e2e4');
      expect(container.read(gameControllerProvider).whiteTimeMs, 179000);
      await controller.reset();
      expect(container.read(gameControllerProvider).whiteTimeMs, 90000);
      expect(container.read(gameControllerProvider).initialTimeMs, 0);
      expect(container.read(gameControllerProvider).incrementMs, 90000);
      controller.setClockPaused(true);
    },
  );

  testWidgets('undo switches the running side without refunding elapsed time', (
    tester,
  ) async {
    createGame();
    await controller.startTwoPlayers(
      timeControl: const TimeControl(enabled: true, minutes: 1),
    );
    now = 1000;
    await play('e2e4');
    now = 3000;
    await controller.undo();
    expect(container.read(gameControllerProvider).whiteTimeMs, 59000);
    expect(container.read(gameControllerProvider).blackTimeMs, 58000);
    expect(container.read(gameClockProvider)!.runningSide, Side.white);
    now = 4000;
    await play('d2d4');
    expect(container.read(gameControllerProvider).whiteTimeMs, 58000);
    controller.setClockPaused(true);
  });

  testWidgets(
    'checkmate stops the timer and switching to unlimited clears it',
    (tester) async {
      createGame();
      await controller.startTwoPlayers(
        timeControl: const TimeControl(enabled: true, minutes: 1),
      );
      for (final move in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
        await play(move);
      }
      expect(
        container.read(gameControllerProvider).termination,
        GameTermination.checkmate,
      );
      expect(container.read(gameClockProvider)!.runningSide, isNull);
      now = 100000;
      await tester.pump(const Duration(seconds: 1));
      expect(
        container.read(gameControllerProvider).termination,
        GameTermination.checkmate,
      );
      await controller.startTwoPlayers();
      expect(container.read(gameClockProvider), isNull);
      expect(container.read(gameControllerProvider).whiteTimeMs, isNull);
    },
  );

  test('timeout is a draw when the opponent cannot mate', () {
    createGame();
    final game = GameState(
      position: Chess.fromSetup(Setup.parseFen('7k/8/8/8/8/8/R7/K7 w - - 0 1')),
      positionHistory: const [],
      sanHistory: const [],
      uciHistory: const [],
      moveActorHistory: const [],
      moveTimeHistoryUtc: const [],
      clockEnabled: true,
      whiteTimeMs: 0,
      blackTimeMs: 1000,
    );
    expect(game.termination, GameTermination.timeout);
    expect(game.result, GameResult.empate);
  });

  test('rejects a zero clock before replacing the current game', () async {
    createGame();
    await controller.startTwoPlayers();
    final game = container.read(gameControllerProvider);
    await expectLater(
      controller.startTwoPlayers(
        timeControl: const TimeControl(enabled: true, minutes: 0),
      ),
      throwsArgumentError,
    );
    expect(container.read(gameControllerProvider), same(game));
  });

  testWidgets('engine errors and retry loading do not consume clock time', (
    tester,
  ) async {
    createGame();
    container.dispose();
    final ready = Completer<void>();
    final replacement = _LoadingMaia(ready.future);
    var attempts = 0;
    container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repository),
        clockNowMsProvider.overrideWithValue(() => now),
        maiaModelResolverProvider.overrideWithValue(() async => 'model.onnx'),
        maiaEngineFactoryProvider.overrideWithValue(
          () => attempts++ == 0
              ? FakeMaiaEngine(
                  onMove: (_, _) async => throw StateError('inference failed'),
                )
              : replacement,
        ),
      ],
    );
    controller = container.read(gameControllerProvider.notifier);
    await controller.startVsAi(
      humanSide: Side.white,
      levelRating: 1100,
      timeControl: const TimeControl(
        enabled: true,
        minutes: 1,
        incrementSeconds: 2,
      ),
    );
    await play('e2e4');
    expect(container.read(gameControllerProvider).engineError, isNotNull);
    expect(container.read(gameClockProvider)!.runningSide, isNull);
    now += 120000;
    final retry = controller.retryAiMove();
    await tester.pump();
    now += 60000;
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(gameClockProvider)!.blackMs, 60000);
    expect(container.read(gameClockProvider)!.runningSide, isNull);
    ready.complete();
    await tester.pump();
    await retry;
    expect(container.read(gameControllerProvider).uciHistory, ['e2e4', 'e7e5']);
    expect(container.read(gameControllerProvider).blackTimeMs, 62000);
    controller.setClockPaused(true);
  });

  testWidgets('an engine reply after flag fall cannot change the result', (
    tester,
  ) async {
    createGame();
    container.dispose();
    final answer = Completer<String>();
    final maia = FakeMaiaEngine(onMove: (_, _) => answer.future);
    container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repository),
        clockNowMsProvider.overrideWithValue(() => now),
        maiaEngineFactoryProvider.overrideWithValue(() => maia),
        maiaModelResolverProvider.overrideWithValue(() async => 'model.onnx'),
      ],
    );
    controller = container.read(gameControllerProvider.notifier);
    await controller.startVsAi(
      humanSide: Side.white,
      levelRating: 1100,
      timeControl: const TimeControl(
        enabled: true,
        minutes: 0,
        incrementSeconds: 1,
      ),
    );
    final move = play('e2e4');
    await tester.pump();
    now = 1100;
    await tester.pump(const Duration(milliseconds: 1100));
    expect(
      container.read(gameControllerProvider).result,
      GameResult.vitoriaBrancas,
    );
    answer.complete('e7e5');
    await move;
    await controller.flushPersistence();
    expect(container.read(gameControllerProvider).uciHistory, ['e2e4']);
    expect(repository.games.values.single.result, StoredGameResult.whiteWin);
  });
}

class _LoadingMaia extends FakeMaiaEngine {
  _LoadingMaia(this.ready) : super(onMove: (_, _) async => 'e7e5');
  final Future<void> ready;
  @override
  Future<void> init(String modelPath) async {
    await ready;
    await super.init(modelPath);
  }
}
