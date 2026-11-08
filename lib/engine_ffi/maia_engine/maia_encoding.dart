import 'dart:math';
import 'dart:typed_data';

import 'package:dartchess/dartchess.dart';

import '../../features/game/application/chess_move_rules.dart';

/// Maia-3's square tokens and policy vocabulary. Mirrors CSSLab/maia3 at
/// 1e13597c42d4858b7cfd7cfdae01e297263364b2; see assets/maia3/NOTICE.md.
abstract final class MaiaEncoding {
  static const historyLength = 8;
  static const policySize = 4352;
  static const _roles = [
    Role.pawn,
    Role.knight,
    Role.bishop,
    Role.rook,
    Role.queen,
    Role.king,
  ];
  static const _promotions = [Role.queen, Role.rook, Role.bishop, Role.knight];

  /// Chronological positions, including the current one. Each snapshot uses
  /// its own side-to-move perspective, as in upstream get_historical_tokens.
  static Float32List tokens(List<Chess> positions) {
    if (positions.isEmpty) throw ArgumentError('Position history is empty');
    final history = positions
        .skip(max(0, positions.length - historyLength))
        .toList();
    final tokens = Float32List(64 * 96);
    for (var frame = 0; frame < historyLength; frame++) {
      final board = history[max(0, frame - (historyLength - history.length))];
      final black = board.turn == Side.black;
      for (var square = 0; square < 64; square++) {
        final piece = board.board.pieceAt(Square(square));
        if (piece == null) continue;
        final oriented = black ? square ^ 56 : square;
        final role = _roles.indexOf(piece.role);
        final channel = role + (piece.color == board.turn ? 0 : 6);
        tokens[oriented * 96 + frame * 12 + channel] = 1;
      }
    }
    return tokens;
  }

  static int index(NormalMove move, Side turn) {
    final from = turn == Side.black ? move.from.value ^ 56 : move.from.value;
    final to = turn == Side.black ? move.to.value ^ 56 : move.to.value;
    if (move.promotion == null) return from * 64 + to;
    final promotion = _promotions.indexOf(move.promotion!);
    if (promotion < 0 || from ~/ 8 != 6 || to ~/ 8 != 7) {
      throw ArgumentError('Invalid promotion for Maia-3: ${move.uci}');
    }
    return 4096 + ((from % 8) * 8 + to % 8) * 4 + promotion;
  }

  /// Use standard king destinations for castling, not dartchess's Chess960
  /// king-to-rook representation. Include all four legal promotions.
  static Map<int, String> legalMoves(Chess position) {
    final movesByIndex = <int, String>{};
    for (var square = 0; square < 64; square++) {
      final from = Square(square);
      final piece = position.board.pieceAt(from);
      if (piece == null || piece.color != position.turn) continue;
      for (final to in legalChessDestinations(position, from)) {
        final promotions =
            piece.role == Role.pawn &&
                (to.rank == Rank.first || to.rank == Rank.eighth)
            ? _promotions
            : <Role?>[null];
        for (final promotion in promotions) {
          final move = NormalMove(from: from, to: to, promotion: promotion);
          movesByIndex[index(move, position.turn)] = move.uci;
        }
      }
    }
    return Map.fromEntries(
      movesByIndex.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  /// Legal-move softmax, temperature 1 and top-p 1 (official defaults).
  static List<double> probabilities(
    List<double> logits,
    Iterable<int> indices,
  ) {
    if (logits.length != policySize) {
      throw StateError('Invalid Maia-3 policy shape');
    }
    final selected = indices.map((index) => logits[index]).toList();
    if (selected.isEmpty) throw StateError('Position has no legal moves');
    if (selected.any((value) => !value.isFinite)) {
      throw StateError('Non-finite Maia-3 policy');
    }
    final peak = selected.reduce(max);
    final weights = selected.map((value) => exp(value - peak)).toList();
    final total = weights.reduce((a, b) => a + b);
    return weights.map((value) => value / total).toList();
  }

  static String sample(List<double> logits, Chess position, Random random) {
    final legal = legalMoves(position);
    final probabilities = MaiaEncoding.probabilities(logits, legal.keys);
    var remaining = random.nextDouble();
    final moves = legal.values.toList();
    for (var i = 0; i < moves.length; i++) {
      remaining -= probabilities[i];
      if (remaining < 0) return moves[i];
    }
    return moves.last;
  }
}
