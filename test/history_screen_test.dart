import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/presentation/chess_board_widget.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/history/presentation/history_screen.dart';

void main() {
  testWidgets('biblioteca lista e reproduz uma partida salva', (tester) async {
    final game = _savedGame();
    final repository = _SingleGameRepository(game);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLibraryProvider.overrideWith((ref) => Stream.value([game])),
          gameRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Partida local — empate'), findsOneWidget);
    await tester.tap(find.textContaining('Partida local — empate'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Lance 0 de 2'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Lance 0 de 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Próximo'));
    await tester.pump();
    expect(find.text('1. e4'), findsOneWidget);
    String boardFen() => tester
        .widget<StaticChessBoardWidget>(find.byType(StaticChessBoardWidget))
        .position
        .fen;
    expect(boardFen(), game.moves.first.fenAfter);
    await tester.tap(find.byTooltip('Final'));
    await tester.pumpAndSettle();
    expect(find.text('Lance 2 de 2'), findsOneWidget);
    expect(boardFen(), game.currentFen);
    await tester.tap(find.byTooltip('Anterior'));
    await tester.pumpAndSettle();
    expect(boardFen(), game.moves.first.fenAfter);
    await tester.tap(find.byTooltip('Início'));
    await tester.pumpAndSettle();
    expect(find.text('Lance 0 de 2'), findsOneWidget);
    expect(boardFen(), game.initialFen);
  });
}

StoredGame _savedGame() {
  var position = Chess.initial;
  final moves = <StoredGameMove>[];
  for (final (index, uci) in ['e2e4', 'e7e5'].indexed) {
    final move = Move.parse(uci)!;
    final (after, san) = position.makeSan(move);
    position = after as Chess;
    moves.add(
      StoredGameMove(
        ply: index + 1,
        uci: uci,
        san: san,
        fenAfter: position.fen,
        actor: GameMoveActor.player,
        playedAtUtc: DateTime.utc(2026, 8, 5, 12, index),
      ),
    );
  }
  return StoredGame(
    id: 'history',
    startedAtUtc: DateTime.utc(2026, 8, 5),
    endedAtUtc: DateTime.utc(2026, 8, 5, 1),
    lastModifiedAtUtc: DateTime.utc(2026, 8, 5, 1),
    status: StoredGameStatus.completed,
    result: StoredGameResult.draw,
    termination: GameTermination.unknown,
    evaluated: true,
    campaignMode: false,
    initialFen: Chess.initial.fen,
    currentFen: position.fen,
    moves: moves,
  );
}

class _SingleGameRepository implements GameRepository {
  _SingleGameRepository(this.game);

  StoredGame? game;

  @override
  Future<StoredGame?> getGame(String id) async => game?.id == id ? game : null;

  @override
  Future<void> deleteGame(String id) async {
    if (game?.id == id) game = null;
  }

  @override
  Stream<List<StoredGame>> watchLibrary() => Stream.value([?game]);

  @override
  Stream<StoredGame?> watchActiveGame() => Stream.value(null);

  @override
  Future<StoredGame?> getActiveGame() async => null;

  @override
  Future<void> beginGame(StoredGame game) async => this.game = game;

  @override
  Future<bool> completeGame(StoredGame game) async {
    this.game = game;
    return true;
  }

  @override
  Future<void> importGame(StoredGame game) async => this.game = game;

  @override
  Future<void> saveOngoing(StoredGame game) async => this.game = game;
}
