import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/repositories/drift_game_repository.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'support_sql_counter.dart';

void main() {
  for (final retroactive in [false, true]) {
    test(
      'incremental projections match full rebuild, retroactive=$retroactive',
      () async {
        final counter = SqlCounter();
        final db = AppDatabase.forTesting(
          NativeDatabase.memory().interceptWith(counter),
        );
        addTearDown(db.close);
        final repository = DriftGameRepository(db);
        Future<Object> projection() async => [
          (await db.select(db.ratingHistory).get())
              .map((r) => [r.gameId, r.rating, r.recordedAtUtc])
              .toList(),
          (await db.select(db.difficultyProgress).get())
              .map((r) => [r.rating, r.validWins, r.windowGames, r.unlocked])
              .toList(),
        ];
        for (var i = 0; i < 16; i++) {
          final date = DateTime.utc(2026, 1, retroactive ? 20 - i : i + 1);
          final game = StoredGame(
            id: 'g$i',
            startedAtUtc: date,
            lastModifiedAtUtc: date,
            status: StoredGameStatus.ongoing,
            result: StoredGameResult.ongoing,
            evaluated: true,
            campaignMode: true,
            levelRating: i < 8 ? 600 : 800,
            playerSide: Side.white,
            initialFen: Chess.initial.fen,
            currentFen: Chess.initial.fen,
            moves: const [],
          );
          await repository.beginGame(game);
          counter.reset();
          await repository.completeGame(
            game.copyWith(
              status: StoredGameStatus.completed,
              result: i % 3 == 0
                  ? StoredGameResult.blackWin
                  : StoredGameResult.whiteWin,
              endedAtUtc: date,
            ),
          );
          if (!retroactive) {
            expect(
              counter.deletes,
              isEmpty,
              reason: 'Appending must not delete prior rating points',
            );
          }
          final incremental = await projection();
          await db.rebuildDerivedState();
          expect(await projection(), incremental);
        }
        await repository.deleteGame('g5');
        final deleted = await projection();
        await db.rebuildDerivedState();
        expect(await projection(), deleted);
      },
    );
  }
}
