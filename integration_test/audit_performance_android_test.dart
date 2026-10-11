import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/game/application/game_state.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';

// Same fixtures, SDK, device and profile mode must be used before and after.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('profile: seleção, repetição e PGN longo', (tester) async {
    final initial = _gameState();
    final source = _pgn();
    final metrics = <String, Object>{
      'state_plies': initial.uciHistory.length,
      'selection_iterations': 500,
      'pgn_plies': 1000,
      'mode': 'profile',
    };
    final selections = <double>[];
    for (var sample = 0; sample < 6; sample++) {
      var state = initial;
      final watch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        state = state.copyWith(
          selectedSquare: i.isEven ? Square.e2 : Square.d2,
        );
        expect(state.isGameOver, isFalse);
      }
      watch.stop();
      if (sample > 0) selections.add(watch.elapsedMicroseconds / 1000);
    }
    metrics['selection_ms'] = selections;
    final parses = <Map<String, Object>>[];
    for (var sample = 0; sample < 6; sample++) {
      final measurement = await _measure(() async {
        final game = await const PgnService().parseImportAsync(
          pgn: source,
          id: 'profile',
          importedAtUtc: DateTime.utc(2026, 10, 11),
        );
        expect(game.moves.length, 1000);
      });
      if (sample > 0) parses.add(measurement);
    }
    metrics['pgn'] = parses;
    binding.reportData = {'audit_performance': metrics};
  }, skip: !kProfileMode);
}

Future<Map<String, Object>> _measure(Future<void> Function() operation) async {
  final clock = Stopwatch()..start();
  var lastTick = 0;
  var maxGap = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 2), (_) {
    final now = clock.elapsedMicroseconds;
    maxGap = max(maxGap, now - lastTick);
    lastTick = now;
  });
  try {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final work = Stopwatch()..start();
    await operation();
    work.stop();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return {
      'elapsed_ms': work.elapsedMicroseconds / 1000,
      'max_event_loop_gap_ms': maxGap / 1000,
    };
  } finally {
    timer.cancel();
  }
}

String _pgn() {
  final moves = StringBuffer();
  for (var cycle = 0; cycle < 250; cycle++) {
    moves.write('${cycle * 2 + 1}. Nf3 Nf6 ${cycle * 2 + 2}. Ng1 Ng8 ');
  }
  return '$moves*';
}

GameState _gameState() {
  var state = GameState.initial();
  final random = Random(20261011);
  final keys = <String>{state.position.fen.split(' ').take(4).join(' ')};
  for (var ply = 0; ply < 80; ply++) {
    final candidates = <NormalMove>[
      for (final entry in state.position.legalMoves.entries)
        for (final to in entry.value.squares)
          NormalMove(
            from: entry.key,
            to: to,
            promotion: state.isPromotion(entry.key, to) ? Role.queen : null,
          ),
    ]..shuffle(random);
    var found = false;
    for (final move in candidates) {
      final (position, san) = state.position.makeSan(move);
      final after = position as Chess;
      final key = after.fen.split(' ').take(4).join(' ');
      if (after.isGameOver || after.halfmoves >= 100 || keys.contains(key)) {
        continue;
      }
      keys.add(key);
      state = state.copyWith(
        position: after,
        positionHistory: [...state.positionHistory, state.position],
        sanHistory: [...state.sanHistory, san],
        uciHistory: [...state.uciHistory, move.uci],
        moveActorHistory: [...state.moveActorHistory, GameMoveActor.player],
        moveTimeHistoryUtc: [
          ...state.moveTimeHistoryUtc,
          DateTime.utc(2026, 10, 11),
        ],
      );
      found = true;
      break;
    }
    if (!found) throw StateError('No non-terminal fixture move at ply $ply');
  }
  return state;
}
