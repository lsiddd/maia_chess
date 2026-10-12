import 'dart:async';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theming/app_theme.dart';
import '../../../core/theming/board_theme.dart';
import '../application/game_controller.dart';
import '../application/game_state.dart';
import '../application/move_feedback.dart';
import '../../tactics/domain/tactical_analysis.dart';
import '../../tactics/presentation/threat_arrows.dart';
import 'chess_piece_widget.dart';
import 'promotion_dialog.dart';
import 'board_accessibility.dart';

/// Interactive board supporting taps and drags.
///
/// Board-level gesture recognisers avoid competing drag targets on all 64
/// squares. Moving pieces use local Stack layers rather than the global
/// overlay.
///
/// Read legal destinations from [GameController] and send move intentions
/// back to it; final legality remains in the rules layer.
class ChessBoardWidget extends ConsumerStatefulWidget {
  const ChessBoardWidget({
    super.key,
    this.orientation = Side.white,
    this.showAttackedPieces = false,
    this.threats = const [],
    this.hintSquare,
    this.attackedSide,
  });

  final Square? hintSquare;
  final Side? attackedSide;
  final bool showAttackedPieces;
  final List<OpponentThreat> threats;

  /// Side displayed at the bottom of the board.
  final Side orientation;

  @override
  ConsumerState<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends ConsumerState<ChessBoardWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Chess? _attackPosition;
  Set<Square> _attackedSquares = const {};
  Square? _draggingFrom;
  final _dragPosition = ValueNotifier<Offset?>(null);

  // Square touched before the drag crosses the gesture-recognition threshold.
  Square? _panDownSquare;

  // Keep the release position in cell units so it survives relayout. Accepted
  // moves animate from the finger release point; rejected moves return from
  // it. Consume the pending position once, either in the state listener or
  // after the move attempt.
  Square? _pendingDragReleaseSquare;
  Offset? _pendingDragReleaseFractional;

  // A single controller animates the current piece flight. A new move or
  // grabbing the flying piece interrupts it immediately, so play need not
  // wait for visual completion.
  late final AnimationController _slideController;
  late final Animation<double> _slideCurve;
  Square? _slideFromSquare;
  Offset? _slideFromFractional;
  Square? _slideToSquare;
  Piece? _slidePiece;
  Square? _rookFrom;
  Square? _rookTo;
  Piece? _rookPiece;
  bool _gestureCancelled = false;
  int _interactionGeneration = 0;
  Square? _promotionFrom;
  Square? _promotionTo;
  Piece? _promotionPawn;
  DialogRoute<Role>? _promotionRoute;

  void _dismissPromotion() {
    _promotionFrom = null;
    _promotionTo = null;
    _promotionPawn = null;
    final route = _promotionRoute;
    _promotionRoute = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _slideController = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _slideCurve = CurvedAnimation(
      parent: _slideController,
      curve: AppMotion.curve,
    );
    _slideController.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() {
        _slideFromSquare = null;
        _slideFromFractional = null;
        _slideToSquare = null;
        _slidePiece = null;
        _rookFrom = null;
        _rookTo = null;
        _rookPiece = null;
      });
    });
  }

  @override
  void dispose() {
    _dismissPromotion();
    WidgetsBinding.instance.removeObserver(this);
    _dragPosition.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _clearSlide() {
    _slideController.stop();
    _slideFromSquare = null;
    _slideFromFractional = null;
    _slideToSquare = null;
    _slidePiece = null;
    _rookFrom = null;
    _rookTo = null;
    _rookPiece = null;
  }

  void _cancelInteraction() {
    _dismissPromotion();
    _interactionGeneration++;
    _gestureCancelled = true;
    _panDownSquare = null;
    _draggingFrom = null;
    _dragPosition.value = null;
    _pendingDragReleaseSquare = null;
    _pendingDragReleaseFractional = null;
    _clearSlide();
  }

  @override
  void didUpdateWidget(covariant ChessBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orientation != widget.orientation) _cancelInteraction();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) setState(_cancelInteraction);
  }

  Square _squareAtLocalPosition(Offset local, double cellSize) {
    final col = (local.dx / cellSize).floor().clamp(0, 7);
    final row = (local.dy / cellSize).floor().clamp(0, 7);
    return _squareAt(row, col, widget.orientation);
  }

  /// Start a visual flight of [piece] to [to]. Use [fromSquare] when present,
  /// otherwise [fromFractional] in cell units, including returns from illegal
  /// drops.
  void _startSlide({
    Square? fromSquare,
    Offset? fromFractional,
    required Square to,
    required Piece piece,
    Square? rookFrom,
    Square? rookTo,
    Piece? rookPiece,
  }) {
    setState(() {
      _clearSlide();
      _rookFrom = rookFrom;
      _rookTo = rookTo;
      _rookPiece = rookPiece;
      _slideFromSquare = fromSquare;
      _slideFromFractional = fromFractional;
      _slideToSquare = to;
      _slidePiece = piece;
    });
    _slideController.stop();
    unawaited(_slideController.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    if (widget.showAttackedPieces &&
        !identical(_attackPosition, state.position)) {
      _attackPosition = state.position;
      _attackedSquares = attackedPieces(state.position);
    }

    // Listen for newly appended moves to animate once per move as a side
    // effect, outside the build phase.
    ref.listen<GameState>(gameControllerProvider, (previous, next) {
      final previousLength = previous?.uciHistory.length ?? 0;
      if (previous?.gameId != next.gameId) {
        setState(_cancelInteraction);
        return;
      }
      if (identical(previous?.position, next.position)) return;
      final isNewMove =
          next.uciHistory.length == previousLength + 1 &&
          next.positionHistory.isNotEmpty &&
          identical(next.positionHistory.last, previous?.position);
      if (!isNewMove) {
        setState(_cancelInteraction);
        return; // Restart, undo, or restore is not a new move.
      }
      if (next.sanHistory.isNotEmpty) {
        unawaited(playMoveHaptic(classifyMoveFeedback(next.sanHistory.last)));
      }

      final move = Move.parse(next.uciHistory.last);
      if (move is! NormalMove) return;
      final oldPosition = previous!.position;
      final isCastle =
          oldPosition.board.pieceAt(move.from)?.role == Role.king &&
          (next.sanHistory.last.startsWith('O-O'));
      final side = move.to > move.from ? CastlingSide.king : CastlingSide.queen;
      final destination = isCastle
          ? kingCastlesTo(oldPosition.turn, side)
          : move.to;
      final rookFrom = isCastle
          ? oldPosition.castles.rookOf(oldPosition.turn, side)
          : null;
      final rookTo = isCastle ? rookCastlesTo(oldPosition.turn, side) : null;
      final movedPiece = next.position.board.pieceAt(destination);
      if (movedPiece == null) return;

      final dragRelease = _pendingDragReleaseSquare == move.from
          ? _pendingDragReleaseFractional
          : null;
      _cancelInteraction();

      _startSlide(
        fromSquare: dragRelease == null ? move.from : null,
        fromFractional: dragRelease,
        to: destination,
        piece: movedPiece,
        rookFrom: rookFrom,
        rookTo: rookTo,
        rookPiece: rookTo == null ? null : next.position.board.pieceAt(rookTo),
      );
    });

    final selected = state.selectedSquare;
    final canInteract =
        !state.isGameOver && !state.isAiTurn && !state.aiThinking;
    final legalDestinations = selected != null
        ? state.legalDestinationsFrom(selected).toSet()
        : const <Square>{};

    // Last-move squares stay highlighted after flight completion until the
    // next move.
    Square? lastMoveFrom;
    Square? lastMoveTo;
    if (state.uciHistory.isNotEmpty) {
      final lastMove = Move.parse(state.uciHistory.last);
      if (lastMove is NormalMove) {
        lastMoveFrom = lastMove.from;
        lastMoveTo = lastMove.to;
      }
    }
    final checkSquare = state.position.isCheck
        ? state.position.board.kingOf(state.position.turn)
        : null;

    Future<Role?> askPromotion(Square from, Square to) async {
      final generation = _interactionGeneration;
      final release = _squareTopLeft(to, widget.orientation, 1);
      setState(() {
        _clearSlide();
        _promotionFrom = from;
        _promotionTo = to;
        _promotionPawn = state.position.board.pieceAt(from);
        _pendingDragReleaseSquare = from;
        _pendingDragReleaseFractional = release;
      });
      final choice = await showPromotionDialog(
        context,
        state.position.turn,
        onRoute: (route) => _promotionRoute = route,
      );
      if (!mounted || generation != _interactionGeneration) return null;
      setState(() {
        _promotionRoute = null;
        _promotionFrom = null;
        _promotionTo = null;
        _promotionPawn = null;
      });
      if (choice == null) {
        _pendingDragReleaseSquare = null;
        _pendingDragReleaseFractional = null;
        _startSlide(
          fromFractional: release,
          to: from,
          piece: state.position.board.pieceAt(from)!,
        );
      }
      return choice;
    }

    Future<void> tapSquare(Square square) {
      final from = ref.read(gameControllerProvider).selectedSquare;
      return controller.onSquareTapped(
        square,
        onPromotion: () => askPromotion(from!, square),
      );
    }

    return _FittedSquare(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = constraints.maxWidth / 8;

          void handleDragDown(DragDownDetails details) {
            _gestureCancelled = false;
            _panDownSquare = _squareAtLocalPosition(
              details.localPosition,
              cellSize,
            );
          }

          void handleDragStart(DragStartDetails details) {
            if (_gestureCancelled) return;
            final downSquare = _panDownSquare;
            _panDownSquare = null;
            // An earlier flight is purely visual: state already holds its
            // final position, so it must not block another drag.
            final square =
                downSquare ??
                _squareAtLocalPosition(details.localPosition, cellSize);
            if (!controller.selectForDrag(square)) return;
            // Haptic feedback confirms that the piece has been picked up.
            unawaited(HapticFeedback.selectionClick());
            setState(() {
              _draggingFrom = square;
              _dragPosition.value = details.localPosition;
              // Stop flight when grabbing its piece so flight and drag layers
              // do not draw duplicates.
              if (_slideToSquare == square || _rookTo == square) {
                _clearSlide();
              }
            });
          }

          void handleDragUpdate(DragUpdateDetails details) {
            if (_draggingFrom == null) return;
            _dragPosition.value = details.localPosition;
          }

          void handleDragEnd(DragEndDetails details) {
            final from = _draggingFrom;
            final pos = _dragPosition.value;
            setState(() {
              _draggingFrom = null;
              _dragPosition.value = null;
            });
            if (from == null || pos == null) return;
            final releaseTopLeft = pos - Offset(cellSize / 2, cellSize / 2);
            // Dropping outside cancels; clamping to the edge could turn it
            // into an unintended legal move.
            final boardBounds = Offset.zero & Size.square(cellSize * 8);
            if (!boardBounds.contains(pos)) {
              final piece = ref
                  .read(gameControllerProvider)
                  .position
                  .board
                  .pieceAt(from);
              if (piece != null) {
                _startSlide(
                  fromFractional: releaseTopLeft / cellSize,
                  to: from,
                  piece: piece,
                );
              }
              return;
            }
            final to = _squareAtLocalPosition(pos, cellSize);
            _pendingDragReleaseSquare = from;
            _pendingDragReleaseFractional = releaseTopLeft / cellSize;
            final generation = _interactionGeneration;
            final beforePosition = state.position;
            unawaited(
              controller
                  .attemptDragMove(
                    from,
                    to,
                    onPromotion: () async {
                      final choice = await askPromotion(from, to);
                      if (!mounted ||
                          generation != _interactionGeneration ||
                          !identical(
                            ref.read(gameControllerProvider).position,
                            beforePosition,
                          )) {
                        return null;
                      }
                      return choice;
                    },
                  )
                  .then((_) {
                    // Accepted moves have already consumed the pending
                    // release point in the state listener. Return a rejected
                    // move or cancelled promotion smoothly to its origin.
                    if (!mounted ||
                        generation != _interactionGeneration ||
                        _pendingDragReleaseSquare != from) {
                      return;
                    }
                    final release = _pendingDragReleaseFractional;
                    _pendingDragReleaseSquare = null;
                    _pendingDragReleaseFractional = null;
                    final current = ref.read(gameControllerProvider);
                    if (!identical(current.position, beforePosition)) return;
                    final piece = current.position.board.pieceAt(from);
                    if (piece == null || release == null) return;
                    _startSlide(
                      fromFractional: release,
                      to: from,
                      piece: piece,
                    );
                  }),
            );
          }

          void handleDragCancel() => setState(() {
            _draggingFrom = null;
            _dragPosition.value = null;
          });

          // Axis recognisers share the ListView threshold. The descendant
          // board wins before scrolling; a pan recogniser required more
          // movement and lost gradual drags.
          return Listener(
            onPointerCancel: (_) => setState(_cancelInteraction),
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final square = _squareAtLocalPosition(
                  details.localPosition,
                  cellSize,
                );
                unawaited(tapSquare(square));
              },
              // Gesture recognition can occur after the pointer has reached a
              // neighbouring square. Capture the original square on drag-down
              // so small squares do not select the wrong piece.
              onVerticalDragDown: handleDragDown,
              onVerticalDragStart: handleDragStart,
              onVerticalDragUpdate: handleDragUpdate,
              onVerticalDragEnd: handleDragEnd,
              onVerticalDragCancel: handleDragCancel,
              onHorizontalDragDown: handleDragDown,
              onHorizontalDragStart: handleDragStart,
              onHorizontalDragUpdate: handleDragUpdate,
              onHorizontalDragEnd: handleDragEnd,
              onHorizontalDragCancel: handleDragCancel,
              child: ValueListenableBuilder<Offset?>(
                valueListenable: _dragPosition,
                child: RepaintBoundary(
                  child: GridView.builder(
                    key: const Key('chess-board-grid'),
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                        ),
                    itemCount: 64,
                    itemBuilder: (context, index) {
                      final displayRow = index ~/ 8;
                      final displayCol = index % 8;
                      final square = _squareAt(
                        displayRow,
                        displayCol,
                        widget.orientation,
                      );
                      final piece = state.position.board.pieceAt(square);
                      final isSelected = square == selected;
                      final isLegalTarget = legalDestinations.contains(square);
                      final isBeingDragged =
                          square == _draggingFrom ||
                          square == _promotionFrom ||
                          square == _promotionTo;
                      // Hide the static destination piece while its flight
                      // layer is visible.
                      final isFlightDestination =
                          _slideToSquare == square || _rookTo == square;
                      // Do not fade the origin separately: the flight already
                      // covers its departure.
                      final isFlightOrigin =
                          (_slideFromSquare == square &&
                              _slideToSquare != null) ||
                          _rookFrom == square;

                      return Semantics(
                        key: ValueKey('board-semantics-${square.name}'),
                        container: true,
                        excludeSemantics: true,
                        label: boardSquareLabel(square, piece),
                        selected: isSelected,
                        button: true,
                        enabled: canInteract,
                        value: [
                          if (square == widget.hintSquare)
                            'Piece suggested by Stockfish',
                          if (isLegalTarget) 'Legal destination',
                          if (square == lastMoveFrom || square == lastMoveTo)
                            'Last move',
                          if (square == checkSquare) 'Check',
                          if (widget.showAttackedPieces &&
                              _attackedSquares.contains(square) &&
                              (widget.attackedSide == null ||
                                  piece?.color == widget.attackedSide))
                            'Attacked piece${piece != null && state.position.board.attacksTo(square, piece.color).isNotEmpty ? ', defended' : ', without geometric defence'}',
                        ].join(', '),
                        onTap: canInteract
                            ? () => unawaited(tapSquare(square))
                            : null,
                        child: _SquareVisual(
                          isHint: square == widget.hintSquare,
                          defended:
                              piece != null &&
                              state.position.board
                                  .attacksTo(square, piece.color)
                                  .isNotEmpty,
                          key: ValueKey('board-square-$displayRow-$displayCol'),
                          piece: (isBeingDragged || isFlightDestination)
                              ? null
                              : piece,
                          pieceKey: piece == null
                              ? null
                              : ValueKey('board-piece-$displayRow-$displayCol'),
                          isSelected: isSelected,
                          isLegalTarget: isLegalTarget,
                          isLastMove:
                              square == lastMoveFrom || square == lastMoveTo,
                          isCheck: square == checkSquare,
                          isAttacked:
                              widget.showAttackedPieces &&
                              _attackedSquares.contains(square) &&
                              (widget.attackedSide == null ||
                                  piece?.color == widget.attackedSide),
                          instantExit:
                              isFlightOrigin ||
                              isBeingDragged ||
                              isFlightDestination,
                        ),
                      );
                    },
                  ),
                ),
                builder: (context, dragPosition, board) {
                  final hoveredSquare =
                      _draggingFrom != null &&
                          dragPosition != null &&
                          (Offset.zero & Size.square(cellSize * 8)).contains(
                            dragPosition,
                          )
                      ? _squareAtLocalPosition(dragPosition, cellSize)
                      : null;

                  return Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.expand,
                    children: [
                      _BoardBackground(
                        boardTheme: BoardAppearance.of(context).boardTheme,
                      ),
                      board!,
                      if (widget.threats.isNotEmpty)
                        Positioned.fill(
                          child: ThreatArrows(
                            threats: widget.threats,
                            orientation: widget.orientation,
                          ),
                        ),
                      for (final flight in [
                        if (_slideToSquare != null && _slidePiece != null)
                          (
                            from: _slideFromSquare,
                            fractional: _slideFromFractional,
                            to: _slideToSquare!,
                            piece: _slidePiece!,
                            key: 'board-slide-layer',
                          ),
                        if (_rookFrom != null &&
                            _rookTo != null &&
                            _rookPiece != null)
                          (
                            from: _rookFrom,
                            fractional: null,
                            to: _rookTo!,
                            piece: _rookPiece!,
                            key: 'board-rook-slide-layer',
                          ),
                      ])
                        AnimatedBuilder(
                          key: Key(flight.key),
                          animation: _slideCurve,
                          builder: (context, _) {
                            final toSquare = flight.to;
                            final piece = flight.piece;
                            final fromOffset = flight.fractional != null
                                ? flight.fractional! * cellSize
                                : flight.from != null
                                ? _squareTopLeft(
                                    flight.from!,
                                    widget.orientation,
                                    cellSize,
                                  )
                                : null;
                            if (fromOffset == null) {
                              return const SizedBox.shrink();
                            }
                            final toOffset = _squareTopLeft(
                              toSquare,
                              widget.orientation,
                              cellSize,
                            );
                            final offset = Offset.lerp(
                              fromOffset,
                              toOffset,
                              _slideCurve.value,
                            )!;
                            return Positioned(
                              left: offset.dx,
                              top: offset.dy,
                              width: cellSize,
                              height: cellSize,
                              child: IgnorePointer(
                                child: FractionallySizedBox(
                                  widthFactor: _pieceScale,
                                  heightFactor: _pieceScale,
                                  child: ExcludeSemantics(
                                    child: ChessPieceWidget(piece: piece),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      if (_promotionTo != null && _promotionPawn != null)
                        Positioned.fromRect(
                          rect:
                              _squareTopLeft(
                                _promotionTo!,
                                widget.orientation,
                                cellSize,
                              ) &
                              Size.square(cellSize),
                          child: IgnorePointer(
                            child: FractionallySizedBox(
                              widthFactor: _pieceScale,
                              heightFactor: _pieceScale,
                              child: ExcludeSemantics(
                                child: ChessPieceWidget(
                                  key: const Key('board-promotion-piece'),
                                  piece: _promotionPawn!,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (hoveredSquare != null)
                        Positioned.fromRect(
                          rect:
                              _squareTopLeft(
                                hoveredSquare,
                                widget.orientation,
                                cellSize,
                              ) &
                              Size.square(cellSize),
                          child: IgnorePointer(
                            child: Container(
                              key: const Key('board-drag-target'),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black87,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Draw the enlarged piece above all layers. The
                      // destination stays under the finger without visual
                      // offset compensation.
                      if (_draggingFrom != null && dragPosition != null)
                        Positioned(
                          key: const Key('board-drag-layer'),
                          left:
                              dragPosition.dx - cellSize * _dragPieceScale / 2,
                          top: dragPosition.dy - cellSize * _dragPieceScale / 2,
                          width: cellSize * _dragPieceScale,
                          height: cellSize * _dragPieceScale,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: ChessPieceWidget(
                                key: const Key('board-drag-piece'),
                                piece: state.position.board.pieceAt(
                                  _draggingFrom!,
                                )!,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// Cburnett SVGs already contain the internal margin used by Lichess.
const _pieceScale = 1.0;
const _dragPieceScale = 1.15;

class _BoardBackground extends StatelessWidget {
  const _BoardBackground({required this.boardTheme});

  final BoardTheme boardTheme;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Image.asset(
      boardTheme.assetPath,
      key: const Key('chess-board-background'),
      fit: BoxFit.fill,
      cacheWidth: 1024,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    ),
  );
}

/// Fit the board to the smallest finite parent axis. In a vertical list,
/// width determines the square; in landscape, finite height also limits it to
/// the screen.
class _FittedSquare extends StatelessWidget {
  const _FittedSquare({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final finiteWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : double.infinity;
        final finiteHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : double.infinity;
        final size = math.min(finiteWidth, finiteHeight);
        final resolvedSize = size.isFinite ? size : 320.0;

        return Center(
          child: SizedBox.square(
            key: const Key('chess-board'),
            dimension: resolvedSize,
            child: child,
          ),
        );
      },
    );
  }
}

/// Read-only board used by game replay.
class StaticChessBoardWidget extends StatelessWidget {
  const StaticChessBoardWidget({
    required this.position,
    super.key,
    this.orientation = Side.white,
    this.boardTheme,
  });

  final Chess position;
  final Side orientation;
  final BoardTheme? boardTheme;

  @override
  Widget build(BuildContext context) {
    return _FittedSquare(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _BoardBackground(
            boardTheme: boardTheme ?? BoardAppearance.of(context).boardTheme,
          ),
          GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
            ),
            itemCount: 64,
            itemBuilder: (context, index) {
              final displayRow = index ~/ 8;
              final displayCol = index % 8;
              final square = _squareAt(displayRow, displayCol, orientation);
              final piece = position.board.pieceAt(square);
              return Semantics(
                container: true,
                excludeSemantics: true,
                label: boardSquareLabel(square, piece),
                child: _SquareVisual(
                  piece: piece,
                  pieceKey: piece == null
                      ? null
                      : ValueKey('static-piece-$displayRow-$displayCol'),
                  isSelected: false,
                  isLegalTarget: false,
                  isLastMove: false,
                  isCheck: false,
                  instantExit: false,
                ),
              );
            },
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Map visual row/column coordinates from the widget top to [Square],
/// respecting [orientation].
Square _squareAt(int displayRow, int displayCol, Side orientation) {
  final rank = orientation == Side.white ? 7 - displayRow : displayRow;
  final file = orientation == Side.white ? displayCol : 7 - displayCol;
  return Square.fromCoords(File(file), Rank(rank));
}

/// Inverse of [_squareAt]: the pixel origin of [square] for the current
/// orientation and cell size, used to position a flying piece.
Offset _squareTopLeft(Square square, Side orientation, double cellSize) {
  final displayRow = orientation == Side.white
      ? 7 - square.rank.value
      : square.rank.value;
  final displayCol = orientation == Side.white
      ? square.file.value
      : 7 - square.file.value;
  return Offset(displayCol * cellSize, displayRow * cellSize);
}

/// Highlights over board assets using Lichess-style colours.
abstract final class _BoardColors {
  static const selectionTint = Color(0x8014551E);

  // Yellow-green highlight for the last move origin and destination.
  static const lastMoveTint = Color(0x699BC700);
  static const greenBoardLastMoveTint = Color(0x69009BC7);

  // Red radial glow behind a king in check, fading with AnimatedOpacity like
  // legal-move indicators.
  static const checkGlowCenter = Color(0xB3F44336);
  static const checkGlowEdge = Color(0x00F44336);
}

class _SquareVisual extends StatelessWidget {
  const _SquareVisual({
    super.key,
    required this.piece,
    required this.pieceKey,
    required this.isSelected,
    required this.isLegalTarget,
    required this.isLastMove,
    required this.isCheck,
    required this.instantExit,
    this.isAttacked = false,
    this.isHint = false,
    this.defended = false,
  });

  final Piece? piece;
  final bool isAttacked;
  final bool isHint;
  final bool defended;
  final Key? pieceKey;
  final bool isSelected;
  final bool isLegalTarget;

  /// Whether this square is the origin or destination of the last move.
  final bool isLastMove;

  /// Whether this square holds the king currently in check.
  final bool isCheck;

  /// Skip a separate exit fade when a piece flight already covers the
  /// transition.
  final bool instantExit;

  @override
  Widget build(BuildContext context) {
    var squareColor = Colors.transparent;
    if (isLastMove) {
      squareColor = BoardAppearance.of(context).boardTheme == BoardTheme.green
          ? _BoardColors.greenBoardLastMoveTint
          : _BoardColors.lastMoveTint;
    }
    if (isSelected) {
      squareColor = Color.alphaBlend(_BoardColors.selectionTint, squareColor);
    }

    return SizedBox.expand(
      // Interpolate selection and last-move colours instead of switching
      // abruptly.
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        color: squareColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                key: const ValueKey('check-glow-indicator'),
                duration: AppMotion.medium,
                curve: AppMotion.curve,
                opacity: isCheck ? 1 : 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _BoardColors.checkGlowCenter,
                        _BoardColors.checkGlowEdge,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: FractionallySizedBox(
                widthFactor: _pieceScale,
                heightFactor: _pieceScale,
                // Keep the piece slot mounted so AnimatedSwitcher can animate
                // both entry and exit. When flight covers the exit, make that
                // transition immediate to avoid duplication.
                child: AnimatedSwitcher(
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    fit: StackFit.expand,
                    children: [...previousChildren, ?currentChild],
                  ),
                  duration: AppMotion.medium,
                  reverseDuration: instantExit ? Duration.zero : null,
                  switchInCurve: AppMotion.curve,
                  switchOutCurve: AppMotion.curve,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: piece == null
                      ? const SizedBox.shrink(key: ValueKey('empty-square'))
                      : ChessPieceWidget(key: pieceKey, piece: piece!),
                ),
              ),
            ),
            if (isAttacked)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    key: const Key('attacked-piece-indicator'),
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: defended
                            ? const Color(0xFF1565C0)
                            : const Color(0xFFC45500),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(defended ? 8 : 0),
                    ),
                    child: defended
                        ? Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF1565C0),
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            if (isHint)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    key: const Key('hint-origin-indicator'),
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFFFB300),
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: AnimatedOpacity(
                key: const ValueKey('legal-target-indicator'),
                duration: AppMotion.fast,
                curve: AppMotion.curve,
                opacity: isLegalTarget ? 1 : 0,
                child: FractionallySizedBox(
                  widthFactor: piece == null ? 0.30 : 0.88,
                  heightFactor: piece == null ? 0.30 : 0.88,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: piece == null
                          ? _BoardColors.selectionTint
                          : Colors.transparent,
                      border: piece != null
                          ? Border.all(color: const Color(0x4D145500), width: 3)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
