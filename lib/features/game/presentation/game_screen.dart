import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theming/app_theme.dart';
import '../../../core/widgets/error_state_card.dart';
import '../../hints/presentation/hint_dialog.dart';
import '../application/game_controller.dart';
import '../application/game_state.dart';
import 'chess_board_widget.dart';

/// Tela de uma partida local ou contra a IA Maia.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final vsAi = state.aiSide != null;

    ref.listen<GameState>(gameControllerProvider, (previous, next) {
      final wasOver = previous?.isGameOver ?? false;
      if (!wasOver && next.isGameOver) {
        _showGameOverDialog(context, next);
      }
    });

    final busy = state.aiThinking || state.hintThinking;
    final canHint = vsAi && !busy && !state.isAiTurn && !state.isGameOver;
    final canUndo = state.canUndo && !busy && !state.isGameOver;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          vsAi
              ? state.campaignMode
                    ? 'Campanha • Maia ${state.levelRating}'
                    : 'Contra Maia ${state.levelRating}'
              : 'Partida local',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _ResponsiveGameLayout(
                constraints: constraints,
                board: ChessBoardWidget(
                  orientation: state.aiSide == null
                      ? Side.white
                      : state.aiSide!.opposite,
                ),
                status: _StatusBar(state: state),
                actions: _GameActions(
                  showHint: vsAi,
                  onHint: canHint
                      ? () => showHintDialog(context, controller.getHint())
                      : null,
                  onUndo: canUndo ? controller.undo : null,
                  onReset: busy
                      ? null
                      : () => _confirmReset(context, controller),
                ),
                moveList: _MoveList(sanHistory: state.sanHistory),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    GameController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar partida?'),
        content: const Text('O progresso atual desta partida será perdido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.reset();
    }
  }

  void _showGameOverDialog(BuildContext context, GameState state) {
    final message = switch (state.result) {
      GameResult.vitoriaBrancas => 'Xeque-mate! Brancas vencem.',
      GameResult.vitoriaPretas => 'Xeque-mate! Pretas vencem.',
      GameResult.empate => 'Empate.',
      GameResult.emAndamento => '',
    };
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fim de jogo'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveGameLayout extends StatelessWidget {
  const _ResponsiveGameLayout({
    required this.constraints,
    required this.board,
    required this.status,
    required this.actions,
    required this.moveList,
  });

  final BoxConstraints constraints;
  final Widget board;
  final Widget status;
  final Widget actions;
  final Widget moveList;

  @override
  Widget build(BuildContext context) {
    final landscape = constraints.maxWidth > constraints.maxHeight;
    final useSidePanel = landscape && constraints.maxWidth >= 620;

    if (useSidePanel) {
      final panelWidth = (constraints.maxWidth * 0.42)
          .clamp(280.0, 420.0)
          .toDouble();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: board),
          const SizedBox(width: 16),
          SizedBox(
            width: panelWidth,
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    status,
                    const SizedBox(height: 8),
                    actions,
                    const SizedBox(height: 12),
                    moveList,
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Em retrato a largura normalmente limita o tabuleiro. A lista é também
    // a contenção de emergência para aparelhos baixos e fontes ampliadas.
    return Scrollbar(
      child: ListView(
        children: [
          status,
          const SizedBox(height: 8),
          actions,
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: board,
            ),
          ),
          const SizedBox(height: 12),
          moveList,
        ],
      ),
    );
  }
}

class _StatusBar extends ConsumerWidget {
  const _StatusBar({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    if (state.engineError != null) {
      return ErrorStateCard(
        message: state.engineError!,
        onRetry: () => ref.read(gameControllerProvider.notifier).reset(),
      );
    }

    final whiteToMove = state.position.turn == Side.white;
    final turnLabel = whiteToMove ? 'Brancas jogam' : 'Pretas jogam';
    final activity = state.aiThinking
        ? 'Maia está pensando…'
        : state.hintThinking
        ? 'Calculando dica…'
        : 'Sua vez de escolher um lance';

    return Semantics(
      key: const Key('turn-status'),
      liveRegion: true,
      label: '$turnLabel${state.position.isCheck ? ', xeque' : ''}',
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colors.surfaceContainerHighest.withValues(alpha: 0.62),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: whiteToMove
                          ? Colors.white
                          : const Color(0xFF202124),
                      border: Border.all(
                        color: whiteToMove
                            ? const Color(0xFF424242)
                            : Colors.white70,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          turnLabel,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        AnimatedSwitcher(
                          duration: AppMotion.fast,
                          switchInCurve: AppMotion.curve,
                          switchOutCurve: AppMotion.curve,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Text(
                            activity,
                            key: ValueKey(activity),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.aiThinking || state.hintThinking)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  if (state.position.isCheck) ...[
                    const SizedBox(width: 8),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Xeque',
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                      backgroundColor: colors.errorContainer,
                      side: BorderSide.none,
                    ),
                  ],
                  if (!state.evaluated) ...[
                    const SizedBox(width: 8),
                    const Tooltip(
                      message: 'Dicas ou desfazer retiram a partida do rating',
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('Não avaliada'),
                      ),
                    ),
                  ],
                ],
              ),
              if (state.persistenceError != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: colors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.persistenceError!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GameActions extends StatelessWidget {
  const _GameActions({
    required this.showHint,
    required this.onHint,
    required this.onUndo,
    required this.onReset,
  });

  final bool showHint;
  final VoidCallback? onHint;
  final VoidCallback? onUndo;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (showHint)
        FilledButton.tonalIcon(
          onPressed: onHint,
          icon: const Icon(Icons.lightbulb_outline, size: 21),
          label: const Text('Dica'),
        ),
      OutlinedButton.icon(
        onPressed: onUndo,
        icon: const Icon(Icons.undo, size: 21),
        label: const Text('Desfazer'),
      ),
      TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: onReset,
        icon: const Icon(Icons.restart_alt, size: 21),
        label: const Text('Reiniciar'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final availablePerButton =
            (constraints.maxWidth - (actions.length - 1) * spacing) /
            actions.length;
        final buttonWidth = availablePerButton >= 112
            ? availablePerButton
            : (constraints.maxWidth >= 232
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth);

        return Wrap(
          key: const Key('game-actions'),
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map(
                (action) =>
                    SizedBox(width: buttonWidth, height: 48, child: action),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _MoveList extends StatelessWidget {
  const _MoveList({required this.sanHistory});

  final List<String> sanHistory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pairs = <({int number, String white, String black})>[];
    for (var i = 0; i < sanHistory.length; i += 2) {
      pairs.add((
        number: (i ~/ 2) + 1,
        white: sanHistory[i],
        black: i + 1 < sanHistory.length ? sanHistory[i + 1] : '—',
      ));
    }

    return Semantics(
      key: const Key('move-list-panel'),
      container: true,
      label: 'Histórico de jogadas',
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.format_list_numbered,
                    size: 20,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Jogadas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${sanHistory.length} ${sanHistory.length == 1 ? 'lance' : 'lances'}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (pairs.isEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 108),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports_esports_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ainda não houve nenhum lance.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              ColoredBox(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(width: 36, child: Text('Nº')),
                      Expanded(child: Text('Brancas')),
                      Expanded(child: Text('Pretas')),
                    ],
                  ),
                ),
              ),
              for (final pair in pairs)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${pair.number}.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          pair.white,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          pair.black,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
