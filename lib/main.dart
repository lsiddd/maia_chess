import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/board_assets.dart';
import 'core/constants/chess_asset_licenses.dart';
import 'core/constants/piece_assets.dart';
import 'core/theming/app_page_route.dart';
import 'core/theming/app_theme.dart';
import 'core/theming/board_theme.dart';
import 'core/widgets/error_state_card.dart';
import 'core/widgets/max_width_body.dart';
import 'data/providers.dart';
import 'data/repositories/game_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/difficulty/presentation/campaign_screen.dart';
import 'features/difficulty/presentation/new_game_vs_ai_screen.dart';
import 'features/game/application/game_controller.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/settings/presentation/appearance_screen.dart';
import 'features/stats/presentation/stats_screen.dart';

void main() {
  registerChessAssetLicenses();
  runApp(const ProviderScope(child: MaiaChessApp()));
}

class MaiaChessApp extends ConsumerWidget {
  const MaiaChessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final storedTheme = settings?.themeMode;
    final boardTheme = settings?.boardTheme ?? BoardTheme.brown;
    return MaterialApp(
      title: 'Maia Chess',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightFor(boardTheme),
      darkTheme: AppTheme.darkFor(boardTheme),
      themeMode: switch (storedTheme) {
        StoredThemeMode.light => ThemeMode.light,
        StoredThemeMode.dark => ThemeMode.dark,
        StoredThemeMode.system || null => ThemeMode.system,
      },
      home: const HomeScreen(),
    );
  }
}

/// Home screen for free play, campaign, and local player data.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _precachedChessAssets = false;
  bool _openingGame = false;

  Future<void> _openGame(Future<void> Function() open) async {
    if (_openingGame || !mounted) return;
    setState(() => _openingGame = true);
    try {
      await open();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the game: $error')),
      );
    } finally {
      if (mounted) setState(() => _openingGame = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache pieces and boards on the menu so decoding does not fall on the
    // first game frame or drag.
    if (_precachedChessAssets) return;
    _precachedChessAssets = true;
    unawaited(precachePieceSvgs(context));
    unawaited(precacheBoardImages(context));
  }

  @override
  Widget build(BuildContext context) {
    final activeGame = ref.watch(activeGameProvider);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maia Chess'),
        actions: [
          IconButton(
            tooltip: 'Appearance',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(AppPageRoute(builder: (_) => const AppearanceScreen())),
          ),
        ],
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            _HomeHeader(colors: colors),
            const SizedBox(height: AppSpacing.xl),
            if (activeGame.valueOrNull != null) ...[
              FilledButton.icon(
                onPressed: _openingGame
                    ? null
                    : () => _openGame(() => _resume(context, ref)),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Continue saved game'),
              ),
              const SizedBox(height: AppSpacing.m),
            ],
            FilledButton.icon(
              onPressed: _openingGame
                  ? null
                  : () => _openGame(() async {
                      await Navigator.of(context).push(
                        AppPageRoute(builder: (_) => const CampaignScreen()),
                      );
                    }),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Maia campaign'),
            ),
            const SizedBox(height: AppSpacing.m),
            FilledButton.tonalIcon(
              onPressed: _openingGame
                  ? null
                  : () => _openGame(() => _openNewAiGame(context, ref)),
              icon: const Icon(Icons.psychology_outlined),
              label: const Text('Free play against Maia'),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'More options',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.s),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.sports_esports_outlined),
                    title: const Text('Play (2 local players)'),
                    onTap: _openingGame
                        ? null
                        : () => _openGame(() => _startLocalGame(context, ref)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.insights_outlined),
                    title: const Text('My performance'),
                    onTap: () => Navigator.of(
                      context,
                    ).push(AppPageRoute(builder: (_) => const StatsScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Saved games and PGN'),
                    onTap: () => Navigator.of(
                      context,
                    ).push(AppPageRoute(builder: (_) => const HistoryScreen())),
                  ),
                ],
              ),
            ),
            if (activeGame.hasError) ...[
              const SizedBox(height: AppSpacing.m),
              ErrorStateCard(
                message: 'Failed to check autosave: ${activeGame.error}',
                onRetry: () => ref.invalidate(activeGameProvider),
              ),
            ],
          ],
        ),
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
                'There is no game to continue.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(
      context,
    ).push(AppPageRoute(builder: (_) => const GameScreen()));
  }

  Future<void> _openNewAiGame(BuildContext context, WidgetRef ref) async {
    if (!await _confirmReplacingActiveGame(context, ref)) return;
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(AppPageRoute(builder: (_) => const NewGameVsAiScreen()));
  }

  Future<void> _startLocalGame(BuildContext context, WidgetRef ref) async {
    if (!await _confirmReplacingActiveGame(context, ref)) return;
    if (!context.mounted) return;
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
    ).push(AppPageRoute(builder: (_) => const GameScreen()));
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
          SnackBar(content: Text('Failed to check autosave: $error')),
        );
      }
      return false;
    }
    if (active == null || !context.mounted) return active == null;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Replace the ongoing game?'),
            content: const Text(
              'Starting another game will remove the current autosave. '
              'You can go back and continue it from the home screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl - 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryContainer, colors.tertiaryContainer],
        ),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(
              Icons.castle_outlined,
              color: colors.onPrimary,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maia Chess',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: AppTypography.accentFontFamily,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text('Offline chess against a human-style AI (Maia)'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
