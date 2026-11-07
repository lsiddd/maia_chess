import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maia_chess/data/repositories/game_repository.dart';
import 'package:maia_chess/core/theming/app_theme.dart';
import 'package:maia_chess/engine_ffi/stockfish_engine/stockfish_analysis.dart';
import 'package:maia_chess/features/game/presentation/chess_board_widget.dart';
import 'package:maia_chess/features/history/domain/game_replayer.dart';
import 'package:maia_chess/features/pgn/application/pgn_service.dart';
import 'package:maia_chess/features/review/application/game_review_analyzer.dart';
import 'package:maia_chess/features/review/domain/review_pgn.dart';
import 'package:maia_chess/features/review/presentation/game_review_screen.dart';
import 'package:maia_chess/features/review/presentation/review_chart.dart';

void main() {
  final game = const PgnService().parseImport(
    pgn: '1. f3 {Original note} (1. d4 d5) e5 2. g4 Qh4# 0-1',
    id: 'review-fixture',
    importedAtUtc: DateTime.utc(2026),
  );
  final replayed = const GameReplayer().replay(game);
  final analyzer = _analyzer(replayed);

  testWidgets('review shows critical moves, branches and retry on the board', (
    tester,
  ) async {
    await _openReview(tester, game, replayed, analyzer);
    await tester.pumpAndSettle();
    expect(find.byType(ReviewChart), findsOneWidget);
    expect(find.byTooltip('Export annotated PGN'), findsOneWidget);

    // The graph takes us to White's second move without changing the record.
    final graph = tester.getRect(find.byType(ReviewChart));
    await tester.tapAt(Offset(graph.left + graph.width * .75, graph.center.dy));
    await tester.pumpAndSettle();
    expect(_board(tester).position.fen, replayed.positions[3].fen);
    expect(find.text('White played g4 · Blunder'), findsOneWidget);

    final show = find.widgetWithText(TextButton, 'Show continuation');
    await _scrollTo(tester, show);
    await tester.tap(show);
    await tester.pumpAndSettle();
    expect(_board(tester).position.isCheckmate, isTrue);
    await tester.tap(find.widgetWithText(TextButton, 'Return to game'));
    await tester.pumpAndSettle();
    expect(_board(tester).position.fen, replayed.positions[3].fen);

    final retry = find.widgetWithText(TextButton, 'Retry move');
    await _scrollTo(tester, retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byType(ReviewChart), findsNothing);
    expect(_board(tester).position.fen, replayed.positions[2].fen);
    await tester.tap(find.byKey(const ValueKey('review-square-g2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-square-g4')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Try again'), findsOneWidget);
    expect(_board(tester).position.fen, replayed.positions[2].fen);

    await tester.tap(find.byKey(const ValueKey('review-square-e2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-square-e4')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Well played'), findsOneWidget);
    expect(_board(tester).position.board.pieceAt(Square.e4)?.role, Role.pawn);
    await tester.tap(find.byTooltip('Back to review'));
    await tester.pumpAndSettle();
    expect(_board(tester).position.fen, replayed.positions[3].fen);
    expect(game.moves.map((move) => move.uci), replayed.ucis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android back returns from practice and variations to the game', (
    tester,
  ) async {
    await _openReview(tester, game, replayed, analyzer);
    await tester.pumpAndSettle();
    final graph = tester.getRect(find.byType(ReviewChart));
    await tester.tapAt(
      Offset(graph.left + graph.width * .75, graph.bottom - 24),
    );
    await tester.pumpAndSettle();
    final retry = find.widgetWithText(TextButton, 'Retry move');
    await _scrollTo(tester, retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Game review'), findsOneWidget);
    expect(_board(tester).position.fen, replayed.positions[3].fen);
    final show = find.widgetWithText(TextButton, 'Show continuation');
    await _scrollTo(tester, show);
    await tester.tap(show);
    await tester.pumpAndSettle();
    expect(_board(tester).position.isCheckmate, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_board(tester).position.fen, replayed.positions[3].fen);
    expect(find.widgetWithText(TextButton, 'Return to game'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(800, 400)]) {
    testWidgets('review remains usable at $size with enlarged text', (
      tester,
    ) async {
      await _openReview(
        tester,
        game,
        replayed,
        analyzer,
        size: size,
        textScale: 2,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next position'));
      await tester.pumpAndSettle();
      expect(_board(tester).position.fen, replayed.positions[1].fen);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelling a scan allows individual position analysis', (
    tester,
  ) async {
    final firstSearch = Completer<List<StockfishLine>>();
    var searches = 0;
    final slow = GameReviewAnalyzer(({
      required fen,
      required initialFen,
      required moves,
      required count,
      required movetimeMs,
      required ensureActive,
    }) async {
      if (++searches == 1) return firstSearch.future;
      return [
        StockfishLine(rank: 1, depth: 12, moves: ['e2e4'], centipawns: 20),
      ];
    });
    await _openReview(tester, game, replayed, slow);
    final cancel = find.widgetWithText(TextButton, 'Cancel analysis');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    firstSearch.complete([
      StockfishLine(rank: 1, depth: 12, moves: ['e2e4'], centipawns: 90),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(ReviewChart), findsNothing);
    final position = find.widgetWithText(OutlinedButton, 'Analyze position');
    await tester.ensureVisible(position);
    await tester.tap(position);
    await tester.pumpAndSettle();
    expect(find.text('Engine lines'), findsOneWidget);
    expect(find.text('+0.20'), findsWidgets);
    expect(searches, 2);
  });

  test(
    'annotated PGN preserves imported notes, alternatives and mainline',
    () async {
      final review = await analyzer.analyze(replayed, request: ReviewRequest());
      final annotated = exportReviewedPgn(game, review);
      expect(annotated, contains('Original note'));
      expect(annotated, contains('d4 d5'));
      expect(annotated, contains('Blunder. Stockfish preferred e4.'));
      final imported = const PgnService().parseImport(
        pgn: annotated,
        id: 'annotated',
        importedAtUtc: DateTime.utc(2026),
      );
      expect(imported.moves.map((move) => move.san), replayed.sans);
      expect(imported.result, StoredGameResult.blackWin);
    },
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    160,
    scrollable: find
        .descendant(
          of: find.byKey(const PageStorageKey('review-portrait-details')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openReview(
  WidgetTester tester,
  StoredGame game,
  ReplayedGame replayed,
  GameReviewAnalyzer analyzer, {
  Size size = const Size(420, 900),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reviewAnalyzerProvider.overrideWithValue(analyzer)],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: GameReviewScreen(game: game, replayed: replayed),
      ),
    ),
  );
  await tester.pump();
}

StaticChessBoardWidget _board(WidgetTester tester) =>
    tester.widget(find.byType(StaticChessBoardWidget));

GameReviewAnalyzer _analyzer(ReplayedGame replayed) {
  return GameReviewAnalyzer(({
    required fen,
    required initialFen,
    required moves,
    required count,
    required movetimeMs,
    required ensureActive,
  }) async {
    final index = replayed.positions.indexWhere(
      (position) => position.fen == fen,
    );
    final (uci, cp, mate) = switch (index) {
      0 => ('e2e4', 20, null),
      1 => ('e7e5', 100, null),
      2 => ('e2e4', -30, null),
      3 => ('d8h4', null, 1),
      _ => ('g8f6', 0, null),
    };
    return [
      StockfishLine(
        rank: 1,
        depth: 12,
        moves: [uci],
        centipawns: cp,
        mate: mate,
      ),
    ];
  });
}
