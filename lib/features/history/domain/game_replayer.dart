import 'package:dartchess/dartchess.dart';

import '../../../data/repositories/game_repository.dart';

class ReplayedGame {
  const ReplayedGame({
    required this.positions,
    required this.sans,
    required this.ucis,
  });

  final List<Chess> positions;
  final List<String> sans;
  final List<String> ucis;
}

class GameReplayException implements Exception {
  const GameReplayException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GameReplayer {
  const GameReplayer();

  ReplayedGame replay(StoredGame game) {
    late Chess position;
    try {
      position = Chess.fromSetup(Setup.parseFen(game.initialFen));
    } catch (error) {
      throw GameReplayException('FEN inicial persistida é inválida: $error');
    }

    final positions = <Chess>[position];
    final sans = <String>[];
    final ucis = <String>[];
    for (var index = 0; index < game.moves.length; index++) {
      final stored = game.moves[index];
      if (stored.ply != index + 1) {
        throw GameReplayException(
          'Sequência de lances corrompida na jogada ${index + 1}.',
        );
      }
      final move = Move.parse(stored.uci);
      if (move == null || !position.isLegal(move)) {
        throw GameReplayException(
          'Lance UCI inválido na jogada ${index + 1}: "${stored.uci}".',
        );
      }
      final (after, canonicalSan) = position.makeSan(move);
      if (canonicalSan != stored.san) {
        throw GameReplayException(
          'SAN divergente na jogada ${index + 1}: '
          'salvo "${stored.san}", esperado "$canonicalSan".',
        );
      }
      position = after as Chess;
      if (position.fen != stored.fenAfter) {
        throw GameReplayException('FEN divergente após a jogada ${index + 1}.');
      }
      positions.add(position);
      sans.add(canonicalSan);
      ucis.add(stored.uci);
    }
    if (position.fen != game.currentFen) {
      throw const GameReplayException(
        'A FEN final não confere com a sequência persistida.',
      );
    }
    return ReplayedGame(
      positions: List.unmodifiable(positions),
      sans: List.unmodifiable(sans),
      ucis: List.unmodifiable(ucis),
    );
  }
}
