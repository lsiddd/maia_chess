import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theming/app_page_route.dart';
import '../../../core/theming/app_theme.dart';
import '../../../core/widgets/error_state_card.dart';
import '../../../core/widgets/max_width_body.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/game_repository.dart';
import '../../game/presentation/chess_board_widget.dart';
import '../../pgn/application/pgn_service.dart';
import '../../review/presentation/game_review_screen.dart';
import '../domain/game_replayer.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _importing = false;
  final _busyGameIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(gameLibraryProvider);
    final page = ref.watch(gameLibraryPageProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved games'),
        actions: [
          IconButton(
            tooltip: 'Import PGN',
            onPressed: _importing ? null : _importPgn,
            icon: _importing
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open_outlined),
          ),
        ],
      ),
      bottomNavigationBar:
          page > 0 || (library.valueOrNull?.length ?? 0) > gameLibraryPageSize
          ? _LibraryBottomBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.l,
                  vertical: AppSpacing.s,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous page',
                      onPressed: page == 0 || library.isLoading
                          ? null
                          : () =>
                                ref
                                        .read(gameLibraryPageProvider.notifier)
                                        .state =
                                    page - 1,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        'Page ${page + 1}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next page',
                      onPressed:
                          library.isLoading ||
                              library.hasError ||
                              (library.valueOrNull?.length ?? 0) <=
                                  gameLibraryPageSize
                          ? null
                          : () =>
                                ref
                                        .read(gameLibraryPageProvider.notifier)
                                        .state =
                                    page + 1,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: MaxWidthBody(
        child: library.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading saved games',
            ),
          ),
          error: (error, stackTrace) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: ErrorStateCard(
                message:
                    'Your saved games could not be loaded. Please try again.',
                onRetry: () => ref.invalidate(gameLibraryProvider),
              ),
            ),
          ),
          data: (games) {
            if (games.isEmpty) {
              return _LibraryEmptyState(
                laterPage: page > 0,
                importing: _importing,
                onImport: _importPgn,
                onPrevious: () =>
                    ref.read(gameLibraryPageProvider.notifier).state = page - 1,
              );
            }
            return ListView.separated(
              key: ValueKey('game-library-page-$page'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                AppSpacing.xxl,
              ),
              itemCount: games.length.clamp(0, gameLibraryPageSize) + 1,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.m),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return to every move.',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Text(
                          'Replay, review or share your games.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }
                final game = games[index - 1];
                final colors = Theme.of(context).colorScheme;
                return Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      AppPageRoute(
                        builder: (_) => ReplayScreen(gameId: game.id),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.l,
                        AppSpacing.l,
                        AppSpacing.s,
                        AppSpacing.l,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _title(game),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.s),
                                Text(
                                  _subtitle(game),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.m),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: AppSpacing.s,
                                  children: [
                                    Icon(
                                      game.status == StoredGameStatus.ongoing
                                          ? Icons.bookmark_outline
                                          : Icons.check_circle_outline,
                                      size: 16,
                                      color: colors.primary,
                                    ),
                                    Text(
                                      game.status == StoredGameStatus.ongoing
                                          ? 'Saved in progress'
                                          : 'Open replay',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(color: colors.primary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<_HistoryAction>(
                            tooltip: 'Game options',
                            enabled: !_busyGameIds.contains(game.id),
                            onSelected: (action) => _handleAction(game, action),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: _HistoryAction.export,
                                child: Text('Export PGN'),
                              ),
                              PopupMenuItem(
                                value: _HistoryAction.delete,
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _importPgn() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final source = await const PgnFileService().pickPgn();
      if (source == null || !mounted) return;
      final game = await const PgnService().parseImportAsync(
        pgn: source,
        id: ref.read(gameIdFactoryProvider)(),
        importedAtUtc: DateTime.now().toUtc(),
      );
      if (!mounted) return;
      await ref.read(gameRepositoryProvider).importGame(game);
      if (!mounted) return;
      ref.read(gameLibraryPageProvider.notifier).state = 0;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game imported. Ready to replay.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not import: $error')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _handleAction(StoredGame game, _HistoryAction action) async {
    if (_busyGameIds.contains(game.id)) return;
    setState(() => _busyGameIds.add(game.id));
    try {
      switch (action) {
        case _HistoryAction.export:
          await const PgnFileService().sharePgn(
            gameId: game.id,
            pgn: game.pgn ?? const PgnService().export(game),
          );
        case _HistoryAction.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete game?'),
              content: const Text(
                'This action cannot be undone. Rating, streaks, and '
                'campaign progress will be rebuilt without this game.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed != true || !mounted) return;
          await ref.read(gameRepositoryProvider).deleteGame(game.id);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Game deleted.')));
      }
    } catch (error) {
      if (!mounted) return;
      final operation = action == _HistoryAction.delete ? 'delete' : 'export';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not $operation the game: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyGameIds.remove(game.id));
    }
  }

  String _title(StoredGame game) {
    final mode = game.levelRating == null
        ? 'Local game'
        : 'Against Maia-3 ${game.levelRating}';
    if (game.status == StoredGameStatus.ongoing) return '$mode — ongoing';
    return '$mode — ${_resultLabel(game.result)}';
  }

  String _subtitle(StoredGame game) {
    final date = game.lastModifiedAtUtc.toLocal();
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    final evaluated =
        game.evaluated && game.levelRating != null && game.playerSide != null
        ? 'rated'
        : 'unrated';
    return '$formatted • ${game.moves.length} moves • $evaluated';
  }
}

class ReplayScreen extends ConsumerStatefulWidget {
  const ReplayScreen({required this.gameId, super.key});

  final String gameId;

  @override
  ConsumerState<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends ConsumerState<ReplayScreen> {
  late Future<StoredGame?> _game;

  @override
  void initState() {
    super.initState();
    _game = ref.read(gameRepositoryProvider).getGame(widget.gameId);
  }

  @override
  void didUpdateWidget(covariant ReplayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId) {
      _game = ref.read(gameRepositoryProvider).getGame(widget.gameId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoredGame?>(
      future: _game,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Replay')),
            body: const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading replay',
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Replay')),
            body: MaxWidthBody(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: ErrorStateCard(
                    message: 'This game could not be opened.',
                    onRetry: () {
                      final game = ref
                          .read(gameRepositoryProvider)
                          .getGame(widget.gameId);
                      setState(() {
                        _game = game;
                      });
                    },
                  ),
                ),
              ),
            ),
          );
        }
        final game = snapshot.data;
        if (game == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Replay')),
            body: const Center(child: Text('Game not found.')),
          );
        }
        try {
          return _ReplayView(game: game);
        } catch (error) {
          return Scaffold(
            appBar: AppBar(title: const Text('Replay')),
            body: const MaxWidthBody(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.l),
                  child: ErrorStateCard(
                    message:
                        'This game contains invalid moves and cannot be replayed.',
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

class _ReplayView extends StatefulWidget {
  _ReplayView({required this.game})
    : replayed = const GameReplayer().replay(game);

  final StoredGame game;
  final ReplayedGame replayed;

  @override
  State<_ReplayView> createState() => _ReplayViewState();
}

class _ReplayViewState extends State<_ReplayView> {
  int _ply = 0;
  bool _exporting = false;

  @override
  void didUpdateWidget(covariant _ReplayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ply = oldWidget.game.id == widget.game.id
        ? _ply.clamp(0, widget.replayed.positions.length - 1)
        : 0;
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final position = widget.replayed.positions[_ply];
    final orientation = game.playerSide ?? Side.white;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Replay'),
        actions: [
          IconButton(
            tooltip: 'Export PGN',
            onPressed: _exporting
                ? null
                : () async {
                    setState(() => _exporting = true);
                    try {
                      await const PgnFileService().sharePgn(
                        gameId: game.id,
                        pgn: game.pgn ?? const PgnService().export(game),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to export: $error')),
                      );
                    } finally {
                      if (mounted) setState(() => _exporting = false);
                    }
                  },
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Preparing PGN',
                    ),
                  )
                : const Icon(Icons.share_outlined),
          ),
        ],
      ),
      bottomNavigationBar: _LibraryBottomBar(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _ply == 0
                    ? 'Starting position'
                    : '${widget.replayed.positions[_ply - 1].fullmoves}${widget.replayed.positions[_ply - 1].turn == Side.white ? '.' : '...'} ${game.moves[_ply - 1].san}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Move $_ply of ${game.moves.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Start',
                    onPressed: _ply == 0
                        ? null
                        : () => setState(() => _ply = 0),
                    icon: const Icon(Icons.first_page),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Previous',
                    onPressed: _ply == 0 ? null : () => setState(() => _ply--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Next',
                    onPressed: _ply == game.moves.length
                        ? null
                        : () => setState(() => _ply++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  IconButton(
                    tooltip: 'End',
                    onPressed: _ply == game.moves.length
                        ? null
                        : () => setState(() => _ply = game.moves.length),
                    icon: const Icon(Icons.last_page),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.xl,
          ),
          children: [
            Text(
              game.levelRating == null
                  ? 'Local game'
                  : 'Against Maia ${game.levelRating}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _resultLabel(game.result),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: StaticChessBoardWidget(
                  position: position,
                  orientation: orientation,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            if (game.status == StoredGameStatus.completed &&
                game.moves.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.l),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => GameReviewScreen(
                      game: game,
                      replayed: widget.replayed,
                      initialPly: _ply,
                    ),
                  ),
                ),
                icon: const Icon(Icons.insights_outlined),
                label: const Text('Review game'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({
    required this.laterPage,
    required this.importing,
    required this.onImport,
    required this.onPrevious,
  });

  final bool laterPage;
  final bool importing;
  final VoidCallback onImport;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 36,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              laterPage
                  ? 'You have reached the end.'
                  : 'A home for your games.',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              laterPage
                  ? 'Return to the previous page to keep exploring.'
                  : 'Your games are saved automatically. You can also import a PGN to replay a game move by move.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: laterPage
                  ? onPrevious
                  : importing
                  ? null
                  : onImport,
              icon: Icon(
                laterPage ? Icons.chevron_left : Icons.file_open_outlined,
              ),
              label: Text(
                laterPage
                    ? 'Previous page'
                    : importing
                    ? 'Importing…'
                    : 'Import PGN',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HistoryAction { export, delete }

String _resultLabel(StoredGameResult result) => switch (result) {
  StoredGameResult.whiteWin => 'White wins',
  StoredGameResult.blackWin => 'Black wins',
  StoredGameResult.draw => 'draw',
  StoredGameResult.ongoing => 'ongoing',
  StoredGameResult.unknown => 'result not specified',
};

class _LibraryBottomBar extends StatelessWidget {
  const _LibraryBottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Align(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: child,
      ),
    ),
  );
}
