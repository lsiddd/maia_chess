import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/features/game/application/game_controller.dart';
import 'package:maia_chess/features/game/application/game_state.dart';
import 'package:maia_chess/features/game/presentation/game_screen.dart';

class _EndedGame extends GameController {
  _EndedGame(this.fen);
  final String fen;
  @override
  GameState build() =>
      super.build().copyWith(position: Chess.fromSetup(Setup.parseFen(fen)));
}

void main() {
  for (final example in [
    (
      fen: '7k/6Q1/5K2/8/8/8/8/8 b - - 0 1',
      label: 'Xeque-mate! Brancas vencem.',
    ),
    (fen: '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1', label: 'Empate por afogamento.'),
    (
      fen: '7k/8/6K1/8/8/8/8/8 w - - 0 1',
      label: 'Empate por material insuficiente.',
    ),
    (
      fen: '7k/8/6K1/8/8/8/8/R7 w - - 100 80',
      label: 'Empate pela regra dos 50 lances.',
    ),
    (
      fen: '7k/6Q1/5K2/8/8/8/8/8 b - - 100 80',
      label: 'Xeque-mate! Brancas vencem.',
    ),
  ]) {
    testWidgets('resultado persistente: ${example.label}', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith(() => _EndedGame(example.fen)),
          ],
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(example.label), findsOneWidget);
      expect(find.text('Sua vez de escolher um lance'), findsNothing);
      expect(find.text('Brancas jogam'), findsNothing);
      expect(find.text('Pretas jogam'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
