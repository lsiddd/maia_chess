import 'dart:io' as io;

import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/difficulty/presentation/campaign_screen.dart';
import 'package:maia_chess/features/stats/presentation/stats_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android real: Fase 5 persiste, desbloqueia, renderiza e reconstrói',
    (tester) async {
      final temporaryDirectory = await getTemporaryDirectory();
      final databaseFile = io.File(
        '${temporaryDirectory.path}/phase_5_android_test.sqlite',
      );
      if (await databaseFile.exists()) await databaseFile.delete();

      final database = AppDatabase.forTesting(
        NativeDatabase.createInBackground(databaseFile),
      );
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      final games = container.read(gameRepositoryProvider);
      final stats = container.read(statsRepositoryProvider);
      final progress = container.read(progressRepositoryProvider);

      try {
        final first = _campaignGame(
          id: 'phase5-device-win-1',
          hour: 12,
          result: StoredGameResult.whiteWin,
        );
        await games.beginGame(first.ongoing);
        expect(await games.completeGame(first.completed), isTrue);
        expect(
          await games.completeGame(first.completed),
          isFalse,
          reason: 'Concluir novamente não pode duplicar as projeções.',
        );

        var snapshot = await stats.get();
        var levels = await progress.getAll();
        expect(snapshot.evaluatedGames, 1);
        expect(snapshot.ratingHistory, hasLength(1));
        expect(levels.first.validWins, 1);
        expect(levels.first.gamesInWindow, 1);
        expect(levels[1].unlocked, isFalse);

        final second = _campaignGame(
          id: 'phase5-device-loss',
          hour: 13,
          result: StoredGameResult.blackWin,
        );
        final third = _campaignGame(
          id: 'phase5-device-win-2',
          hour: 14,
          result: StoredGameResult.whiteWin,
        );
        await games.beginGame(second.ongoing);
        expect(await games.completeGame(second.completed), isTrue);
        await games.beginGame(third.ongoing);
        expect(await games.completeGame(third.completed), isTrue);

        snapshot = await stats.get();
        levels = await progress.getAll();
        expect(snapshot.evaluatedGames, 3);
        expect(snapshot.ratingHistory, hasLength(3));
        expect(snapshot.resultsByLevel[1100]?.wins, 2);
        expect(snapshot.resultsByLevel[1100]?.losses, 1);
        expect(levels.first.levelCompleted, isTrue);
        expect(levels.first.gamesInWindow, 3);
        expect(levels[1].unlocked, isTrue);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: CampaignScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('A escalada dos nove Maias'), findsOneWidget);
        expect(find.text('Etapa concluída'), findsOneWidget);
        expect(find.text('Jogar novamente'), findsOneWidget);
        expect(find.text('Maia 1200'), findsOneWidget);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StatsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('3 partidas avaliadas'), findsOneWidget);
        expect(find.text('Sequência atual'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp(r'Gráfico de evolução com 3 pontos; rating atual'),
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('2V  0E  1D'),
          250,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('2V  0E  1D'), findsOneWidget);

        await games.deleteGame(third.ongoing.id);
        snapshot = await stats.get();
        levels = await progress.getAll();
        expect(snapshot.evaluatedGames, 2);
        expect(snapshot.ratingHistory, hasLength(2));
        expect(snapshot.resultsByLevel[1100]?.wins, 1);
        expect(snapshot.resultsByLevel[1100]?.losses, 1);
        expect(levels.first.validWins, 1);
        expect(levels.first.gamesInWindow, 2);
        expect(levels[1].unlocked, isFalse);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: CampaignScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1/2 vitórias • 2/3 partidas'), findsOneWidget);
        expect(find.text('Bloqueado'), findsWidgets);

        await games.deleteGame(first.ongoing.id);
        await games.deleteGame(second.ongoing.id);
        snapshot = await stats.get();
        levels = await progress.getAll();
        expect(snapshot.evaluatedGames, 0);
        expect(snapshot.ratingHistory, isEmpty);
        expect(levels.first.validWins, 0);
        expect(levels.first.gamesInWindow, 0);
        expect(levels.first.unlocked, isTrue);
        expect(levels.skip(1).every((level) => !level.unlocked), isTrue);
        expect(await database.select(database.ratingHistory).get(), isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await database.close();
        if (await databaseFile.exists()) await databaseFile.delete();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

({StoredGame ongoing, StoredGame completed}) _campaignGame({
  required String id,
  required int hour,
  required StoredGameResult result,
}) {
  final startedAt = DateTime.utc(2026, 8, 6, hour);
  final ongoing = StoredGame(
    id: id,
    startedAtUtc: startedAt,
    lastModifiedAtUtc: startedAt,
    status: StoredGameStatus.ongoing,
    levelRating: 1100,
    playerSide: Side.white,
    result: StoredGameResult.ongoing,
    evaluated: true,
    campaignMode: true,
    initialFen: Chess.initial.fen,
    currentFen: Chess.initial.fen,
    moves: const [],
  );
  return (
    ongoing: ongoing,
    completed: ongoing.copyWith(
      endedAtUtc: startedAt.add(const Duration(minutes: 20)),
      lastModifiedAtUtc: startedAt.add(const Duration(minutes: 20)),
      status: StoredGameStatus.completed,
      result: result,
      termination: GameTermination.checkmate,
    ),
  );
}
