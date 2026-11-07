import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'features/game/presentation/time_control_picker.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/settings/presentation/appearance_screen.dart';
import 'features/stats/presentation/stats_screen.dart';
import 'core/widgets/home_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open your game. Please try again.'),
        ),
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
    final saved = activeGame.valueOrNull;
    final busy = _openingGame || activeGame.isLoading;
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
          const SizedBox(width: AppSpacing.s),
        ],
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.xl,
          ),
          children: [
            HomeHero(
              savedGame: saved,
              loading: activeGame.isLoading,
              opening: _openingGame,
              onPlay: busy
                  ? null
                  : () => _openGame(
                      () => saved == null
                          ? _openNewAiGame(context, ref)
                          : _resume(context, ref),
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const HomeSectionHeading(title: 'Find your next challenge'),
            const SizedBox(height: AppSpacing.m),
            if (saved != null) ...[
              HomeActionTile(
                icon: Icons.add_rounded,
                title: 'Free play against Maia-3',
                subtitle: 'Choose an opponent and play your way.',
                onTap: busy
                    ? null
                    : () => _openGame(() => _openNewAiGame(context, ref)),
              ),
              const SizedBox(height: AppSpacing.s),
            ],
            HomeActionTile(
              icon: Icons.flag_outlined,
              title: 'Maia-3 campaign',
              subtitle: 'Build your game, one level at a time.',
              onTap: busy
                  ? null
                  : () => _openGame(() async {
                      await Navigator.of(context).push(
                        AppPageRoute(builder: (_) => const CampaignScreen()),
                      );
                    }),
            ),
            const SizedBox(height: AppSpacing.s),
            HomeActionTile(
              icon: Icons.people_outline_rounded,
              title: 'Play (2 local players)',
              subtitle: 'Share the board with someone nearby.',
              onTap: busy
                  ? null
                  : () => _openGame(() => _startLocalGame(context, ref)),
            ),
            const SizedBox(height: AppSpacing.xl),
            const HomeSectionHeading(title: 'Your chess notebook'),
            const SizedBox(height: AppSpacing.m),
            Card(
              child: Column(
                children: [
                  HomeActionTile(
                    icon: Icons.insights_outlined,
                    title: 'My performance',
                    subtitle: 'Rating, results and progress',
                    outlined: false,
                    onTap: () => Navigator.of(
                      context,
                    ).push(AppPageRoute(builder: (_) => const StatsScreen())),
                  ),
                  const Divider(indent: 64, endIndent: AppSpacing.l),
                  HomeActionTile(
                    icon: Icons.book_outlined,
                    title: 'Saved games and PGN',
                    subtitle: 'Replay, review and learn',
                    outlined: false,
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
                message:
                    'Your saved game could not be loaded. Try again before starting a new game.',
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
    final timeControl = await showTimeControlDialog(context);
    if (timeControl == null || !context.mounted) return;
    await ref
        .read(gameControllerProvider.notifier)
        .startTwoPlayers(timeControl: timeControl);
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
