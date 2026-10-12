import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/presentation/chess_board_widget.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/history/presentation/history_screen.dart';

void main() {
  testWidgets('library lists and replays a saved game', (tester) async {
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

    expect(find.textContaining('Local game — draw'), findsOneWidget);
    await tester.tap(find.textContaining('Local game — draw'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Move 0 of 2'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Move 0 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    expect(find.text('1. e4'), findsOneWidget);
    String boardFen() => tester
        .widget<StaticChessBoardWidget>(find.byType(StaticChessBoardWidget))
        .position
        .fen;
    expect(boardFen(), game.moves.first.fenAfter);
    await tester.tap(find.byTooltip('End'));
    await tester.pumpAndSettle();
    expect(find.text('Move 2 of 2'), findsOneWidget);
    expect(boardFen(), game.currentFen);
    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();
    expect(boardFen(), game.moves.first.fenAfter);
    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Move 0 of 2'), findsOneWidget);
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
