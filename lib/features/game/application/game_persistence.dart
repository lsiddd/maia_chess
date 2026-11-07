import '../../../data/repositories/game_repository.dart';
import '../../pgn/application/pgn_service.dart';
import 'game_state.dart';

/// Serializes immutable session snapshots and owns ordered, recoverable I/O.
class GamePersistence {
  GamePersistence(this.repository);
  final GameRepository Function() repository;
  Future<void> _tail = Future.value();
  Future<void> flush() => _tail;

  Future<void> save(StoredGame snapshot) => enqueue(() async {
    if (snapshot.status == StoredGameStatus.completed) {
      snapshot = snapshot.copyWith(
        pgn: await const PgnService().exportAsync(snapshot),
      );
      await repository().completeGame(snapshot);
    } else {
      await repository().saveOngoing(snapshot);
    }
  });

  StoredGame snapshot(
    GameState snapshotState, {
    required StoredGameStatus status,
    required StoredGameResult result,
    GameTermination? termination,
  }) {
    final id = snapshotState.gameId;
    final startedAt = snapshotState.startedAtUtc;
    if (id == null || startedAt == null) {
      throw StateError('The game does not yet have a persistent ID.');
    }
    final now = DateTime.now().toUtc();
    final moves = <StoredGameMove>[];
    for (var index = 0; index < snapshotState.sanHistory.length; index++) {
      final fenAfter = index + 1 < snapshotState.positionHistory.length
          ? snapshotState.positionHistory[index + 1].fen
          : snapshotState.position.fen;
      moves.add(
        StoredGameMove(
          ply: index + 1,
          uci: snapshotState.uciHistory[index],
          san: snapshotState.sanHistory[index],
          fenAfter: fenAfter,
          actor: snapshotState.moveActorHistory[index],
          playedAtUtc: snapshotState.moveTimeHistoryUtc[index].toUtc(),
        ),
      );
    }
    return StoredGame(
      id: id,
      startedAtUtc: startedAt.toUtc(),
      endedAtUtc: status == StoredGameStatus.completed ? now : null,
      lastModifiedAtUtc: now,
      status: status,
      levelRating: snapshotState.levelRating,
      playerSide: snapshotState.aiSide?.opposite,
      result: result,
      termination: termination,
      evaluated: snapshotState.evaluated,
      campaignMode: snapshotState.campaignMode,
      initialFen: snapshotState.positionHistory.isEmpty
          ? snapshotState.position.fen
          : snapshotState.positionHistory.first.fen,
      currentFen: snapshotState.position.fen,
      clockEnabled: snapshotState.clockEnabled,
      initialTimeMs: snapshotState.initialTimeMs,
      incrementMs: snapshotState.incrementMs,
      whiteTimeMs: snapshotState.whiteTimeMs,
      blackTimeMs: snapshotState.blackTimeMs,
      moves: List.unmodifiable(moves),
    );
  }

  Future<void> enqueue(Future<void> Function() action) {
    final operation = _tail.then(
      (_) => action(),
      onError: (Object _, StackTrace stackTrace) => action(),
    );
    _tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace stackTrace) {},
    );
    return operation;
  }
}
