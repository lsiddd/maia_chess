import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../data/repositories/game_repository.dart';
import '../../game/presentation/chess_board_widget.dart';
import '../../pgn/application/pgn_service.dart';
import '../domain/game_replayer.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(gameLibraryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partidas salvas'),
        actions: [
          IconButton(
            tooltip: 'Importar PGN',
            onPressed: () => _importPgn(context, ref),
            icon: const Icon(Icons.file_open_outlined),
          ),
        ],
      ),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LibraryError(error: error),
        data: (games) {
          if (games.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma partida salva.\n'
                  'As partidas em andamento são salvas automaticamente.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: games.length,
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
                    MaterialPageRoute(
                      builder: (_) => ReplayScreen(gameId: game.id),
                    ),
                  ),
                  trailing: PopupMenuButton<_HistoryAction>(
                    onSelected: (action) =>
                        _handleAction(context, ref, game, action),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _HistoryAction.export,
                        child: Text('Exportar PGN'),
                      ),
                      PopupMenuItem(
                        value: _HistoryAction.delete,
                        child: Text('Excluir'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _importPgn(BuildContext context, WidgetRef ref) async {
    try {
      final source = await const PgnFileService().pickPgn();
      if (source == null || !context.mounted) return;
      final game = const PgnService().parseImport(
        pgn: source,
        id: ref.read(gameIdFactoryProvider)(),
        importedAtUtc: DateTime.now().toUtc(),
      );
      await ref.read(gameRepositoryProvider).importGame(game);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PGN importado e validado.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível importar: $error')),
      );
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    StoredGame game,
    _HistoryAction action,
  ) async {
    switch (action) {
      case _HistoryAction.export:
        try {
          await const PgnFileService().sharePgn(
            gameId: game.id,
            pgn: game.pgn ?? const PgnService().export(game),
          );
        } catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao exportar PGN: $error')),
          );
        }
      case _HistoryAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir partida?'),
            content: const Text(
              'Essa ação não pode ser desfeita. Rating, sequências e '
              'progresso da campanha serão reconstruídos sem esta partida.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(gameRepositoryProvider).deleteGame(game.id);
        }
    }
  }

  String _title(StoredGame game) {
    final mode = game.levelRating == null
        ? 'Partida local'
        : 'Contra Maia ${game.levelRating}';
    if (game.status == StoredGameStatus.ongoing) return '$mode — em andamento';
    return '$mode — ${_resultLabel(game.result)}';
  }

  String _subtitle(StoredGame game) {
    final date = game.lastModifiedAtUtc.toLocal();
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    final evaluated = game.evaluated ? 'avaliada' : 'não avaliada';
    return '$formatted • ${game.moves.length} lances • $evaluated';
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
            appBar: AppBar(title: const Text('Reprodução')),
            body: Center(child: Text('Falha ao abrir: ${snapshot.error}')),
          );
        }
        final game = snapshot.data;
        if (game == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Reprodução')),
            body: const Center(child: Text('Partida não encontrada.')),
          );
        }
        try {
          return _ReplayView(game: game);
        } catch (error) {
          return Scaffold(
            appBar: AppBar(title: const Text('Reprodução')),
            body: Center(child: Text('Partida corrompida: $error')),
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
  Widget build(BuildContext context) {
    final game = widget.game;
    final position = widget.replayed.positions[_ply];
    final orientation = game.playerSide ?? Side.white;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reprodução'),
        actions: [
          IconButton(
            tooltip: 'Exportar PGN',
            onPressed: () async {
              try {
                await const PgnFileService().sharePgn(
                  gameId: game.id,
                  pgn: game.pgn ?? const PgnService().export(game),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Falha ao exportar: $error')),
                );
              }
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Início',
                  onPressed: _ply == 0 ? null : () => setState(() => _ply = 0),
                  icon: const Icon(Icons.first_page),
                ),
                IconButton(
                  tooltip: 'Anterior',
                  onPressed: _ply == 0 ? null : () => setState(() => _ply--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Lance $_ply de ${game.moves.length}'),
                IconButton(
                  tooltip: 'Próximo',
                  onPressed: _ply == game.moves.length
                      ? null
                      : () => setState(() => _ply++),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: 'Final',
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
                  '${_ply.isOdd ? '${(_ply + 1) ~/ 2}.' : '${_ply ~/ 2}...'} '
                  '${game.moves[_ply - 1].san}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Não foi possível abrir a biblioteca: $error'),
      ),
    );
  }
}

enum _HistoryAction { export, delete }

String _resultLabel(StoredGameResult result) => switch (result) {
  StoredGameResult.whiteWin => 'vitória das brancas',
  StoredGameResult.blackWin => 'vitória das pretas',
  StoredGameResult.draw => 'empate',
  StoredGameResult.ongoing => 'em andamento',
  StoredGameResult.unknown => 'resultado não informado',
};
