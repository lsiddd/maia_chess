import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/difficulty_levels.dart';
import '../../../core/theming/app_page_route.dart';
import '../../../core/theming/app_theme.dart';
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
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(
                    icon: Icons.swap_horiz,
                    label: 'Seu lado',
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SegmentedButton<Side>(
                    segments: const [
                      ButtonSegment(value: Side.white, label: Text('Brancas')),
                      ButtonSegment(value: Side.black, label: Text('Pretas')),
                    ],
                    selected: {_humanSide},
                    onSelectionChanged: (selection) =>
                        setState(() => _humanSide = selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(
                    icon: Icons.psychology_outlined,
                    label: 'Nível (estilo Maia)',
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Wrap(
                    spacing: AppSpacing.s,
                    runSpacing: AppSpacing.s,
                    children: DifficultyLevel.all.map((level) {
                      final selected = level.rating == _levelRating;
                      return ChoiceChip(
                        label: Text('${level.rating}'),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _levelRating = level.rating),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _starting ? null : _start,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _starting
                  ? const SizedBox(
                      key: ValueKey('starting-spinner'),
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Começar partida', key: ValueKey('starting-label')),
            ),
          ),
          if (_starting) ...[
            const SizedBox(height: AppSpacing.m),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: AppSpacing.s),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
