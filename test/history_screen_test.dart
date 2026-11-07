import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/core/theming/app_theme.dart';
import 'package:maia_chess/data/providers.dart';
import 'package:maia_chess/features/game/presentation/chess_board_widget.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/features/history/presentation/history_screen.dart';

void main() {
  testWidgets('empty library offers import without redundant pagination', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLibraryProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Import PGN'), findsOneWidget);
    expect(find.text('Page 1'), findsNothing);
  });

  testWidgets('pagination appears only when needed and opens the next page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLibraryProvider.overrideWith(
            (ref) => Stream.value(
              ref.watch(gameLibraryPageProvider) == 0
                  ? List.filled(gameLibraryPageSize + 1, _savedGame())
                  : [_savedGame()],
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.textContaining('Local game — draw'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();
    expect(find.text('Page 1'), findsOneWidget);
  });

  testWidgets('replay failure retains navigation and can be retried', (
    tester,
  ) async {
    final repository = _SingleGameRepository(_savedGame())..failRead = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ReplayScreen(gameId: 'history'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('This game could not be opened.'), findsOneWidget);
    repository.failRead = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Move 0 of 2'), findsOneWidget);
    expect(find.byType(StaticChessBoardWidget), findsOneWidget);
  });

  testWidgets(
    'replay controls stay visible with enlarged text on a small screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameRepositoryProvider.overrideWithValue(
              _SingleGameRepository(_savedGame()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const ReplayScreen(gameId: 'history'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text('1. e4'), findsOneWidget);
      final next = tester.getRect(find.byTooltip('Next'));
      expect(next.bottom, lessThanOrEqualTo(480));
      expect(next.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    },
  );

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

    expect(find.text('Move 0 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    await tester.ensureVisible(find.text('1. e4'));
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

  testWidgets('completed replays offer review and campaign autosaves do not', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 850);
    addTearDown(tester.view.reset);

    for (final ongoing in [false, true]) {
      final game = _savedGame(ongoing: ongoing);
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(ongoing),
          overrides: [
            gameRepositoryProvider.overrideWithValue(
              _SingleGameRepository(game),
            ),
          ],
          child: MaterialApp(home: ReplayScreen(gameId: game.id)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Review game'),
        ongoing ? findsNothing : findsOneWidget,
      );
    }
  });
}

StoredGame _savedGame({bool ongoing = false}) {
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
    endedAtUtc: ongoing ? null : DateTime.utc(2026, 8, 5, 1),
    lastModifiedAtUtc: DateTime.utc(2026, 8, 5, 1),
    status: ongoing ? StoredGameStatus.ongoing : StoredGameStatus.completed,
    result: ongoing ? StoredGameResult.ongoing : StoredGameResult.draw,
    termination: ongoing ? null : GameTermination.unknown,
    evaluated: true,
    campaignMode: ongoing,
    initialFen: Chess.initial.fen,
    currentFen: position.fen,
    moves: moves,
  );
}

class _SingleGameRepository implements GameRepository {
  _SingleGameRepository(this.game);

  StoredGame? game;
  bool failRead = false;

  @override
  Future<StoredGame?> getGame(String id) async {
    if (failRead) throw StateError('Temporary read failure');
    return game?.id == id ? game : null;
  }

  @override
  Future<void> deleteGame(String id) async {
    if (game?.id == id) game = null;
  }

  @override
  Stream<List<StoredGame>> watchLibrary({int? limit, int offset = 0}) =>
      Stream.value(offset == 0 ? [?game] : []);

  @override
  Stream<StoredGame?> watchActiveGame() => Stream.value(null);

  @override
  Future<StoredGame?> getActiveGame() async => null;

  @override
  Future<void> beginGame(StoredGame game, {bool Function()? canCommit}) async {
    if (canCommit != null && !canCommit()) {
      throw const GameStartCancelledException();
    }
    this.game = game;
  }

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
