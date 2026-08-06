import 'package:flutter/material.dart';

/// Cartão de erro reutilizado em toda tela com dados assíncronos: ícone +
/// mensagem sobre `errorContainer`, com uma ação opcional de nova
/// tentativa. Extraído do padrão que antes só existia em `_StatusBar`
/// (`game_screen.dart`) para as demais telas (campanha, estatísticas,
/// biblioteca de partidas) pararem de mostrar só texto cru em erro.
class ErrorStateCard extends StatelessWidget {
  const ErrorStateCard({
    required this.message,
    super.key,
    this.onRetry,
    this.retryLabel = 'Tentar de novo',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: colors.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ],
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
