import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../data/repositories/game_repository.dart';
import '../../pgn/application/pgn_service.dart';
import 'game_review.dart';

Future<String> exportReviewedPgnAsync(StoredGame game, GameReview review) {
  if (game.moves.length < 128 && (game.pgn?.length ?? 0) < 65536) {
    return Future.value(exportReviewedPgn(game, review));
  }
  return compute(_exportReviewed, (game, review));
}

String _exportReviewed((StoredGame, GameReview) input) =>
    exportReviewedPgn(input.$1, input.$2);

/// Annotate a copy of the original PGN, preserving imported notes and branches.
String exportReviewedPgn(StoredGame game, GameReview review) {
  final pgn = PgnGame.parsePgn(game.pgn ?? const PgnService().export(game));
  var parent = pgn.moves;
  for (final move in review.moves) {
    final played = parent.children.firstOrNull;
    if (played == null || game.moves[move.ply - 1].san != move.san) {
      throw const FormatException('The reviewed moves do not match the game.');
    }
    final best = move.before.lines.firstOrNull;
    final evaluation = move.after.evaluation;
    final score = evaluation.mate == null
        ? evaluation.centipawns == null
              ? ''
              : '[%eval ${(evaluation.centipawns! / 100).toStringAsFixed(2)}] '
        : '[%eval #${evaluation.mate}] ';
    played.data.comments = [
      ...?played.data.comments,
      '$score${move.quality.label}.'
          '${move.quality.isMistake && best != null ? ' Stockfish preferred ${best.sans.first}.' : ''}',
    ];
    if (move.quality.isMistake &&
        best != null &&
        best.sans.first != played.data.san) {
      _mergeLine(parent, best.sans);
    }
    parent = played;
  }
  return pgn.makePgn();
}

void _mergeLine(PgnNode<PgnNodeData> parent, List<String> moves) {
  for (final san in moves) {
    final existing = parent.children.where((node) => node.data.san == san);
    if (existing.isNotEmpty) {
      parent = existing.first;
    } else {
      final child = PgnChildNode(PgnNodeData(san: san));
      parent.children.add(child);
      parent = child;
    }
  }
}
