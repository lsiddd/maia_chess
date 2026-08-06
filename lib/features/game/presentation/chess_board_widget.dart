import 'dart:async';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_controller.dart';
import 'chess_piece_widget.dart';
import 'promotion_dialog.dart';

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

class _ChessBoardWidgetState extends ConsumerState<ChessBoardWidget> {
  Square? _draggingFrom;
  Offset? _dragPosition;

  Square _squareAtLocalPosition(Offset local, double cellSize) {
    final col = (local.dx / cellSize).floor().clamp(0, 7);
    final row = (local.dy / cellSize).floor().clamp(0, 7);
    return _squareAt(row, col, widget.orientation);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    final selected = state.selectedSquare;
    final legalDestinations = selected != null
        ? state.legalDestinationsFrom(selected).toSet()
        : const <Square>{};

    Future<Role?> askPromotion() =>
        showPromotionDialog(context, state.position.turn);

    return _FittedSquare(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = constraints.maxWidth / 8;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final square = _squareAtLocalPosition(
                details.localPosition,
                cellSize,
              );
              unawaited(
                controller.onSquareTapped(square, onPromotion: askPromotion),
              );
            },
            onPanStart: (details) {
              if (state.isGameOver ||
                  state.isAiTurn ||
                  state.aiThinking ||
                  state.hintThinking) {
                return;
              }
              final square = _squareAtLocalPosition(
                details.localPosition,
                cellSize,
              );
              final piece = state.position.board.pieceAt(square);
              if (piece == null || piece.color != state.position.turn) return;
              setState(() {
                _draggingFrom = square;
                _dragPosition = details.localPosition;
              });
            },
            onPanUpdate: (details) {
              if (_draggingFrom == null) return;
              setState(() => _dragPosition = details.localPosition);
            },
            onPanEnd: (details) {
              final from = _draggingFrom;
              final pos = _dragPosition;
              setState(() {
                _draggingFrom = null;
                _dragPosition = null;
              });
              if (from == null || pos == null) return;
              final to = _squareAtLocalPosition(pos, cellSize);
              unawaited(
                controller.attemptDragMove(from, to, onPromotion: askPromotion),
              );
            },
            onPanCancel: () => setState(() {
              _draggingFrom = null;
              _dragPosition = null;
            }),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GridView.builder(
                  key: const Key('chess-board-grid'),
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                    final isBeingDragged = square == _draggingFrom;

                    return _SquareVisual(
                      key: ValueKey('board-square-$displayRow-$displayCol'),
                      piece: isBeingDragged ? null : piece,
                      pieceKey: piece == null
                          ? null
                          : ValueKey('board-piece-$displayRow-$displayCol'),
                      isDark: isDark,
                      isSelected: isSelected,
                      isLegalTarget: isLegalTarget,
                    );
                  },
                ),
                if (_draggingFrom != null && _dragPosition != null)
                  Positioned(
                    left: _dragPosition!.dx - cellSize / 2,
                    top: _dragPosition!.dy - cellSize / 2,
                    width: cellSize,
                    height: cellSize,
                    child: IgnorePointer(
                      child: FractionallySizedBox(
                        widthFactor: _pieceScale,
                        heightFactor: _pieceScale,
                        child: ChessPieceWidget(
                          piece: state.position.board.pieceAt(_draggingFrom!)!,
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
              ],
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
              return _SquareVisual(
                piece: piece,
                pieceKey: piece == null
                    ? null
                    : ValueKey('static-piece-$displayRow-$displayCol'),
                isDark: (square.file.value + square.rank.value).isEven,
                isSelected: false,
                isLegalTarget: false,
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

class _SquareVisual extends StatelessWidget {
  const _SquareVisual({
    super.key,
    required this.piece,
    required this.pieceKey,
    required this.isDark,
    required this.isSelected,
    required this.isLegalTarget,
  });

  final Piece? piece;
  final Key? pieceKey;
  final bool isDark;
  final bool isSelected;
  final bool isLegalTarget;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark
        ? const Color(0xFF769656)
        : const Color(0xFFEEEED2);
    final squareColor = isSelected
        ? Color.alphaBlend(const Color(0xA6FFD54F), baseColor)
        : baseColor;

    return SizedBox.expand(
      child: ColoredBox(
        color: squareColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (piece != null)
              Positioned.fill(
                child: FractionallySizedBox(
                  widthFactor: _pieceScale,
                  heightFactor: _pieceScale,
                  child: ChessPieceWidget(key: pieceKey, piece: piece!),
                ),
              ),
            if (isLegalTarget)
              Positioned.fill(
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
          ],
        ),
      ),
    );
  }
}
