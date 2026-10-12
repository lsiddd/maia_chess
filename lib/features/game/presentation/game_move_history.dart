import 'dart:math' as math;
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../application/game_state.dart';
import 'chess_board_widget.dart';

class GameMoveHistory extends StatefulWidget {
  const GameMoveHistory({
    super.key,
    required this.game,
    required this.orientation,
  });
  final GameState game;
  final Side orientation;

  @override
  State<GameMoveHistory> createState() => _GameMoveHistoryState();
}

class _GameMoveHistoryState extends State<GameMoveHistory> {
  int? _selectedPly;
  double? _scrollOffset;

  @override
  void didUpdateWidget(covariant GameMoveHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.gameId != widget.game.gameId ||
        oldWidget.game.position.fen != widget.game.position.fen) {
      _selectedPly = null;
      _scrollOffset = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final orientation = widget.orientation;
    final start = math.max(0, ((game.sanHistory.length - 3) ~/ 2) * 2);
    final recent = <String>[];
    for (var i = start; i < game.sanHistory.length; i += 2) {
      recent.add(
        '${i ~/ 2 + 1}. ${game.sanHistory[i]}${i + 1 < game.sanHistory.length ? ' ${game.sanHistory[i + 1]}' : ''}',
      );
    }
    return SizedBox(
      height: 48,
      child: InkWell(
        key: const Key('move-list-panel'),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => SafeArea(
            top: false,
            child: FractionallySizedBox(
              heightFactor: .92,
              child: _HistoryReview(
                game: game,
                orientation: orientation,
                initialPly: _selectedPly,
                initialOffset: _scrollOffset,
                onLeave: (ply, offset) {
                  if (mounted &&
                      widget.game.position.fen == game.position.fen) {
                    _selectedPly = ply;
                    _scrollOffset = offset;
                  }
                },
              ),
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                recent.isEmpty ? 'Moves · No moves yet' : recent.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_less),
          ],
        ),
      ),
    );
  }
}

/// Independent history review that never changes the live game.
class _HistoryReview extends StatefulWidget {
  const _HistoryReview({
    required this.game,
    required this.orientation,
    this.initialPly,
    this.initialOffset,
    required this.onLeave,
  });
  final int? initialPly;
  final double? initialOffset;
  final void Function(int, double) onLeave;
  final GameState game;
  final Side orientation;
  @override
  State<_HistoryReview> createState() => _HistoryReviewState();
}

class _HistoryReviewState extends State<_HistoryReview> {
  late int _ply = widget.initialPly ?? widget.game.sanHistory.length;
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset:
        widget.initialOffset ?? math.max(0, ((_ply + 1) ~/ 2) * 48.0 - 96),
  );
  late double _lastOffset = _scroll.initialScrollOffset;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _lastOffset = _scroll.offset);
  }

  @override
  void dispose() {
    widget.onLeave(_ply, _lastOffset);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final position = _ply == game.sanHistory.length
        ? game.position
        : game.positionHistory[_ply];
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final separateActions =
                constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            final currentPosition = TextButton(
              onPressed: () {
                setState(() => _ply = game.sanHistory.length);
                if (_scroll.hasClients) {
                  _scroll.jumpTo(_scroll.position.maxScrollExtent);
                }
              },
              child: const Text('Current position'),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Moves',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!separateActions) currentPosition,
                      IconButton(
                        tooltip: 'Close history',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (separateActions) currentPosition,
                ],
              ),
            );
          },
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: StaticChessBoardWidget(
              position: position,
              orientation: widget.orientation,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: game.sanHistory.isEmpty
              ? const Center(child: Text('No moves have been played yet.'))
              : ListView.builder(
                  controller: _scroll,
                  itemExtent: 48,
                  itemCount: (game.sanHistory.length + 1) ~/ 2,
                  itemBuilder: (context, row) => Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Center(child: Text('${row + 1}.')),
                      ),
                      for (var side = 0; side < 2; side++)
                        Expanded(
                          child: row * 2 + side >= game.sanHistory.length
                              ? const SizedBox()
                              : TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: _ply == row * 2 + side + 1
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer
                                        : null,
                                  ),
                                  onPressed: () =>
                                      setState(() => _ply = row * 2 + side + 1),
                                  child: Text(game.sanHistory[row * 2 + side]),
                                ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
