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
  bool _savingSettings = false;
  int _planIndex = 0;
  String? _noticeText;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(gameControllerProvider.notifier);
    _plans = ref.read(liveThreatControllerProvider.notifier);
    ref.listenManual(
      appSettingsProvider,
      (previous, next) {
        if (next.valueOrNull?.showAttackedPieces == true) {
          _markAttackAssistance();
        }
      },
      fireImmediately: true,
    );
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
      _notice('Game over: no move is available.');
      return;
    }
    try {
      await ref.read(visualHintProvider.notifier).toggle();
    } on HintCancelledException {
      /* Position or interaction changed. */
    } catch (_) {
      _notice('Could not calculate a hint. Tap Hint to try again.');
    }
  }

  Future<void> _settings({bool? attacks, bool? ownOnly}) async {
    if (_savingSettings) return;
    setState(() => _savingSettings = true);
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
      _notice('Could not save the preference.');
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  void _markAttackAssistance() {
    scheduleMicrotask(() {
      if (!mounted ||
          ref.read(appSettingsProvider).valueOrNull?.showAttackedPieces != true ||
          ref.read(gameControllerProvider).isGameOver) {
        return;
      }
      unawaited(_controller.markAsNotEvaluated());
    });
  }

  @override
  Widget build(BuildContext context) {
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
        _markAttackAssistance();
      }
    });
    ref.listen<LiveThreatState>(liveThreatControllerProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        _notice('Analysis unavailable. Turn Plans off and on to try again.');
      }
    });
    final busy = game.aiThinking;
    final toolbar = SizedBox(
      height: 64,
      child: Row(
        key: const Key('game-actions'),
        children: [
          GameToolButton(
            label: 'Undo',
            icon: Icons.undo,
            tooltip: game.campaignMode
                ? 'Undo: this game will no longer count toward the campaign'
                : 'Undo',
            onPressed: game.canUndo && !busy && !game.isGameOver
                ? _controller.undo
                : null,
          ),
          GameToolButton(
            key: const Key('hint-button'),
            label: 'Hint',
            icon: Icons.lightbulb_outline,
            active: hint != null,
            loading: game.hintThinking,
            tooltip:
                'Stockfish hint: highlights only the piece; makes the game unrated',
            onPressed: game.isGameOver || (!busy && !game.isAiTurn)
                ? _hint
                : null,
          ),
          GameToolButton(
            key: const Key('toggle-attacked-pieces'),
            label: 'Attacks',
            icon: Icons.crop_free,
            active: settings.showAttackedPieces,
            onPressed: _savingSettings
                ? null
                : () {
                    unawaited(
                      _settings(attacks: !settings.showAttackedPieces),
                    );
                    if (!settings.showAttackedPieces && !game.isGameOver) {
                      unawaited(_controller.markAsNotEvaluated());
                    }
                  },
          ),
          GameToolButton(
            key: const Key('show-opponent-threats'),
            label: 'Plans',
            icon: Icons.trending_up,
            tooltip: 'Opponent plans',
            active: plans.enabled,
            loading: plans.loading,
            onPressed: () {
              _planIndex = 0;
              _plans.setEnabled(!plans.enabled);
              if (!plans.enabled && game.position.isCheck) {
                _notice('Get out of check before viewing opponent plans.');
              }
            },
          ),
          GameToolButton(
            label: 'More',
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
                  tooltip: 'Next opponent plan',
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
          game.aiSide == null ? 'Local game' : 'Maia ${game.levelRating}',
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
                ('flip', Icons.swap_vert, 'Rotate board'),
                ('save', Icons.save_outlined, 'Save game'),
                ('settings', Icons.tune, 'Settings'),
                (
                  'filter',
                  Icons.filter_alt_outlined,
                  settings.ownAttackedPiecesOnly
                      ? 'Attacks: show all pieces'
                      : 'Attacks: my pieces only',
                ),
                ('help', Icons.help_outline, 'Tool help'),
                ('reset', Icons.restart_alt, 'Restart'),
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
                      ? 'Hints, attacks, plans, and undo make the game unrated: it does not count toward campaign progress.'
                      : 'The game is saved automatically after every move. Assistance and undo make it unrated.',
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
        if (!mounted) return;
        final error = ref.read(gameControllerProvider).persistenceError;
        _notice(error ?? 'Game saved.');
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
            title: const Text('Game tools'),
            content: const SingleChildScrollView(
              child: Text(
                'Hint: an amber outline marks only the piece suggested by Stockfish. Tap again to hide it.\n\n'
                'Attacks: a solid orange border marks an attacked piece without geometric defence; a double blue border marks an attacked, defended piece. This does not guarantee a material gain or loss: pins and exchanges require tactical analysis.\n\n'
                'Opponent plans: an arrow shows one Stockfish option if the opponent could move now. It is not a proven threat. Use the counter to switch plans.\n\n'
                'Undo: against Maia, returns to your previous decision; in local play, takes back one move. Assistance and undo make the game unrated and ineligible for campaign progress.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
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
          title: const Text('Restart game?'),
          content: const Text(
            'The current progress in this game will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restart'),
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
        (game.persistenceError != null
            ? game.persistenceError!
            : game.isGameOver
            ? gameResultDescription(game)
            : game.engineError != null
            ? 'Maia unavailable'
            : game.position.isCheck
            ? 'Check'
            : game.aiSide == null
            ? (game.position.turn == Side.white
                  ? 'White to move'
                  : 'Black to move')
            : game.isAiTurn
            ? 'Maia to move'
            : 'Your turn');
    final mode = game.campaignMode
        ? 'Campaign'
        : game.aiSide == null
        ? 'Local'
        : 'Practice';
    return SizedBox(
      height: 52,
      child: Semantics(
        key: const Key('turn-status'),
        liveRegion: true,
        label:
            '${lastMoveAnnouncement(game)} $turn. $mode. ${game.evaluated ? 'Rated' : 'Unrated'}',
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
                tooltip: 'Try again',
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
                    'Assistance and undo make the game unrated and ineligible for campaign progress.',
                child: Text(
                  '$mode${game.evaluated ? '' : ' · Unrated'}',
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
