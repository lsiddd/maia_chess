import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart';

import '../local/app_database.dart';
import 'game_repository.dart';

class DriftGameRepository implements GameRepository {
  DriftGameRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<StoredGame>> watchLibrary() {
    final query = _db.select(_db.games)
      ..orderBy([(row) => OrderingTerm.desc(row.lastModifiedAtUtc)]);
    return query.watch().asyncMap((rows) => Future.wait(rows.map(_hydrate)));
  }

  @override
  Stream<StoredGame?> watchActiveGame() {
    final query = _db.select(_db.games)
      ..where((row) => row.status.equals(StoredGameStatus.ongoing.name))
      ..orderBy([(row) => OrderingTerm.desc(row.lastModifiedAtUtc)])
      ..limit(1);
    return query.watchSingleOrNull().asyncMap(
      (row) => row == null ? null : _hydrate(row),
    );
  }

  @override
  Future<StoredGame?> getActiveGame() async {
    final query = _db.select(_db.games)
      ..where((row) => row.status.equals(StoredGameStatus.ongoing.name))
      ..orderBy([(row) => OrderingTerm.desc(row.lastModifiedAtUtc)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<StoredGame?> getGame(String id) async {
    final row = await (_db.select(
      _db.games,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<void> beginGame(StoredGame game) {
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
        throw StateError('Autosave inexistente: ${game.id}');
      }
      if (existing.status != StoredGameStatus.ongoing.name) {
        throw StateError('Não é permitido sobrescrever partida finalizada.');
      }
      await _replaceSnapshot(game);
    });
  }

  @override
  Future<bool> completeGame(StoredGame game) {
    if (game.status != StoredGameStatus.completed) {
      throw ArgumentError('A partida deve estar finalizada.');
    }
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.games,
      )..where((row) => row.id.equals(game.id))).getSingleOrNull();
      if (existing == null) {
        throw StateError('Autosave inexistente: ${game.id}');
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
      throw ArgumentError('PGN importado deve ser arquivado como finalizado.');
    }
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.games,
      )..where((row) => row.id.equals(game.id))).getSingleOrNull();
      if (existing != null) {
        throw StateError('Já existe uma partida com o ID ${game.id}.');
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
      throw StateError('Falha ao atualizar a partida ${game.id}.');
    }
    await (_db.delete(
      _db.gameMoves,
    )..where((row) => row.gameId.equals(game.id))).go();
    await _insertMoves(game);
  }

  Future<void> _insertMoves(StoredGame game) async {
    if (game.moves.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAll(
        _db.gameMoves,
        game.moves
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
      throw ArgumentError('O autosave deve estar em andamento.');
    }
  }
}

T _enumByName<T extends Enum>(Iterable<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Valor persistido inválido para $field: "$name"');
}
