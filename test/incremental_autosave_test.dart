import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/local/app_database.dart';
import 'package:maia_chess/data/repositories/drift_game_repository.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/history/domain/game_replayer.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';

import 'support_sql_counter.dart';

void main() {
  late SqlCounter counter;
  late AppDatabase database;
  late DriftGameRepository repository;
  setUp(() {
    counter = SqlCounter();
    database = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(counter),
    );
    repository = DriftGameRepository(database);
  });
  tearDown(() => database.close());

  test(
    'identical snapshot and eligibility change do not rewrite moves',
    () async {
      final game = _game('1. e4 e5 *');
      await repository.beginGame(game);
      counter.reset();
      await repository.saveOngoing(game);
      await repository.saveOngoing(game.copyWith(evaluated: false));
      expect(counter.deletes, isEmpty);
      expect(counter.batchRows, 0);
      expect((await repository.getActiveGame())!.evaluated, isFalse);
    },
  );

  test('a new move inserts only one row', () async {
    await repository.beginGame(_game('1. e4 e5 *'));
    counter.reset();
    await repository.saveOngoing(_game('1. e4 e5 2. Nf3 *'));
    expect(counter.deletes, isEmpty);
    expect(counter.batchRows, 1);
    final stored = (await repository.getActiveGame())!;
    expect(stored.moves.map((move) => move.uci), ['e2e4', 'e7e5', 'g1f3']);
    expect(const GameReplayer().replay(stored).positions, hasLength(4));
  });

  test(
    'undo removes only the suffix and allows a different continuation',
    () async {
      await repository.beginGame(_game('1. e4 e5 2. Nf3 *'));
      counter.reset();
      await repository.saveOngoing(_game('1. e4 *'));
      expect(counter.deletes, hasLength(1));
      expect(counter.batchRows, 0);
      counter.reset();
      await repository.saveOngoing(_game('1. e4 d5 *'));
      expect(counter.deletes, isEmpty);
      expect(counter.batchRows, 1);
      expect((await repository.getActiveGame())!.moves.last.uci, 'd7d5');
    },
  );

  test(
    'suffix insertion failure rolls back FEN and moves in the same transaction',
    () async {
      final original = _game('1. e4 e5 *');
      await repository.beginGame(original);
      await database.customStatement('''
      CREATE TRIGGER fail_suffix BEFORE INSERT ON game_moves
      WHEN NEW.uci = 'd7d5'
      BEGIN SELECT RAISE(ABORT, 'injected write failure'); END
    ''');
      await expectLater(
        repository.saveOngoing(_game('1. e4 d5 *')),
        throwsA(isA<Exception>()),
      );
      final stored = (await repository.getActiveGame())!;
      expect(stored.currentFen, original.currentFen);
      expect(stored.moves.map((move) => move.uci), ['e2e4', 'e7e5']);
      expect(
        const GameReplayer().replay(stored).positions.last.fen,
        original.currentFen,
      );
    },
  );

  test('move actor and timestamp changes are also persisted', () async {
    final game = _game('1. e4 e5 *');
    await repository.beginGame(game);
    final last = game.moves.last;
    final changed = StoredGameMove(
      ply: last.ply,
      uci: last.uci,
      san: last.san,
      fenAfter: last.fenAfter,
      actor: GameMoveActor.player,
      playedAtUtc: last.playedAtUtc.add(const Duration(seconds: 2)),
    );
    counter.reset();
    await repository.saveOngoing(
      game.copyWith(moves: [game.moves.first, changed]),
    );
    expect(counter.batchRows, 1);
    final stored = (await repository.getActiveGame())!.moves.last;
    expect(stored.actor, changed.actor);
    expect(
      stored.playedAtUtc.millisecondsSinceEpoch ~/ 1000,
      changed.playedAtUtc.millisecondsSinceEpoch ~/ 1000,
    );
  });
}

StoredGame _game(String pgn) => const PgnService()
    .parseImport(
      pgn: pgn,
      id: 'autosave',
      importedAtUtc: DateTime.utc(2026, 10, 11, 12, 0, 0, 456),
    )
    .copyWith(
      status: StoredGameStatus.ongoing,
      result: StoredGameResult.ongoing,
    );
