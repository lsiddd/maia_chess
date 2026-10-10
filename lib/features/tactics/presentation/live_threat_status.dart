import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../game/application/game_state.dart';
import '../application/live_threat_controller.dart';
import 'threat_arrows.dart';

class LiveThreatStatus extends StatelessWidget {
  const LiveThreatStatus({
    super.key,
    required this.analysis,
    required this.game,
    required this.onRetry,
  });

  final LiveThreatState analysis;
  final GameState game;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String? message;
    if (analysis.paused) {
      message = 'Análise pausada.';
    } else if (game.isGameOver) {
      message = 'Partida encerrada.';
    } else if (game.position.isCheck) {
      message = 'As setas voltam após sair do xeque.';
    } else if (game.aiThinking || game.isAiTurn) {
      message = 'As setas voltam na sua vez.';
    } else if (game.hintThinking) {
      message = 'As setas voltam após a dica.';
    } else if (analysis.loading) {
      message = 'Atualizando setas com Stockfish…';
    } else if (analysis.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Não foi possível atualizar as ameaças.'),
          TextButton.icon(
            key: const Key('retry-opponent-threats'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      );
    } else if (analysis.result?.threats.isEmpty ?? true) {
      message = 'O adversário não tem lances nesta posição.';
    } else {
      message = null;
    }
    if (message != null) {
      return Semantics(
        liveRegion: true,
        child: Text(message, key: const Key('opponent-threat-status')),
      );
    }
    final threats = analysis.result!.threats;
    final side = game.position.turn.opposite == Side.white
        ? 'brancas'
        : 'pretas';
    return Column(
      key: const Key('opponent-threat-legend'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Opções das $side se você passasse a vez:'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (var i = 0; i < threats.length; i++)
              Semantics(
                label:
                    'Ameaça ${i + 1}: ${threats[i].san}, '
                    '${threats[i].move.from.name} para ${threats[i].move.to.name}, '
                    'avaliação ${threats[i].scoreLabel} do adversário',
                child: Tooltip(
                  message:
                      '${threats[i].move.from.name} → '
                      '${threats[i].move.to.name} · Profundidade '
                      '${threats[i].line.depth}',
                  child: ExcludeSemantics(
                    child: Chip(
                      avatar: CircleAvatar(
                        backgroundColor: threatArrowColors[i],
                        foregroundColor: Colors.black,
                        child: Text('${i + 1}'),
                      ),
                      label: Text(
                        '${threats[i].san} · ${threats[i].scoreLabel}',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
