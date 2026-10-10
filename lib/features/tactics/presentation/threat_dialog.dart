import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../domain/tactical_analysis.dart';

Future<void> showThreatDialog(
  BuildContext context,
  Future<ThreatResult> analysis, {
  required Future<void> Function() onClosed,
}) async {
  analysis.ignore();
  try {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Top 3 ameaças'),
        scrollable: true,
        content: SizedBox(
          width: 360,
          child: FutureBuilder<ThreatResult>(
            future: analysis,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Stockfish está analisando as ameaças…'),
                  ],
                );
              }
              if (snapshot.hasError) {
                return const Text(
                  'Não foi possível concluir a análise. '
                  'Feche e tente novamente.',
                );
              }
              final result = snapshot.requireData;
              final side = result.position.turn == Side.white
                  ? 'brancas'
                  : 'pretas';
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('O que as $side poderiam jogar se você passasse a vez.'),
                  const SizedBox(height: 8),
                  const Text(
                    'São alternativas, não uma sequência de lances. '
                    'Sua próxima jogada pode mudar essas ameaças.',
                  ),
                  const SizedBox(height: 16),
                  if (result.threats.isEmpty)
                    const Text('O adversário não teria lances legais.'),
                  for (final threat in result.threats)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            child: Text('${threat.line.rank}'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  threat.san,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  '${threat.move.from.name} → '
                                  '${threat.move.to.name}',
                                ),
                                Text(
                                  '${threat.scoreLabel} • '
                                  'Profundidade ${threat.line.depth}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (result.threats.isNotEmpty)
                    const Text(
                      'Avaliação na perspectiva do adversário: '
                      'positivo favorece o adversário; negativo favorece você. '
                      'Análise rápida do Stockfish (1 s).',
                    ),
                  if (result.threats.length == 1 || result.threats.length == 2)
                    const Text('Há menos de três variantes disponíveis.'),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  } finally {
    await onClosed();
  }
}
