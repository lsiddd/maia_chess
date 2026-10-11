import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_state.dart';

void main() {
  test(
    'construtor e copyWith isolam listas mutáveis fornecidas pelo chamador',
    () {
      final positions = <Chess>[];
      final sans = <String>[];
      final ucis = <String>[];
      final actors = <GameMoveActor>[];
      final times = <DateTime>[];
      final state = GameState(
        position: Chess.initial,
        positionHistory: positions,
        sanHistory: sans,
        uciHistory: ucis,
        moveActorHistory: actors,
        moveTimeHistoryUtc: times,
      );
      final copied = state.copyWith(
        positionHistory: positions,
        sanHistory: sans,
        uciHistory: ucis,
        moveActorHistory: actors,
        moveTimeHistoryUtc: times,
      );
      positions.add(Chess.initial);
      sans.add('e4');
      ucis.add('e2e4');
      actors.add(GameMoveActor.player);
      times.add(DateTime.utc(2026));
      for (final snapshot in [state, copied]) {
        expect(snapshot.positionHistory, isEmpty);
        expect(snapshot.sanHistory, isEmpty);
        expect(snapshot.uciHistory, isEmpty);
        expect(snapshot.moveActorHistory, isEmpty);
        expect(snapshot.moveTimeHistoryUtc, isEmpty);
        expect(() => snapshot.sanHistory.add('e4'), throwsUnsupportedError);
      }
    },
  );

  test(
    'seleção reutiliza históricos imutáveis e preserva fatos da partida',
    () {
      final state = GameState.initial();
      expect(state.isGameOver, isFalse);
      final selected = state.copyWith(
        selectedSquare: Square.e2,
        evaluated: false,
      );
      expect(selected.positionHistory, same(state.positionHistory));
      expect(selected.sanHistory, same(state.sanHistory));
      expect(selected.uciHistory, same(state.uciHistory));
      expect(selected.moveActorHistory, same(state.moveActorHistory));
      expect(selected.moveTimeHistoryUtc, same(state.moveTimeHistoryUtc));
      expect(selected.isGameOver, isFalse);
      expect(selected.selectedSquare, Square.e2);
    },
  );

  test('mudanças de posição ou histórico invalidam término e repetição', () {
    final initial = GameState.initial();
    expect(initial.isGameOver, isFalse);
    expect(initial.isDrawByThreefoldRepetition, isFalse);
    final repeated = initial.copyWith(
      positionHistory: [Chess.initial, Chess.initial],
      sanHistory: ['Nf3', 'Ng1'],
      uciHistory: ['g1f3', 'f3g1'],
      moveActorHistory: [GameMoveActor.player, GameMoveActor.player],
      moveTimeHistoryUtc: [DateTime.utc(2026), DateTime.utc(2026)],
    );
    expect(repeated.isGameOver, isTrue);
    expect(repeated.isDrawByThreefoldRepetition, isTrue);
    final undone = repeated.copyWith(
      positionHistory: [],
      sanHistory: [],
      uciHistory: [],
      moveActorHistory: [],
      moveTimeHistoryUtc: [],
    );
    expect(undone.isGameOver, isFalse);
    expect(undone.isDrawByThreefoldRepetition, isFalse);
    final mated = initial.copyWith(
      position: Chess.fromSetup(
        Setup.parseFen('7k/6Q1/5K2/8/8/8/8/8 b - - 0 1'),
      ),
    );
    expect(mated.isGameOver, isTrue);
    expect(mated.result, GameResult.vitoriaBrancas);
  });
}
