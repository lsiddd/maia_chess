import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theming/app_theme.dart';
import 'data/providers.dart';
import 'data/repositories/game_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/difficulty/presentation/campaign_screen.dart';
import 'features/difficulty/presentation/new_game_vs_ai_screen.dart';
import 'features/game/application/game_controller.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/stats/presentation/stats_screen.dart';

void main() {
  runApp(const ProviderScope(child: MaiaChessApp()));
}

class MaiaChessApp extends ConsumerWidget {
  const MaiaChessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storedTheme = ref.watch(appSettingsProvider).valueOrNull?.themeMode;
    return MaterialApp(
      title: 'Xadrez Maia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (storedTheme) {
        StoredThemeMode.light => ThemeMode.light,
        StoredThemeMode.dark => ThemeMode.dark,
        StoredThemeMode.system || null => ThemeMode.system,
      },
      home: const HomeScreen(),
    );
  }
}

/// Tela inicial com os modos livre/campanha e os dados locais do jogador.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGame = ref.watch(activeGameProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Xadrez Maia')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          const Text(
            'Xadrez offline contra IA de estilo humano (Maia)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          if (activeGame.valueOrNull != null) ...[
            FilledButton.icon(
              onPressed: () => _resume(context, ref),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Continuar partida salva'),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CampaignScreen())),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Campanha Maia'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => _openNewAiGame(context, ref),
            icon: const Icon(Icons.psychology_outlined),
            label: const Text('Modo livre contra a IA'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _startLocalGame(context, ref),
            icon: const Icon(Icons.sports_esports_outlined),
            label: const Text('Jogar (2 jogadores locais)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Meu desempenho'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
            icon: const Icon(Icons.history),
            label: const Text('Partidas salvas e PGN'),
          ),
          if (activeGame.hasError) ...[
            const SizedBox(height: 12),
            Text(
              'Falha ao verificar autosave: ${activeGame.error}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(gameControllerProvider.notifier);
    final restored = await controller.restoreActiveGame();
    if (!context.mounted) return;
    if (!restored) {
      final state = ref.read(gameControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.persistenceError ??
                state.engineError ??
                'Não há partida para continuar.',
          ),
        ),
      );
      return;
    }
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GameScreen())),
    );
  }

  Future<void> _openNewAiGame(BuildContext context, WidgetRef ref) async {
    if (!await _confirmReplacingActiveGame(context, ref)) return;
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NewGameVsAiScreen()));
  }

  Future<void> _startLocalGame(BuildContext context, WidgetRef ref) async {
    if (!await _confirmReplacingActiveGame(context, ref)) return;
    await ref.read(gameControllerProvider.notifier).startTwoPlayers();
    if (!context.mounted) return;
    final error = ref.read(gameControllerProvider).persistenceError;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  Future<bool> _confirmReplacingActiveGame(
    BuildContext context,
    WidgetRef ref,
  ) async {
    StoredGame? active;
    try {
      active = await ref.read(gameRepositoryProvider).getActiveGame();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao verificar autosave: $error')),
        );
      }
      return false;
    }
    if (active == null || !context.mounted) return active == null;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Substituir partida em andamento?'),
            content: const Text(
              'Ao iniciar outra partida, o autosave atual será removido. '
              'Você pode voltar e continuá-lo pela tela inicial.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Substituir'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
