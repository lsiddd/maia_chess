import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/drift_game_repository.dart';
import 'package:maia_chess/data/repositories/drift_progress_repository.dart';
import 'package:maia_chess/data/repositories/drift_stats_repository.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_clock.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_state.dart';
import 'package:maia_chess/features/game/application/time_control.dart';
import 'package:maia_chess/features/game/presentation/board_accessibility.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

import 'game_controller_test.dart'
    show FakeGameRepository, FakeMaiaEngine, FakeStockfishEngine;
import 'support_game_settings.dart';
import 'package:maia_chess/features/hints/application/visual_hint_controller.dart';

void main() {
  late ProviderContainer container;
  late GameController controller;
  late FakeGameRepository repository;
  var now = 0;

  void createGame({
    FakeMaiaEngine? maia,
    FakeStockfishEngine? stockfish,
    GameRepository? persistence,
  }) {
    final settings = MemorySettings();
    addTearDown(settings.close);
    repository = FakeGameRepository();
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        if (stockfish != null)
          stockfishEngineFactoryProvider.overrideWithValue(() => stockfish),
        gameRepositoryProvider.overrideWithValue(persistence ?? repository),
        clockNowMsProvider.overrideWithValue(() => now),
        maiaEngineFactoryProvider.overrideWithValue(
          () => maia ?? FakeMaiaEngine(onMove: (_, _) async => 'e2e4'),
        ),
        maiaModelResolverProvider.overrideWithValue(() async => 'test.onnx'),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
      ],
    );
    controller = container.read(gameControllerProvider.notifier);
    addTearDown(container.dispose);
  }

  Future<void> play(String uci) {
    final move = NormalMove.fromUci(uci);
    return controller.attemptDragMove(
      move.from,
      move.to,
      onPromotion: () async => null,
    );
  }

  for (final side in Side.values) {
    test(
      'local $side resignation saves the opponent win and blocks play',
      () async {
        createGame();
        await controller.startTwoPlayers();
        if (side == Side.black) await play('e2e4');
        final before = container.read(gameControllerProvider);
        expect(before.isGameOver, isFalse); // Prime the memoized state.
        await controller.resign();
        final game = container.read(gameControllerProvider);
        expect(game.resignedSide, side);
        expect(game.isGameOver, isTrue);
        expect(game.canUndo, isFalse);
        expect(game.position, same(before.position));
        expect(
          game.result,
          side == Side.white
              ? GameResult.vitoriaPretas
              : GameResult.vitoriaBrancas,
        );
        final stored = repository.games.values.single;
        expect(stored.status, StoredGameStatus.completed);
        expect(stored.termination, GameTermination.resignation);
        expect(stored.endedAtUtc, isNotNull);
        expect(
          stored.pgn,
          contains('[Result "${side == Side.white ? '0-1' : '1-0'}"]'),
        );
        expect(stored.pgn, contains('[TerminationDetails "resignation"]'));
        expect(await repository.getActiveGame(), isNull);
        await controller.resign();
        await controller.undo();
        await play(side == Side.white ? 'e2e4' : 'e7e5');
        expect(
          container.read(gameControllerProvider).uciHistory,
          before.uciHistory,
        );
        expect(gameResultDescription(game), contains('resigned'));
        await controller.startTwoPlayers();
        expect(container.read(gameControllerProvider).isGameOver, isFalse);
        expect(container.read(gameControllerProvider).resignedSide, isNull);
      },
    );
  }

  test(
    'human can resign during Maia search; its late reply is discarded',
    () async {
      final reply = Completer<String>();
      final requested = Completer<void>();
      final maia = FakeMaiaEngine(
        onMove: (_, _) {
          requested.complete();
          return reply.future;
        },
      );
      createGame(maia: maia);
      await controller.startVsAi(humanSide: Side.white, levelRating: 600);
      final move = play('e2e4');
      await requested.future;
      expect(container.read(gameControllerProvider).aiThinking, isTrue);
      await controller.resign();
      expect(container.read(gameControllerProvider).resignedSide, Side.white);
      expect(container.read(gameControllerProvider).aiThinking, isFalse);
      expect(maia.cancelCount, 1);
      reply.complete('e7e5');
      await move;
      expect(container.read(gameControllerProvider).uciHistory, ['e2e4']);
      expect(repository.games.values.single.result, StoredGameResult.blackWin);
    },
  );

  test('Black can resign against Maia on the human turn', () async {
    createGame();
    await controller.startVsAi(humanSide: Side.black, levelRating: 600);
    await controller.resign();
    expect(container.read(gameControllerProvider).resignedSide, Side.black);
    expect(repository.games.values.single.result, StoredGameResult.whiteWin);
  });

  testWidgets('resignation freezes exact clock balances', (tester) async {
    now = 0;
    createGame();
    await controller.startTwoPlayers(
      timeControl: const TimeControl(enabled: true, minutes: 1),
    );
    now = 1500;
    await controller.resign();
    expect(container.read(gameClockProvider)!.whiteMs, 58500);
    expect(container.read(gameClockProvider)!.runningSide, isNull);
    now = 90000;
    await tester.pump(const Duration(seconds: 2));
    expect(
      container.read(gameControllerProvider).termination,
      GameTermination.resignation,
    );
    expect(repository.games.values.single.whiteTimeMs, 58500);
  });

  testWidgets('an expired clock takes precedence over resignation', (
    tester,
  ) async {
    now = 0;
    createGame();
    await controller.startTwoPlayers(
      timeControl: const TimeControl(enabled: true, minutes: 1),
    );
    now = 60001;
    await controller.resign();
    await controller.flushPersistence();
    expect(container.read(gameControllerProvider).resignedSide, isNull);
    expect(repository.games.values.single.termination, GameTermination.timeout);
  });

  test(
    'resignation cancels a pending hint and keeps the game unrated',
    () async {
      final reply = Completer<String>();
      final requested = Completer<void>();
      createGame(
        stockfish: FakeStockfishEngine(
          onMove: (_, _) {
            requested.complete();
            return reply.future;
          },
        ),
      );
      await controller.startTwoPlayers();
      final hint = controller.getHint();
      final cancelled = expectLater(
        hint,
        throwsA(isA<HintCancelledException>()),
      );
      await requested.future;
      await controller.resign();
      await cancelled;
      reply.complete('e2e4');
      expect(container.read(gameControllerProvider).hintThinking, isFalse);
      expect(repository.games.values.single.evaluated, isFalse);
    },
  );

  test('resignation clears an already displayed hint', () async {
    createGame(stockfish: FakeStockfishEngine(onMove: (_, _) async => 'e2e4'));
    await controller.startTwoPlayers();
    final subscription = container.listen(visualHintProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(visualHintProvider.notifier).toggle();
    expect(container.read(visualHintProvider), Square.e2);
    await controller.resign();
    expect(container.read(visualHintProvider), isNull);
  });

  test('a failed save keeps the resignation and can be retried', () async {
    final failing = _FailingCompletionRepository();
    createGame(persistence: failing);
    await controller.startTwoPlayers();
    await controller.resign();
    expect(container.read(gameControllerProvider).isGameOver, isTrue);
    expect(
      container.read(gameControllerProvider).persistenceError,
      contains('Autosave failed'),
    );
    failing.fail = false;
    await controller.saveGame();
    expect(container.read(gameControllerProvider).persistenceError, isNull);
    expect(
      failing.games.values.single.termination,
      GameTermination.resignation,
    );
    expect(failing.games.values.single.result, StoredGameResult.blackWin);
  });

  test('resignation draws when the opponent has only a king', () {
    final game = GameState.initial().copyWith(
      position: Chess.fromSetup(Setup.parseFen('7k/8/8/8/8/8/P7/K7 w - - 0 1')),
      resignedSide: Side.white,
    );
    expect(game.result, GameResult.empate);
    expect(game.termination, GameTermination.resignation);
  });

  test(
    'campaign resignation persists and counts as one loss, even after retry',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final games = DriftGameRepository(database);
      createGame(persistence: games);
      await controller.startVsAi(
        humanSide: Side.white,
        levelRating: 600,
        campaignMode: true,
      );
      await controller.resign();
      await controller.saveGame();
      await controller.resign();
      final stored = await games.getGame(
        container.read(gameControllerProvider).gameId!,
      );
      expect(stored!.termination, GameTermination.resignation);
      expect(stored.result, StoredGameResult.blackWin);
      expect(await games.getActiveGame(), isNull);
      final stats = await DriftStatsRepository(database).get();
      expect(stats.evaluatedGames, 1);
      expect(stats.resultsByLevel[600]!.losses, 1);
      expect(stats.ratingHistory, hasLength(1));
      final progress = (await DriftProgressRepository(database).getAll()).first;
      expect(progress.gamesInWindow, 1);
      expect(progress.validWins, 0);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('resign menu confirms or cancels at ${scale}x text', (
      tester,
    ) async {
      createGame();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      await controller.startTwoPlayers();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const GameScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> openResign() async {
        await tester.ensureVisible(find.text('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Resign'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Resign'));
        await tester.pumpAndSettle();
      }

      await openResign();
      expect(find.text('Resign as White?'), findsOneWidget);
      await tester.tap(find.text('Keep playing'));
      await tester.pumpAndSettle();
      expect(container.read(gameControllerProvider).isGameOver, isFalse);
      await openResign();
      await tester.tap(find.widgetWithText(FilledButton, 'Resign'));
      await tester.pumpAndSettle();
      expect(find.text('White resigned. Black wins.'), findsOneWidget);
      expect(find.byTooltip('Rematch'), findsOneWidget);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Resign'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}

class _FailingCompletionRepository extends FakeGameRepository {
  bool fail = true;

  @override
  Future<bool> completeGame(StoredGame game) {
    if (fail) return Future.error(StateError('Storage unavailable'));
    return super.completeGame(game);
  }
}
