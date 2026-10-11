import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/theming/app_page_route.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../hints/application/visual_hint_controller.dart';
import '../../settings/presentation/appearance_screen.dart';
import '../../tactics/application/live_threat_controller.dart';
import '../application/game_controller.dart';
import '../application/game_state.dart';
import 'board_accessibility.dart';
import 'chess_board_widget.dart';
import 'game_move_history.dart';
import 'game_toolbar.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});
  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  late final GameController _controller;
  late final LiveThreatController _plans;
  bool _flipped = false;
  int _planIndex = 0;
  String? _noticeText;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(gameControllerProvider.notifier);
    _plans = ref.read(liveThreatControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _plans.setPaused(state != AppLifecycleState.resumed);
    if (state != AppLifecycleState.resumed) {
      ref.read(visualHintProvider.notifier).clear();
      unawaited(_controller.cancelHint());
      unawaited(_controller.flushPersistence());
    }
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.cancelHint());
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;
    _noticeTimer?.cancel();
    setState(() => _noticeText = message);
    _noticeTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _noticeText = null);
    });
  }

  Future<void> _hint() async {
    if (ref.read(gameControllerProvider).isGameOver) {
      _notice('Partida encerrada: não há lance disponível.');
      return;
    }
    try {
      await ref.read(visualHintProvider.notifier).toggle();
    } on HintCancelledException {
      /* A posição ou a interação mudou. */
    } catch (_) {
      _notice(
        'Não foi possível calcular a dica. Toque em Dica para tentar novamente.',
      );
    }
  }

  Future<void> _settings({bool? attacks, bool? ownOnly}) async {
    try {
      final repository = ref.read(settingsRepositoryProvider);
      final current = await repository.get();
      await repository.save(
        current.copyWith(
          showAttackedPieces: attacks,
          ownAttackedPiecesOnly: ownOnly,
        ),
      );
    } catch (_) {
      _notice('Não foi possível salvar a preferência.');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider, (previous, next) {
      if (next.valueOrNull?.showAttackedPieces == true &&
          !ref.read(gameControllerProvider).isGameOver) {
        scheduleMicrotask(_controller.markAsNotEvaluated);
      }
    });
    final game = ref.watch(gameControllerProvider);
    final plans = ref.watch(liveThreatControllerProvider);
    final hint = ref.watch(visualHintProvider);
    final settings =
        ref.watch(appSettingsProvider).valueOrNull ?? const StoredAppSettings();
    final base = game.aiSide?.opposite ?? Side.white;
    final orientation = _flipped ? base.opposite : base;
    final candidates = plans.result?.threats ?? const [];
    final selectedPlan = candidates.isEmpty
        ? null
        : candidates[_planIndex % candidates.length];
    ref.listen<GameState>(gameControllerProvider, (previous, next) {
      if (_noticeText != null &&
          (previous?.position.fen != next.position.fen ||
              previous?.aiThinking != next.aiThinking)) {
        _noticeTimer?.cancel();
        setState(() => _noticeText = null);
      }
      if (previous?.position.fen != next.position.fen) _planIndex = 0;
      if (previous?.engineError != next.engineError &&
          next.engineError != null) {
        _notice(next.engineError!);
      }
      if (previous?.persistenceError != next.persistenceError &&
          next.persistenceError != null) {
        _notice(next.persistenceError!);
      }
      if (!(previous?.isGameOver ?? false) && next.isGameOver) {
        _notice(gameResultDescription(next));
      }
      if (previous?.gameId != next.gameId &&
          settings.showAttackedPieces &&
          !next.isGameOver) {
        scheduleMicrotask(_controller.markAsNotEvaluated);
      }
    });
    ref.listen<LiveThreatState>(liveThreatControllerProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        _notice(
          'Análise indisponível. Desative e ative Planos para tentar novamente.',
        );
      }
    });
    final busy = game.aiThinking;
    final toolbar = SizedBox(
      height: 64,
      child: Row(
        key: const Key('game-actions'),
        children: [
          GameToolButton(
            label: 'Desfazer',
            icon: Icons.undo,
            tooltip: game.campaignMode
                ? 'Desfazer: esta partida deixa de contar para a campanha'
                : 'Desfazer',
            onPressed: game.canUndo && !busy && !game.isGameOver
                ? _controller.undo
                : null,
          ),
          GameToolButton(
            key: const Key('hint-button'),
            label: 'Dica',
            icon: Icons.lightbulb_outline,
            active: hint != null,
            loading: game.hintThinking,
            tooltip:
                'Dica Stockfish: destaca apenas a peça; retira a avaliação',
            onPressed: game.isGameOver || (!busy && !game.isAiTurn)
                ? _hint
                : null,
          ),
          GameToolButton(
            key: const Key('toggle-attacked-pieces'),
            label: 'Ataques',
            icon: Icons.crop_free,
            active: settings.showAttackedPieces,
            onPressed: () {
              unawaited(_settings(attacks: !settings.showAttackedPieces));
              if (!settings.showAttackedPieces && !game.isGameOver) {
                unawaited(_controller.markAsNotEvaluated());
              }
            },
          ),
          GameToolButton(
            key: const Key('show-opponent-threats'),
            label: 'Planos',
            icon: Icons.trending_up,
            tooltip: 'Planos do adversário',
            active: plans.enabled,
            loading: plans.loading,
            onPressed: () {
              _planIndex = 0;
              _plans.setEnabled(!plans.enabled);
              if (!plans.enabled && game.position.isCheck) {
                _notice(
                  'Saia do xeque antes de consultar os planos do adversário.',
                );
              }
            },
          ),
          GameToolButton(
            label: 'Mais',
            icon: Icons.more_horiz,
            onPressed: _more,
          ),
        ],
      ),
    );
    final board = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: ChessBoardWidget(
          orientation: orientation,
          showAttackedPieces: settings.showAttackedPieces,
          attackedSide: settings.ownAttackedPiecesOnly
              ? game.aiSide?.opposite ?? game.position.turn
              : null,
          hintSquare: hint,
          threats: selectedPlan == null ? const [] : [selectedPlan],
        ),
      ),
    );
    final status = Row(
      children: [
        Expanded(
          child: _TurnStatus(
            game: game,
            onRetry: _controller.retryAiMove,
            notice: _noticeText,
          ),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: candidates.length > 1
              ? IconButton(
                  key: const Key('next-opponent-plan'),
                  tooltip: 'Próximo plano do adversário',
                  onPressed: () => setState(
                    () => _planIndex = (_planIndex + 1) % candidates.length,
                  ),
                  icon: FittedBox(
                    child: Text(
                      '${_planIndex % candidates.length + 1}/${candidates.length}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
    final history = GameMoveHistory(game: game, orientation: orientation);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(
          game.aiSide == null ? 'Partida local' : 'Maia ${game.levelRating}',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 620 &&
                  constraints.maxWidth > constraints.maxHeight) {
                return Row(
                  children: [
                    Expanded(child: board),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 300,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          status,
                          const SizedBox(height: 12),
                          toolbar,
                          history,
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  status,
                  Expanded(child: board),
                  toolbar,
                  history,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _more() async {
    final game = ref.read(gameControllerProvider);
    final settings =
        ref.read(appSettingsProvider).valueOrNull ?? const StoredAppSettings();
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in [
                ('flip', Icons.swap_vert, 'Girar tabuleiro'),
                ('save', Icons.save_outlined, 'Salvar partida'),
                ('settings', Icons.tune, 'Configurações'),
                (
                  'filter',
                  Icons.filter_alt_outlined,
                  settings.ownAttackedPiecesOnly
                      ? 'Ataques: mostrar todas as peças'
                      : 'Ataques: somente minhas peças',
                ),
                ('help', Icons.help_outline, 'Ajuda das ferramentas'),
                ('reset', Icons.restart_alt, 'Reiniciar'),
              ])
                ListTile(
                  leading: Icon(item.$2),
                  title: Text(item.$3),
                  onTap: () => Navigator.pop(context, item.$1),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  game.campaignMode
                      ? 'Dicas, ataques, planos e desfazer tornam a partida não avaliada: ela não conta para avançar na campanha.'
                      : 'A partida é salva automaticamente a cada lance. Ajudas e desfazer retiram a avaliação.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'flip':
        setState(() => _flipped = !_flipped);
      case 'save':
        await _controller.saveGame();
        final error = ref.read(gameControllerProvider).persistenceError;
        _notice(error ?? 'Partida salva.');
      case 'settings':
        await Navigator.of(
          context,
        ).push(AppPageRoute(builder: (_) => const AppearanceScreen()));
      case 'filter':
        await _settings(ownOnly: !settings.ownAttackedPiecesOnly);
      case 'help':
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ferramentas de partida'),
            content: const SingleChildScrollView(
              child: Text(
                'Dica: o contorno âmbar indica somente a peça sugerida pelo Stockfish. Toque novamente para ocultar.\n\n'
                'Ataques: borda laranja contínua indica peça atacada sem defesa geométrica; borda azul dupla indica atacada e defendida. Isso não garante ganho ou perda de material: cravadas e trocas exigem análise tática.\n\n'
                'Planos do adversário: uma seta mostra uma opção do Stockfish caso o adversário pudesse jogar agora. Não é uma ameaça comprovada. Use o contador para alternar.\n\n'
                'Desfazer: contra Maia, volta à sua decisão anterior; no modo local, volta um lance. Ajudas e desfazer retiram a avaliação e a validade na campanha.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      case 'reset':
        await _reset();
    }
  }

  Future<void> _reset() async {
    if (ref.read(gameControllerProvider).sanHistory.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reiniciar partida?'),
          content: const Text('O progresso atual desta partida será perdido.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reiniciar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _controller.reset();
  }
}

class _TurnStatus extends StatelessWidget {
  const _TurnStatus({required this.game, required this.onRetry, this.notice});
  final String? notice;
  final GameState game;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final turn =
        notice ??
        (game.isGameOver
            ? gameResultDescription(game)
            : game.engineError != null
            ? 'Maia indisponível'
            : game.position.isCheck
            ? 'Xeque'
            : game.aiSide == null
            ? (game.position.turn == Side.white
                  ? 'Brancas jogam'
                  : 'Pretas jogam')
            : game.isAiTurn
            ? 'Vez da Maia'
            : 'Sua vez');
    final mode = game.campaignMode
        ? 'Campanha'
        : game.aiSide == null
        ? 'Local'
        : 'Treino';
    return SizedBox(
      height: 52,
      child: Semantics(
        key: const Key('turn-status'),
        liveRegion: true,
        label:
            '${lastMoveAnnouncement(game)} $turn. $mode. ${game.evaluated ? 'Avaliada' : 'Não avaliada'}',
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: game.position.isCheck ? colors.error : colors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Tooltip(
                message: turn,
                child: Text(
                  turn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            if (game.engineError != null)
              IconButton(
                tooltip: 'Tentar novamente',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              )
            else if (game.aiThinking)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Flexible(
              child: Tooltip(
                message:
                    'Ajudas e desfazer retiram a avaliação e a validade na campanha.',
                child: Text(
                  '$mode${game.evaluated ? '' : ' · Não avaliada'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
