import 'package:flutter/material.dart';

import '../domain/hint_result.dart';

/// Mostra a dica dupla (seção 5 da especificação) para a consulta já iniciada
/// pelo callback do botão e exibe o resultado lado a lado.
Future<void> showHintDialog(
  BuildContext context,
  Future<HintResult> hintFuture,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _HintDialog(hintFuture: hintFuture),
  );
}

class _HintDialog extends StatelessWidget {
  const _HintDialog({required this.hintFuture});

  final Future<HintResult> hintFuture;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dica'),
      content: FutureBuilder<HintResult>(
        future: hintFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 96,
              width: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              width: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Não foi possível calcular a dica.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            );
          }
          final hint = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HintRow(
                icon: Icons.psychology_outlined,
                label: 'Estilo Maia ${hint.levelRating}',
                move: hint.maiaSan,
              ),
              const SizedBox(height: 16),
              _HintRow(
                icon: Icons.emoji_events_outlined,
                label: 'Melhor lance (Stockfish)',
                move: hint.stockfishSan,
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.label, required this.move});

  final IconData icon;
  final String label;
  final String move;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(move, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ],
    );
  }
}
