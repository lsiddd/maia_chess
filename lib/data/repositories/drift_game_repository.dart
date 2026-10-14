import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart';

import '../local/app_database.dart';
import 'game_repository.dart';

class DriftGameRepository implements GameRepository {
  DriftGameRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<StoredGame>> watchLibrary({int? limit, int offset = 0}) {
    if (offset < 0 ||
        (limit == null && offset != 0) ||
        (limit != null && (limit < 1 || limit > 500))) {
      throw ArgumentError('Invalid library page bounds.');
    }
    return _watchSnapshot(
      () => _db.transaction(() async {
        final query = _db.select(_db.games)
          ..orderBy([
            (row) => OrderingTerm.desc(row.lastModifiedAtUtc),
            (row) => OrderingTerm.desc(row.id),
          ]);
        if (limit != null) query.limit(limit, offset: offset);
        final rows = await query.get();
        return _hydrateLibrary(rows, limited: limit != null);
      }),
    );
  }

  @override
  Stream<StoredGame?> watchActiveGame() {
    return _watchSnapshot(getActiveGame);
  }

  @override
  Future<StoredGame?> getActiveGame() => _db.transaction(() async {
    final query = _db.select(_db.games)
      ..where((row) => row.status.equals(StoredGameStatus.ongoing.name))
      ..orderBy([(row) => OrderingTerm.desc(row.lastModifiedAtUtc)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _hydrate(row);
  });

  @override
  Future<StoredGame?> getGame(String id) => _db.transaction(() async {
    final row = await (_db.select(
      _db.games,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _hydrate(row);
  });

  Stream<T> _watchSnapshot<T>(Future<T> Function() read) {
    // Subscribe before the initial read so a concurrent commit is not missed.
    final changes = Stream<void>.multi((events) {
      final subscription = _db
          .tableUpdates(TableUpdateQuery.onAllTables([_db.games, _db.gameMoves]))
          .listen(
            (_) => events.add(null),
            onError: events.addError,
            onDone: events.close,
          );
      events.onCancel = subscription.cancel;
      events.onPause = subscription.pause;
      events.onResume = subscription.resume;
      events.add(null);
    });
    return changes.asyncMap((_) => read());
  }

  @override
  Future<void> beginGame(StoredGame game, {bool Function()? canCommit}) {
    _requireOngoing(game);
    return _db.transaction(() async {
      final activeIds =
          await (_db.selectOnly(_db.games)
                ..addColumns([_db.games.id])
                ..where(_db.games.status.equals(StoredGameStatus.ongoing.name)))
              .map((row) => row.read(_db.games.id)!)
              .get();
      if (activeIds.isNotEmpty) {
        await (_db.delete(
          _db.games,
        )..where((row) => row.id.isIn(activeIds))).go();
      }
      await _insertSnapshot(game);
      if (canCommit != null && !canCommit()) {
        throw const GameStartCancelledException();
      }
    });
  }

  @override
  Future<void> saveOngoing(StoredGame game) {
    _requireOngoing(game);
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.games,
      )..where((row) => row.id.equals(game.id))).getSingleOrNull();
      if (existing == null) {
        throw StateError('Autosave not found: ${game.id}');
      }
      if (existing.status != StoredGameStatus.ongoing.name) {
        throw StateError('A completed game cannot be overwritten.');
      }
      await _replaceSnapshot(game);
    });
  }

  @override
  Future<bool> completeGame(StoredGame game) {
    if (game.status != StoredGameStatus.completed) {
      throw ArgumentError('The game must be completed.');
    }
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.games,
      )..where((row) => row.id.equals(game.id))).getSingleOrNull();
      if (existing == null) {
        throw StateError('Autosave not found: ${game.id}');
      }
      if (existing.status == StoredGameStatus.completed.name) {
        return false;
      }

      await _replaceSnapshot(game);
      await _db.rebuildDerivedState();
      return true;
    });
  }

  @override
  Future<void> importGame(StoredGame game) {
    if (game.status != StoredGameStatus.completed) {
      throw ArgumentError(
        'An imported PGN must be archived as a completed game.',
      );
    }
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.games,
      )..where((row) => row.id.equals(game.id))).getSingleOrNull();
      if (existing != null) {
        throw StateError('A game with ID ${game.id} already exists.');
      }
      await _insertSnapshot(game);
    });
  }

  @override
  Future<void> deleteGame(String id) {
    return _db.transaction(() async {
      await (_db.delete(_db.games)..where((row) => row.id.equals(id))).go();
      await _db.rebuildDerivedState();
    });
  }

  Future<StoredGame> _hydrate(GameRow row) async {
    final moveQuery = _db.select(_db.gameMoves)
      ..where((move) => move.gameId.equals(row.id))
      ..orderBy([(move) => OrderingTerm.asc(move.ply)]);
    final moves = await moveQuery.get();
    return _fromRows(row, moves);
  }

  Future<List<StoredGame>> _hydrateLibrary(
    List<GameRow> rows, {
    required bool limited,
  }) async {
    if (rows.isEmpty) return const [];
    final query = _db.select(_db.gameMoves);
    // Bounded pages fit SQLite's bind limit. The legacy full-library read
    // avoids an unbounded IN clause and still uses two SELECTs.
    if (limited) {
      query.where((move) => move.gameId.isIn(rows.map((row) => row.id)));
    }
    final moves =
        await (query..orderBy([
              (move) => OrderingTerm.asc(move.gameId),
              (move) => OrderingTerm.asc(move.ply),
            ]))
            .get();
    final byGame = <String, List<GameMoveRow>>{};
    for (final move in moves) {
      (byGame[move.gameId] ??= []).add(move);
    }
    return rows
        .map((row) => _fromRows(row, byGame[row.id] ?? const []))
        .toList(growable: false);
  }

  StoredGame _fromRows(GameRow row, List<GameMoveRow> moves) {
    return StoredGame(
      id: row.id,
      startedAtUtc: row.startedAtUtc.toUtc(),
      endedAtUtc: row.endedAtUtc?.toUtc(),
      lastModifiedAtUtc: row.lastModifiedAtUtc.toUtc(),
      status: _enumByName(StoredGameStatus.values, row.status, 'status'),
      levelRating: row.levelRating,
      playerSide: row.playerSide == null
          ? null
          : _enumByName(Side.values, row.playerSide!, 'playerSide'),
      result: _enumByName(StoredGameResult.values, row.result, 'result'),
      termination: row.termination == null
          ? null
          : _enumByName(
              GameTermination.values,
              row.termination!,
              'termination',
            ),
      evaluated: row.evaluated,
      campaignMode: row.campaignMode,
      initialFen: row.initialFen,
      currentFen: row.currentFen,
      pgn: row.pgn,
      clockEnabled: row.clockEnabled,
      initialTimeMs: row.initialTimeMs,
      whiteTimeMs: row.whiteTimeMs,
      blackTimeMs: row.blackTimeMs,
      moves: moves
          .map(
            (move) => StoredGameMove(
              ply: move.ply,
              uci: move.uci,
              san: move.san,
              fenAfter: move.fenAfter,
              actor: _enumByName(GameMoveActor.values, move.actor, 'actor'),
              playedAtUtc: move.playedAtUtc.toUtc(),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _insertSnapshot(StoredGame game) async {
    await _db.into(_db.games).insert(_gameCompanion(game));
    await _insertMoves(game);
  }

  Future<void> _replaceSnapshot(StoredGame game) async {
    final changed = await (_db.update(
      _db.games,
    )..where((row) => row.id.equals(game.id))).write(_gameCompanion(game));
    if (changed != 1) {
      throw StateError('Failed to update game ${game.id}.');
    }
    final existing =
        await (_db.select(_db.gameMoves)
              ..where((row) => row.gameId.equals(game.id))
              ..orderBy([(row) => OrderingTerm.asc(row.ply)]))
            .get();
    var common = 0;
    while (common < existing.length &&
        common < game.moves.length &&
        _sameMove(existing[common], game.moves[common])) {
      common++;
    }
    // Preserve the unchanged prefix, including row identity. Undo deletes
    // only the old suffix; append and metadata-only saves delete nothing.
    if (common < existing.length) {
      await (_db.delete(_db.gameMoves)..where(
            (row) =>
                row.gameId.equals(game.id) &
                row.ply.isBiggerOrEqualValue(existing[common].ply),
          ))
          .go();
    }
    await _insertMoves(game, startIndex: common);
  }

  bool _sameMove(GameMoveRow saved, StoredGameMove incoming) =>
      saved.ply == incoming.ply &&
      saved.uci == incoming.uci &&
      saved.san == incoming.san &&
      saved.fenAfter == incoming.fenAfter &&
      saved.actor == incoming.actor.name &&
      // Compare at the database's actual timestamp precision. SQLite's
      // default DateTime storage truncates subsecond values.
      _db.typeMapping.mapToSqlVariable(saved.playedAtUtc.toUtc()) ==
          _db.typeMapping.mapToSqlVariable(incoming.playedAtUtc.toUtc());

  Future<void> _insertMoves(StoredGame game, {int startIndex = 0}) async {
    if (startIndex == game.moves.length) return;
    await _db.batch((batch) {
      batch.insertAll(
        _db.gameMoves,
        game.moves
            .skip(startIndex)
            .map(
              (move) => GameMovesCompanion.insert(
                gameId: game.id,
                ply: move.ply,
                uci: move.uci,
                san: move.san,
                fenAfter: move.fenAfter,
                actor: move.actor.name,
                playedAtUtc: move.playedAtUtc.toUtc(),
              ),
            )
            .toList(growable: false),
      );
    });
  }

  GamesCompanion _gameCompanion(StoredGame game) {
    return GamesCompanion(
      id: Value(game.id),
      startedAtUtc: Value(game.startedAtUtc.toUtc()),
      endedAtUtc: Value(game.endedAtUtc?.toUtc()),
      lastModifiedAtUtc: Value(game.lastModifiedAtUtc.toUtc()),
      status: Value(game.status.name),
      levelRating: Value(game.levelRating),
      playerSide: Value(game.playerSide?.name),
      result: Value(game.result.name),
      termination: Value(game.termination?.name),
      evaluated: Value(game.evaluated),
      campaignMode: Value(game.campaignMode),
      initialFen: Value(game.initialFen),
      currentFen: Value(game.currentFen),
      pgn: Value(game.pgn),
      clockEnabled: Value(game.clockEnabled),
      initialTimeMs: Value(game.initialTimeMs),
      whiteTimeMs: Value(game.whiteTimeMs),
      blackTimeMs: Value(game.blackTimeMs),
    );
  }

  void _requireOngoing(StoredGame game) {
    if (game.status != StoredGameStatus.ongoing) {
      throw ArgumentError('The autosave must be ongoing.');
    }
  }
}

T _enumByName<T extends Enum>(Iterable<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Invalid stored value for $field: "$name"');
}
