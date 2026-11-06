import 'dart:convert';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/engine_ffi/maia_engine/maia_encoding.dart';

import 'fixtures/maia3_reference.dart';

void main() {
  final reference = jsonDecode(maia3ReferenceJson) as Map<String, dynamic>;
  for (final fixture
      in (reference['cases'] as List).cast<Map<String, dynamic>>()) {
    test('official encoding and legal vocabulary: ${fixture['name']}', () {
      final positions = (fixture['fens'] as List)
          .map((fen) => Chess.fromSetup(Setup.parseFen(fen as String)))
          .toList();
      final tokens = MaiaEncoding.tokens(positions);
      expect([
        for (var i = 0; i < tokens.length; i++)
          if (tokens[i] != 0) i,
      ], fixture['tokenOnes']);
      final legal = MaiaEncoding.legalMoves(positions.last);
      expect(legal.keys.toList(), fixture['legalIndices']);
      expect(legal.values.toList(), fixture['legalMoves']);
    });
  }
  test('sampling only returns legal moves despite illegal policy peaks', () {
    final logits = List<double>.filled(4352, 1000);
    final legal = MaiaEncoding.legalMoves(Chess.initial);
    for (final index in legal.keys) {
      logits[index] = -1000;
    }
    final random = Random(42);
    final seen = <String>{};
    for (var i = 0; i < 100; i++) {
      final move = MaiaEncoding.sample(logits, Chess.initial, random);
      expect(legal.values, contains(move));
      seen.add(move);
    }
    expect(seen.length, greaterThan(1));
    expect(() => MaiaEncoding.probabilities([0], [0]), throwsStateError);
    logits[legal.keys.first] = double.nan;
    expect(
      () => MaiaEncoding.probabilities(logits, legal.keys),
      throwsStateError,
    );
  });
}
