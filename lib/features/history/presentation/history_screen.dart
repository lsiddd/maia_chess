import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theming/app_page_route.dart';
import '../../../core/widgets/error_state_card.dart';
import '../../../core/widgets/max_width_body.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/game_repository.dart';
import '../../game/presentation/chess_board_widget.dart';
import '../../pgn/application/pgn_service.dart';
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              TextButton.icon(
                onPressed: page == 0
                    ? null
                    : () {
                        ref.read(gameLibraryPageProvider.notifier).state =
                            page - 1;
                      },
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
              Text('Page ${page + 1}'),
              TextButton.icon(
                onPressed: library.isLoading ||
                        library.hasError ||
                        (library.valueOrNull?.length ?? 0) <= gameLibraryPageSize
                    ? null
                    : () {
                        ref.read(gameLibraryPageProvider.notifier).state =
                            page + 1;
                      },
                label: const Text('Next'),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
      body: MaxWidthBody(
        child: library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorStateCard(
                message: 'Could not open the library: $error',
                onRetry: () => ref.invalidate(gameLibraryProvider),
              ),
            ),
          ),
          data: (games) {
            if (games.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    page == 0
                        ? 'No saved games.\nOngoing games are saved automatically.'
                        : 'No games on this page.\nGo back to the previous page.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              key: ValueKey('game-library-page-$page'),
              padding: const EdgeInsets.all(12),
              itemCount: games.length.clamp(0, gameLibraryPageSize),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final game = games[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      game.status == StoredGameStatus.ongoing
                          ? Icons.save_outlined
                          : Icons.sports_esports_outlined,
                    ),
                    title: Text(_title(game)),
                    subtitle: Text(_subtitle(game)),
                    onTap: () => Navigator.of(context).push(
                      AppPageRoute(
                        builder: (_) => ReplayScreen(gameId: game.id),
                      ),
                    ),
                    trailing: PopupMenuButton<_HistoryAction>(
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
        const SnackBar(content: Text('PGN imported and validated.')),
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

  Future<void> _handleAction(
    StoredGame game,
    _HistoryAction action,
  ) async {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Game deleted.')),
          );
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
        : 'Against Maia ${game.levelRating}';
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Replay')),
            body: Center(child: Text('Failed to open: ${snapshot.error}')),
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
            body: Center(child: Text('Corrupted game: $error')),
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
            onPressed: () async {
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
              }
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: MaxWidthBody(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: StaticChessBoardWidget(
                    position: position,
                    orientation: orientation,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text('Move $_ply of ${game.moves.length}')),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Start',
                    onPressed: _ply == 0
                        ? null
                        : () => setState(() => _ply = 0),
                    icon: const Icon(Icons.first_page),
                  ),
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: _ply == 0 ? null : () => setState(() => _ply--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
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
              if (_ply > 0)
                Center(
                  child: Text(
                    '${widget.replayed.positions[_ply - 1].fullmoves}'
                    '${widget.replayed.positions[_ply - 1].turn == Side.white ? '.' : '...'} '
                    '${game.moves[_ply - 1].san}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          ),
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
