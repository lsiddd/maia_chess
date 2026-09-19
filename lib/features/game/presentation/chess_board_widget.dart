import 'dart:async';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theming/app_theme.dart';
import '../application/game_controller.dart';
import '../application/game_state.dart';
import '../application/move_feedback.dart';
import 'chess_piece_widget.dart';
import 'promotion_dialog.dart';
import 'board_accessibility.dart';

/// Tabuleiro interativo: lances por toque (seleciona origem, toca destino)
/// ou por arrastar a peça até a casa de destino.
///
/// Usa um único `GestureDetector` cobrindo o tabuleiro inteiro (em vez de
/// `Draggable`/`DragTarget` por casa) — mais simples e evita conflitos de
/// arena de gestos entre 64 reconhecedores de toque/arraste aninhados. A
/// peça "flutuante" durante o arraste é só um widget posicionado dentro do
/// próprio `Stack` do tabuleiro, sem depender do `Overlay` global.
///
/// A validação de legalidade nunca é feita aqui — este widget só lê o
/// estado exposto por [GameController] (que consulta `dartchess`) e envia
/// intenções de lance de volta a ele.
class ChessBoardWidget extends ConsumerStatefulWidget {
  const ChessBoardWidget({super.key, this.orientation = Side.white});

  /// Lado exibido na parte inferior do tabuleiro (perspectiva do jogador).
  final Side orientation;

  @override
  ConsumerState<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends ConsumerState<ChessBoardWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Square? _draggingFrom;
  Offset? _dragPosition;

  // Casa tocada em `onDragDown`, antes do gesto ser reconhecido como
  // arraste — ver o comentário em `onDragDown` mais abaixo.
  Square? _panDownSquare;

  // Casa de origem do arraste que acabou de ser solto, guardada em unidades
  // de célula (não em pixels) para sobreviver a um relayout: se o lance for
  // aceito, o "voo" da peça (abaixo) parte exatamente de onde o dedo soltou
  // em vez de saltar de volta para o centro da casa de origem antes de
  // animar. Consumida (e zerada) assim que usada, seja pelo `ref.listen`
  // abaixo (lance aceito) ou pelo retorno de `attemptDragMove` (rejeitado).
  Square? _pendingDragReleaseSquare;
  Offset? _pendingDragReleaseFractional;

  // Anima a peça deslizando da casa de origem até a de destino sempre que
  // um lance é aplicado — do jogador (toque ou arraste) ou da engine —, em
  // vez de a peça só desaparecer de um lugar e aparecer no outro. Um único
  // `AnimationController` é suficiente porque só existe um voo por vez: se
  // um novo lance é aplicado (ou a peça em voo é agarrada de novo) antes do
  // voo anterior terminar, ele é interrompido/reiniciado na hora — o
  // jogador pode continuar jogando livremente sem esperar a animação.
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
    _dragPosition = null;
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

  /// Inicia (ou reinicia) o voo visual de [piece] até [to]. Se [fromSquare]
  /// for nulo, a origem é [fromFractional] (posição em unidades de célula,
  /// usada para o retorno suave de um arraste solto num destino ilegal);
  /// caso contrário a origem é o centro de [fromSquare].
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

    // Sempre que um novo lance entra no histórico — jogado por toque,
    // arraste ou pela engine —, dispara a animação de deslizamento da peça
    // até a casa de destino. `ref.listen` (em vez de comparar em `build`)
    // garante que isto rode como efeito colateral, uma vez por lance, e não
    // durante a fase de build em si.
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
        return; // reinício, undo ou restauração: não é "um lance novo".
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
        !state.isGameOver &&
        !state.isAiTurn &&
        !state.aiThinking &&
        !state.hintThinking;
    final legalDestinations = selected != null
        ? state.legalDestinationsFrom(selected).toSet()
        : const <Square>{};

    // Casas do último lance (origem e destino) recebem um destaque suave e
    // persistente, independente da animação de voo — inclusive depois que
    // ela termina, até o próximo lance ser jogado.
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
          final dragPosition = _dragPosition;
          final hoveredSquare =
              _draggingFrom != null &&
                  dragPosition != null &&
                  (Offset.zero & Size.square(cellSize * 8)).contains(
                    dragPosition,
                  )
              ? _squareAtLocalPosition(dragPosition, cellSize)
              : null;

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
            // Não bloqueia por um voo de outro lance ainda em animação: o
            // voo é só visual (a posição em `state` já está atualizada
            // desde que o lance foi aplicado) e o jogador não deve sentir
            // o arraste seguinte "não funcionar" nos ~350ms depois de
            // qualquer lance, inclusive o da IA.
            final square =
                downSquare ??
                _squareAtLocalPosition(details.localPosition, cellSize);
            if (!controller.selectForDrag(square)) return;
            // Confirma no tato que a peça foi "pega" — sem isso o começo
            // do arraste só se percebe pelo olho.
            unawaited(HapticFeedback.selectionClick());
            setState(() {
              _draggingFrom = square;
              _dragPosition = details.localPosition;
              // Se a peça agarrada é a que ainda está "aterrissando" de um
              // voo em andamento, encerra o voo na hora: senão o overlay
              // de voo e o overlay de arraste desenhariam a mesma peça
              // sobreposta nesta casa até a animação acabar sozinha.
              if (_slideToSquare == square || _rookTo == square) {
                _clearSlide();
              }
            });
          }

          void handleDragUpdate(DragUpdateDetails details) {
            if (_draggingFrom == null) return;
            setState(() => _dragPosition = details.localPosition);
          }

          void handleDragEnd(DragEndDetails details) {
            final from = _draggingFrom;
            final pos = _dragPosition;
            setState(() {
              _draggingFrom = null;
              _dragPosition = null;
            });
            if (from == null || pos == null) return;
            final releaseTopLeft = pos - Offset(cellSize / 2, cellSize / 2);
            // Soltar fora cancela: limitar as coordenadas à borda poderia
            // transformar essa soltura em um lance legal não desejado.
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
                    // Se o lance foi aceito, `ref.listen` acima já
                    // consumiu os campos pendentes e iniciou o voo até o
                    // destino — nada a fazer aqui. Se não (lance ilegal
                    // ou promoção cancelada), solta a peça de volta para
                    // a própria casa em vez de ela só reaparecer ali.
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
            _dragPosition = null;
          });

          // Recognizers por eixo usam o mesmo limiar da ListView. Como o
          // tabuleiro é descendente, ganha a disputa antes da rolagem.
          // Pan exige mais deslocamento e perdia em movimentos graduais.
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
              // `onDragStart` só dispara depois que o movimento já superou o
              // limiar de reconhecimento do gesto (slop) — em casas pequenas
              // esse limiar pode corresponder a quase uma célula inteira, e
              // por essa altura `details.localPosition` já pode estar sobre a
              // casa vizinha. `onDragDown` fixa a casa de fato tocada, antes de
              // qualquer deslocamento, para o arraste sempre pegar a peça
              // correta mesmo que o gesto só seja "aceito" mais adiante.
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
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  GridView.builder(
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
                      final isDark =
                          (square.file.value + square.rank.value).isEven;
                      final isSelected = square == selected;
                      final isLegalTarget = legalDestinations.contains(square);
                      final isBeingDragged =
                          square == _draggingFrom ||
                          square == _promotionFrom ||
                          square == _promotionTo;
                      // Enquanto a peça está "voando" para esta casa, a
                      // versão estática dela fica oculta (a peça visível é só
                      // a que está no overlay de voo, abaixo).
                      final isFlightDestination =
                          _slideToSquare == square || _rookTo == square;
                      // A casa de onde a peça acabou de sair não deve
                      // esmaecer sozinha: o voo já cobre esse efeito, então a
                      // troca para "vazia" aqui é instantânea.
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
                          if (isLegalTarget) 'Destino legal',
                          if (square == lastMoveFrom || square == lastMoveTo)
                            'Último lance',
                          if (square == checkSquare) 'Xeque',
                        ].join(', '),
                        onTap: canInteract
                            ? () => unawaited(tapSquare(square))
                            : null,
                        child: _SquareVisual(
                          key: ValueKey('board-square-$displayRow-$displayCol'),
                          piece: (isBeingDragged || isFlightDestination)
                              ? null
                              : piece,
                          pieceKey: piece == null
                              ? null
                              : ValueKey('board-piece-$displayRow-$displayCol'),
                          isDark: isDark,
                          isSelected: isSelected,
                          isLegalTarget: isLegalTarget,
                          isLastMove:
                              square == lastMoveFrom || square == lastMoveTo,
                          isCheck: square == checkSquare,
                          instantExit:
                              isFlightOrigin ||
                              isBeingDragged ||
                              isFlightDestination,
                        ),
                      );
                    },
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
                        if (fromOffset == null) return const SizedBox.shrink();
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
                            border: Border.all(color: Colors.white, width: 2),
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
                  // A peça ampliada fica acima de todas as camadas. O destino
                  // continua sendo a casa sob o dedo, sem compensação visual.
                  if (_draggingFrom != null && dragPosition != null)
                    Positioned(
                      key: const Key('board-drag-layer'),
                      left: dragPosition.dx - cellSize / 2,
                      top: dragPosition.dy - cellSize / 2,
                      width: cellSize,
                      height: cellSize,
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
              ),
            ),
          );
        },
      ),
    );
  }
}

const _pieceScale = 0.78;

/// Ajusta o tabuleiro ao menor eixo finito recebido pelo pai.
///
/// Em uma lista vertical a altura é ilimitada e a largura define o quadrado;
/// em paisagem os dois eixos são limitados e a altura disponível passa a
/// impedir que o tabuleiro estoure a tela.
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

/// Versão somente leitura usada pela biblioteca de partidas.
class StaticChessBoardWidget extends StatelessWidget {
  const StaticChessBoardWidget({
    required this.position,
    super.key,
    this.orientation = Side.white,
  });

  final Chess position;
  final Side orientation;

  @override
  Widget build(BuildContext context) {
    return _FittedSquare(
      child: Stack(
        fit: StackFit.expand,
        children: [
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
                  isDark: (square.file.value + square.rank.value).isEven,
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

/// Converte a posição visual (linha/coluna exibidas, começando no topo do
/// widget) para a [Square] correspondente, respeitando [orientation].
Square _squareAt(int displayRow, int displayCol, Side orientation) {
  final rank = orientation == Side.white ? 7 - displayRow : displayRow;
  final file = orientation == Side.white ? displayCol : 7 - displayCol;
  return Square.fromCoords(File(file), Rank(rank));
}

/// Inverso de [_squareAt]: o canto superior esquerdo (em pixels) de
/// [square] dentro do tabuleiro, dada a orientação e o tamanho de célula
/// atuais. Usado para posicionar a peça "voando" de uma casa a outra.
Offset _squareTopLeft(Square square, Side orientation, double cellSize) {
  final displayRow = orientation == Side.white
      ? 7 - square.rank.value
      : square.rank.value;
  final displayCol = orientation == Side.white
      ? square.file.value
      : 7 - square.file.value;
  return Offset(displayCol * cellSize, displayRow * cellSize);
}

/// Paleta do tabuleiro em si, fixa independente do tema claro/escuro do
/// app: é a convenção visual do domínio de xadrez (mesmas cores usadas por
/// chess.com/lichess), não uma escolha de marca do app.
abstract final class _BoardColors {
  static const lightSquare = Color(0xFFEEEED2);
  static const darkSquare = Color(0xFF769656);
  static const selectionTint = Color(0xA6FFD54F);

  // Mesmo tom da seleção, porém mais discreto: marca as duas casas do
  // último lance sem competir visualmente com a casa selecionada agora.
  static const lastMoveTint = Color(0x66FFD54F);

  // Brilho radial vermelho por trás do rei em xeque, com o mesmo padrão de
  // fade implícito (AnimatedOpacity) usado no indicador de lance legal.
  static const checkGlowCenter = Color(0xB3F44336);
  static const checkGlowEdge = Color(0x00F44336);
}

class _SquareVisual extends StatelessWidget {
  const _SquareVisual({
    super.key,
    required this.piece,
    required this.pieceKey,
    required this.isDark,
    required this.isSelected,
    required this.isLegalTarget,
    required this.isLastMove,
    required this.isCheck,
    required this.instantExit,
  });

  final Piece? piece;
  final Key? pieceKey;
  final bool isDark;
  final bool isSelected;
  final bool isLegalTarget;

  /// Se esta casa é a origem ou o destino do último lance jogado.
  final bool isLastMove;

  /// Se esta casa tem o rei do lado que está em xeque agora.
  final bool isCheck;

  /// Se a peça que está saindo desta casa não deve esmaecer sozinha: um voo
  /// (ver [_ChessBoardWidgetState]) já está cobrindo essa transição.
  final bool instantExit;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark
        ? _BoardColors.darkSquare
        : _BoardColors.lightSquare;
    var squareColor = baseColor;
    if (isLastMove) {
      squareColor = Color.alphaBlend(_BoardColors.lastMoveTint, squareColor);
    }
    if (isSelected) {
      squareColor = Color.alphaBlend(_BoardColors.selectionTint, squareColor);
    }

    return SizedBox.expand(
      // AnimatedContainer em vez de ColoredBox: a troca de cor ao
      // selecionar/desselecionar uma casa (ou marcar o último lance) passa
      // a interpolar suavemente em vez de trocar de uma vez.
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
                // A peça troca (aparece/some) com um fade + scale em vez de
                // saltar instantaneamente entre "presente"/"ausente"; o
                // slot fica sempre montado para o AnimatedSwitcher poder
                // animar a saída, não só a entrada. Quando a saída já está
                // coberta por um voo (`instantExit`), a transição de saída
                // é instantânea para não duplicar a animação.
                child: AnimatedSwitcher(
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
                          ? Colors.black.withValues(alpha: 0.30)
                          : Colors.transparent,
                      border: piece != null
                          ? Border.all(
                              color: Colors.black.withValues(alpha: 0.46),
                              width: 3,
                            )
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
