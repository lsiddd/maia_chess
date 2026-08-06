import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/difficulty_levels.dart';
import '../../../core/theming/app_page_route.dart';
import '../../game/application/game_controller.dart';
import '../../game/presentation/game_screen.dart';

/// Tela de configuração de uma partida contra a IA Maia: escolha de lado
/// (seção 5.1 da especificação) e nível de dificuldade em modo livre
/// (seção 4 — modo campanha fica para a Fase 5).
class NewGameVsAiScreen extends ConsumerStatefulWidget {
  const NewGameVsAiScreen({super.key});

  @override
  ConsumerState<NewGameVsAiScreen> createState() => _NewGameVsAiScreenState();
}

class _NewGameVsAiScreenState extends ConsumerState<NewGameVsAiScreen> {
  Side _humanSide = Side.white;
  int _levelRating = DifficultyLevel.all.first.rating;
  bool _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    final controller = ref.read(gameControllerProvider.notifier);
    try {
      final started = await controller.startVsAi(
        humanSide: _humanSide,
        levelRating: _levelRating,
      );
      if (!mounted) return;
      if (!started) {
        final error =
            ref.read(gameControllerProvider).engineError ??
            ref.read(gameControllerProvider).persistenceError ??
            'Não foi possível iniciar o motor Maia.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      unawaited(
        Navigator.of(
          context,
        ).push(AppPageRoute(builder: (_) => const GameScreen())),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jogar contra a IA Maia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Seu lado', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<Side>(
            segments: const [
              ButtonSegment(value: Side.white, label: Text('Brancas')),
              ButtonSegment(value: Side.black, label: Text('Pretas')),
            ],
            selected: {_humanSide},
            onSelectionChanged: (selection) =>
                setState(() => _humanSide = selection.first),
          ),
          const SizedBox(height: 24),
          Text(
            'Nível (estilo Maia)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DifficultyLevel.all.map((level) {
              final selected = level.rating == _levelRating;
              return ChoiceChip(
                label: Text('${level.rating}'),
                selected: selected,
                onSelected: (_) => setState(() => _levelRating = level.rating),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _starting ? null : _start,
            child: _starting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Começar partida'),
          ),
          if (_starting) ...[
            const SizedBox(height: 12),
            Text(
              'Carregando o peso do Maia $_levelRating... '
              'pode levar alguns segundos na primeira vez.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
