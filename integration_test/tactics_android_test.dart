import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_service.dart';
import 'package:maia_chess/features/tactics/domain/tactical_analysis.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stockfish nativo: MultiPV dos dois lados e retorno à dica', (
    tester,
  ) async {
    final engine = StockfishService();
    try {
      await engine.init();
      for (final original in [
        Chess.initial,
        Chess.initial.playUnchecked(NormalMove.fromUci('e2e4')),
      ]) {
        final position = opponentThreatPosition(
          Chess.fromSetup(Setup.parseFen(original.fen)),
        );
        final result = ThreatResult.fromLines(
          position,
          await engine.getTopMoves(position.fen),
        );
        expect(result.threats, hasLength(3));
        expect(result.threats.map((t) => t.line.rank), [1, 2, 3]);
        expect(result.threats.map((t) => t.line.depth).toSet(), hasLength(1));
        for (final threat in result.threats) {
          expect(position.isLegal(threat.move), isTrue);
          expect(threat.san, isNotEmpty);
        }
      }
      final hint = await engine.getBestMove(Chess.initial.fen);
      expect(Chess.initial.isLegal(Move.parse(hint)!), isTrue);
      // Fewer than three legal moves is normal and must not hang MultiPV.
      final constrained = Chess.fromSetup(
        Setup.parseFen('8/8/8/8/8/8/r1k5/K7 w - - 0 1'),
      );
      final lines = await engine.getTopMoves(constrained.fen);
      expect(lines, hasLength(1));
      expect(
        constrained.isLegal(Move.parse(lines.single.moves.first)!),
        isTrue,
      );
    } finally {
      await engine.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
