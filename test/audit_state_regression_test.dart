import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/drift_game_repository.dart';
import 'package:maia_chess/data/repositories/drift_stats_repository.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';
import 'game_controller_test.dart' show FakeGameRepository, FakeMaiaEngine;
import 'support_game_settings.dart';

class PauseStats extends d.QueryInterceptor {
  bool armed = false;
  final read = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    d.QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(sql, args);
    if (armed && sql.contains('FROM "games"') && sql.contains('"evaluated"')) {
      armed = false;
      read.complete();
      await release.future;
    }
    return rows;
  }
}

StoredGame game(String id) => StoredGame(
  id: id,
  startedAtUtc: DateTime.utc(2026),
  lastModifiedAtUtc: DateTime.utc(2026),
  status: StoredGameStatus.ongoing,
  result: StoredGameResult.ongoing,
  evaluated: true,
  campaignMode: true,
  levelRating: 600,
  playerSide: Side.white,
  initialFen: Chess.initial.fen,
  currentFen: Chess.initial.fen,
  moves: const [],
);
void main() {
  test('statistics reads one consistent transaction', () async {
    final gate = PauseStats();
    final db = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(gate),
    );
    addTearDown(db.close);
    final games = DriftGameRepository(db);
    final first = game('first');
    await games.beginGame(first);
    await games.completeGame(
      first.copyWith(
        status: StoredGameStatus.completed,
        result: StoredGameResult.whiteWin,
        endedAtUtc: DateTime.utc(2026),
      ),
    );
    final second = game('second');
    await games.beginGame(second);
    gate.armed = true;
    final reading = DriftStatsRepository(db).get();
    await gate.read.future.timeout(const Duration(seconds: 5));
    final completion = games.completeGame(
      second.copyWith(
        status: StoredGameStatus.completed,
        result: StoredGameResult.blackWin,
        endedAtUtc: DateTime.utc(2026, 1, 2),
      ),
    );
    gate.release.complete();
    final result = await reading;
    expect(result.evaluatedGames, 1);
    expect(result.ratingHistory.length, 1);
    await completion;
  });
  testWidgets('current position follows Maia replies in open history', (
    tester,
  ) async {
    final reply = Completer<String>();
    final settings = MemorySettings();
    addTearDown(settings.close);
    final c = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
        maiaEngineFactoryProvider.overrideWithValue(
          () => FakeMaiaEngine(onMove: (_, _) => reply.future),
        ),
        maiaModelResolverProvider.overrideWithValue(() async => 'test.onnx'),
        stockfishWarmupEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(c.dispose);
    final ctl = c.read(gameControllerProvider.notifier);
    await ctl.startVsAi(humanSide: Side.white, levelRating: 600);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 850);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final moving = ctl.attemptDragMove(
      Square.e2,
      Square.e4,
      onPromotion: () async => null,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('move-list-panel')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Position 1 of 1'), findsOneWidget);
    reply.complete('e7e5');
    await tester.pump(const Duration(seconds: 2));
    await moving;
    await tester.pumpAndSettle();
    expect(c.read(gameControllerProvider).uciHistory, ['e2e4', 'e7e5']);
    await tester.tap(find.text('Current position'));
    await tester.pumpAndSettle();
    expect(find.text('Position 2 of 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
