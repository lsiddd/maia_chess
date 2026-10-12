import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/repositories/drift_game_repository.dart';
import 'package:maia_chess/features/history/domain/game_replayer.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';

import 'support_sql_counter.dart';

void main() {
  for (final count in [3, 20, 1100]) {
    test(
      'library with $count games uses two queries and preserves moves',
      () async {
        final counter = SqlCounter();
        final database = AppDatabase.forTesting(
          NativeDatabase.memory().interceptWith(counter),
        );
        addTearDown(database.close);
        final repository = DriftGameRepository(database);
        // Batch fixtures keep setup fast and exercise libraries beyond SQLite's
        // traditional 999-parameter limit.
        final imported = const PgnService().parseImport(
          pgn: '1. e4 e5 2. Nf3 *',
          id: 'fixture',
          importedAtUtc: DateTime.utc(2026, 10, 11),
        );
        await database.batch((batch) {
          for (var i = 0; i < count; i++) {
            final id = 'game-$i';
            final date = imported.startedAtUtc.add(Duration(seconds: i));
            batch.insert(
              database.games,
              GamesCompanion.insert(
                id: id,
                startedAtUtc: date,
                lastModifiedAtUtc: date,
                initialFen: imported.initialFen,
                currentFen: imported.currentFen,
              ),
            );
            batch.insertAll(
              database.gameMoves,
              imported.moves
                  .map(
                    (move) => GameMovesCompanion.insert(
                      gameId: id,
                      ply: move.ply,
                      uci: move.uci,
                      san: move.san,
                      fenAfter: move.fenAfter,
                      actor: move.actor.name,
                      playedAtUtc: date,
                    ),
                  )
                  .toList(),
            );
          }
        });
        counter.reset();
        final library = await repository.watchLibrary().first;
        expect(counter.selects, hasLength(2));
        expect(library, hasLength(count));
        expect(library.first.id, 'game-${count - 1}');
        expect(library.last.id, 'game-0');
        for (final game in library) {
          expect(game.moves.map((move) => move.uci), ['e2e4', 'e7e5', 'g1f3']);
          expect(
            const GameReplayer().replay(game).positions.last.fen,
            imported.currentFen,
          );
        }
      },
    );
  }

  test('empty library does not query moves', () async {
    final counter = SqlCounter();
    final database = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(counter),
    );
    addTearDown(database.close);
    await database.select(database.games).get();
    counter.reset();
    expect(await DriftGameRepository(database).watchLibrary().first, isEmpty);
    expect(counter.selects, hasLength(1));
  });
}
