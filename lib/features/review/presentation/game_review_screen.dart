import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theming/app_theme.dart';
import '../../../core/widgets/error_state_card.dart';
import '../../../data/repositories/game_repository.dart';
import '../../game/application/game_controller.dart';
import '../../history/domain/game_replayer.dart';
import '../../pgn/application/pgn_service.dart';
import '../application/game_review_analyzer.dart';
import '../domain/game_review.dart';
import '../domain/review_pgn.dart';
import 'review_board.dart';
import 'review_chart.dart';
import 'review_details.dart';

final _lastReviewProvider = Provider((ref) => _LastReview());

class _LastReview {
  StoredGame? source;
  GameReview? review;

  GameReview? forGame(StoredGame game) =>
      source?.id == game.id &&
          source?.lastModifiedAtUtc == game.lastModifiedAtUtc
      ? review
      : null;
}

class GameReviewScreen extends ConsumerStatefulWidget {
  const GameReviewScreen({
    super.key,
    required this.game,
    required this.replayed,
    this.initialPly = 0,
  });

  final StoredGame game;
  final ReplayedGame replayed;
  final int initialPly;

  @override
  ConsumerState<GameReviewScreen> createState() => _GameReviewScreenState();
}

class _GameReviewScreenState extends ConsumerState<GameReviewScreen>
    with WidgetsBindingObserver {
  final _portraitScroll = ScrollController();
  late final void Function() _releaseReviewEngine;
  late int _ply;
  late Side _orientation;
  GameReview? _review;
  List<double> _whiteWinPercent = const [];
  ReviewRequest? _request;
  (int, int)? _progress;
  String? _analysisError;

  _Variation? _variation;
  int _step = 0;
  ReviewPositionAnalysis? _positionAnalysis;
  String? _positionError;

  bool _retrying = false;
  Side? _retrySide;
  ReviewRetry? _retryResult;
  bool _sharing = false;

  int get _lastPly => widget.replayed.ucis.length;
  bool get _canAnalyzeGame => _lastPly <= GameReviewAnalyzer.maxFullReviewPlies;
  int get _basePly => _variation?.basePly ?? (_retrying ? _ply - 1 : _ply);
  bool get _busy => _request != null;
  List<ReviewedMove> get _moments => _review?.keyMoments ?? const [];
  Iterable<ReviewedMove> get _exercises => _moments.where(
    (move) =>
        move.quality.isMistake &&
        (_retrySide == null || move.side == _retrySide),
  );
  Chess get _position =>
      _variation?.positions[_step] ?? widget.replayed.positions[_basePly];
  ReviewPositionAnalysis? get _currentAnalysis =>
      _positionAnalysis ?? (_step == 0 ? _review?.positions[_basePly] : null);
  ReviewedMove? get _reviewedMove =>
      _ply == 0 ? null : _review?.moves[_ply - 1];

  @override
  void initState() {
    super.initState();
    _releaseReviewEngine = ref
        .read(gameControllerProvider.notifier)
        .acquireStockfishForReview();
    _ply = widget.initialPly.clamp(0, _lastPly);
    _orientation = widget.game.playerSide ?? Side.white;
    _retrySide = widget.game.playerSide;
    WidgetsBinding.instance.addObserver(this);
    final cached = ref.read(_lastReviewProvider).forGame(widget.game);
    if (cached != null) {
      _showReview(cached);
    } else if (_canAnalyzeGame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_analyzeGame());
      });
    } else {
      _analysisError = const ReviewLimitException().toString();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _busy) _cancelAnalysis();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _request?.cancel();
    _releaseReviewEngine();
    _portraitScroll.dispose();
    super.dispose();
  }

  bool _isCurrent(ReviewRequest request) =>
      mounted && identical(_request, request);

  void _showReview(GameReview review) {
    _review = review;
    _whiteWinPercent = [
      for (final position in review.positions)
        position.evaluation.whiteWinPercent,
    ];
  }

  Future<void> _analyzeGame() async {
    if (_busy || !_canAnalyzeGame) return;
    final request = ReviewRequest();
    setState(() {
      _request = request;
      _analysisError = null;
      _progress = (0, _lastPly + 1);
    });
    try {
      final review = await ref
          .read(reviewAnalyzerProvider)
          .analyze(
            widget.replayed,
            request: request,
            onProgress: (done, total) {
              if (_isCurrent(request)) {
                setState(() => _progress = (done, total));
              }
            },
          );
      if (!_isCurrent(request)) return;
      ref.read(_lastReviewProvider)
        ..source = widget.game
        ..review = review;
      setState(() => _showReview(review));
    } on ReviewCancelledException {
      // Leaving the screen or cancelling discards the unfinished scan.
    } catch (error) {
      if (_isCurrent(request)) {
        setState(() => _analysisError = error.toString());
      }
    } finally {
      if (_isCurrent(request)) {
        setState(() {
          _request = null;
          _progress = null;
        });
      }
    }
  }

  void _cancelAnalysis() {
    _request?.cancel();
    setState(() {
      _request = null;
      _progress = null;
    });
  }

  void _clearVariation() {
    _variation = null;
    _step = 0;
    _positionAnalysis = null;
    _positionError = null;
  }

  void _goTo(int ply) {
    if (_busy && _progress == null) _cancelAnalysis();
    setState(() {
      _ply = ply.clamp(0, _lastPly);
      _retrying = false;
      _retryResult = null;
      _clearVariation();
    });
  }

  void _moveCursor(int direction) {
    final variation = _variation;
    if (variation == null) {
      _goTo(_ply + direction);
      return;
    }
    if (_busy && _progress == null) _cancelAnalysis();
    setState(() {
      _step = (_step + direction).clamp(0, variation.ucis.length);
      _positionAnalysis = null;
      _positionError = null;
    });
  }

  void _showLine(
    int basePly,
    ReviewLine line, {
    Iterable<String> prefix = const [],
  }) {
    if (_busy) _cancelAnalysis();
    final variation = _Variation.fromMoves(widget.replayed, basePly, [
      ...prefix,
      ...line.ucis,
    ]);
    if (variation.ucis.length <= prefix.length) return;
    setState(() {
      _retrying = false;
      _retryResult = null;
      _clearVariation();
      _variation = variation;
      _step = prefix.length + 1;
    });
    if (_portraitScroll.hasClients) _portraitScroll.jumpTo(0);
  }

  void _playMove(String uci) {
    if (_retrying) {
      if (!_busy && _retryResult?.acceptable != true) unawaited(_tryMove(uci));
      return;
    }
    if (_busy && _progress == null) _cancelAnalysis();
    final base = _basePly;
    final continuation = [...?_variation?.ucis.take(_step), uci];
    final variation = _Variation.fromMoves(widget.replayed, base, continuation);
    if (variation.ucis.length != continuation.length) return;
    setState(() {
      _clearVariation();
      _variation = variation;
      _step = variation.ucis.length;
    });
  }

  Future<void> _analyzePosition() async {
    if (_busy) return;
    final base = _basePly;
    final request = ReviewRequest();
    setState(() {
      _request = request;
      _positionError = null;
    });
    try {
      final analysis = await ref
          .read(reviewAnalyzerProvider)
          .analyzePosition(
            widget.replayed,
            base,
            continuation: _variation?.ucis.take(_step).toList() ?? const [],
            request: request,
          );
      if (_isCurrent(request)) setState(() => _positionAnalysis = analysis);
    } on ReviewCancelledException {
      // A cursor change discards the pending position result.
    } catch (error) {
      if (_isCurrent(request)) {
        setState(() => _positionError = error.toString());
      }
    } finally {
      if (_isCurrent(request)) setState(() => _request = null);
    }
  }

  void _startExercise(ReviewedMove move) {
    if (_busy) _cancelAnalysis();
    setState(() {
      _ply = move.ply;
      _orientation = move.side;
      _retrying = true;
      _retryResult = null;
      _clearVariation();
    });
    if (_portraitScroll.hasClients) _portraitScroll.jumpTo(0);
  }

  Future<void> _tryMove(String uci) async {
    final move = _reviewedMove!;
    final request = ReviewRequest();
    setState(() {
      _request = request;
      _retryResult = null;
      _positionError = null;
    });
    try {
      final result = await ref
          .read(reviewAnalyzerProvider)
          .retryMove(widget.replayed, move, uci, request: request);
      if (!_isCurrent(request)) return;
      setState(() {
        _retryResult = result;
        if (result.acceptable) {
          _variation = _Variation.fromMoves(widget.replayed, move.ply - 1, [
            uci,
          ]);
          _step = _variation!.ucis.length;
        }
      });
    } on ReviewCancelledException {
      // An exercise switch discards the pending attempt.
    } catch (error) {
      if (_isCurrent(request)) {
        setState(() => _positionError = error.toString());
      }
    } finally {
      if (_isCurrent(request)) setState(() => _request = null);
    }
  }

  Future<void> _shareReview(GameReview review) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await const PgnFileService().sharePgn(
        gameId: '${widget.game.id}_review',
        pgn: await exportReviewedPgnAsync(widget.game, review),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export the review: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    final variation = _variation;
    final positionAnalysis = _retrying ? null : _currentAnalysis;
    final suggestion = positionAnalysis?.lines.firstOrNull?.ucis.firstOrNull;
    final lastMovePly = variation != null && _step > 0 ? _step : _basePly;
    final lastMove = lastMovePly == 0
        ? null
        : variation != null && _step > 0
        ? reviewBoardMove(
            variation.positions[_step - 1],
            variation.ucis[_step - 1],
          )
        : reviewBoardMove(
            widget.replayed.positions[_basePly - 1],
            widget.replayed.ucis[_basePly - 1],
          );
    final board = ReviewBoard(
      position: position,
      orientation: _orientation,
      onMove: _playMove,
      enabled:
          !position.isGameOver &&
          (!_retrying || (!_busy && _retryResult?.acceptable != true)),
      lastMove: lastMove,
      suggestion: reviewBoardMove(position, suggestion),
    );
    final controls = _retrying ? const SizedBox.shrink() : _navigation(context);
    final details = _retrying ? _exercise(context) : _details(context);

    return PopScope(
      canPop: !_retrying && _variation == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (_retrying || _variation != null)) _goTo(_ply);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _retrying ? 'Learn from mistakes' : 'Game review',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: _retrying
              ? IconButton(
                  onPressed: () => _goTo(_ply),
                  tooltip: 'Back to review',
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          actions: [
            if (!_retrying && _review != null)
              IconButton(
                tooltip: 'Export annotated PGN',
                onPressed: _sharing ? null : () => _shareReview(_review!),
                icon: const Icon(Icons.share_outlined),
              ),
            PopupMenuButton<String>(
              tooltip: 'Review options',
              onSelected: (action) async {
                if (action == 'rotate') {
                  setState(() => _orientation = _orientation.opposite);
                } else {
                  await Clipboard.setData(ClipboardData(text: position.fen));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Position copied.')),
                    );
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rotate', child: Text('Rotate board')),
                PopupMenuItem(
                  value: 'copy',
                  child: Text('Copy position (FEN)'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 650 &&
                  constraints.maxWidth > constraints.maxHeight;
              if (wide) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.m),
                            child: Column(
                              children: [
                                Expanded(child: board),
                                if (positionAnalysis != null)
                                  ReviewEvaluationBar(
                                    evaluation: positionAnalysis.evaluation,
                                  ),
                                controls,
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            key: const PageStorageKey(
                              'review-landscape-details',
                            ),
                            padding: const EdgeInsets.all(AppSpacing.m),
                            children: details,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    key: const PageStorageKey('review-portrait-details'),
                    controller: _portraitScroll,
                    padding: const EdgeInsets.all(AppSpacing.m),
                    children: [
                      board,
                      if (positionAnalysis != null)
                        ReviewEvaluationBar(
                          evaluation: positionAnalysis.evaluation,
                        ),
                      controls,
                      ...details,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _navigation(BuildContext context) {
    final variation = _variation;
    final cursor = variation == null ? _ply : _step;
    final last = variation?.ucis.length ?? _lastPly;
    final title = variation == null
        ? _ply == 0
              ? 'Initial position'
              : reviewMoveLabel(
                  widget.replayed.positions[_ply - 1],
                  widget.replayed.sans[_ply - 1],
                )
        : _step == 0
        ? 'Variation start'
        : reviewMoveLabel(
            variation.positions[_step - 1],
            variation.sans[_step - 1],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'First position',
                onPressed: cursor == 0 ? null : () => _moveCursor(-cursor),
                icon: const Icon(Icons.first_page),
              ),
              IconButton(
                tooltip: 'Previous position',
                onPressed: cursor == 0 ? null : () => _moveCursor(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                  child: Text(
                    '$cursor / $last',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next position',
                onPressed: cursor == last ? null : () => _moveCursor(1),
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: 'Last position',
                onPressed: cursor == last
                    ? null
                    : () => _moveCursor(last - cursor),
                icon: const Icon(Icons.last_page),
              ),
            ],
          ),
          if (variation != null)
            TextButton.icon(
              onPressed: () => _goTo(_ply),
              icon: const Icon(Icons.undo),
              label: const Text('Return to game'),
            ),
        ],
      ),
    );
  }

  List<Widget> _details(BuildContext context) {
    final review = _review;
    final move = _reviewedMove;
    final progress = _progress;
    final positionAnalysis = _currentAnalysis;
    final variation = _variation;
    final previousMoment = _moments.where((move) => move.ply < _ply).lastOrNull;
    final nextMoment = _moments.where((move) => move.ply > _ply).firstOrNull;
    return [
      if (progress != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reviewing your game',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${progress.$1} of ${progress.$2} positions · You can keep exploring.',
                ),
                const SizedBox(height: AppSpacing.s),
                LinearProgressIndicator(
                  value: progress.$1 / progress.$2,
                  semanticsLabel: 'Game review progress',
                  semanticsValue:
                      '${(progress.$1 / progress.$2 * 100).round()}',
                ),
                TextButton(
                  onPressed: _cancelAnalysis,
                  child: const Text('Cancel analysis'),
                ),
              ],
            ),
          ),
        )
      else if (review == null) ...[
        if (_analysisError case final error?)
          ErrorStateCard(message: 'Game analysis is unavailable. $error'),
        if (_canAnalyzeGame)
          OutlinedButton.icon(
            onPressed: _busy ? null : _analyzeGame,
            icon: const Icon(Icons.insights),
            label: const Text('Analyze game'),
          ),
      ],
      if (review != null && variation == null) ...[
        ReviewChart(
          whiteWinPercent: _whiteWinPercent,
          ply: _ply,
          onSelect: _goTo,
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: previousMoment == null
                  ? null
                  : () => _goTo(previousMoment.ply),
              icon: const Icon(Icons.skip_previous),
              label: const Text('Previous key move'),
            ),
            TextButton.icon(
              onPressed: nextMoment == null
                  ? null
                  : () => _goTo(nextMoment.ply),
              icon: const Icon(Icons.skip_next),
              label: const Text('Next key move'),
            ),
          ],
        ),
        if (move != null)
          ReviewMoveDetails(
            move: move,
            onBest: _bestLine(move),
            onShow: review.positions[_ply].lines.isEmpty
                ? null
                : () => _showLine(_ply, review.positions[_ply].lines.first),
            onRetry: move.quality.isMistake ? () => _startExercise(move) : null,
          ),
      ],
      if (_positionError case final error?)
        ErrorStateCard(
          message: 'Position analysis is unavailable. $error',
          onRetry: _busy ? null : _analyzePosition,
        ),
      if (positionAnalysis != null && positionAnalysis.lines.isNotEmpty)
        ReviewLines(
          lines: positionAnalysis.lines,
          onSelect: (line) {
            if (variation == null) {
              _showLine(_ply, line);
            } else {
              _showLine(
                variation.basePly,
                line,
                prefix: variation.ucis.take(_step),
              );
            }
          },
        ),
      if (!_position.isGameOver && _positionAnalysis == null)
        OutlinedButton.icon(
          onPressed: _busy ? null : _analyzePosition,
          icon: const Icon(Icons.analytics_outlined),
          label: Text(
            _busy && progress == null
                ? 'Analyzing position…'
                : positionAnalysis == null
                ? 'Analyze position'
                : 'Analyze position deeper',
          ),
        ),
      if (variation == null) ...[
        if (review != null)
          ReviewSummary(
            review: review,
            retrySide: _retrySide,
            onRetrySide: (side) => setState(() => _retrySide = side),
            onLearn: _exercises.isEmpty
                ? null
                : () => _startExercise(_exercises.first),
          ),
        ReviewMoveList(
          replayed: widget.replayed,
          review: review,
          ply: _ply,
          onSelect: _goTo,
        ),
      ] else
        ReviewVariationList(
          positions: variation.positions,
          sans: variation.sans,
          step: _step,
          onSelect: (step) => _moveCursor(step - _step),
        ),
    ];
  }

  VoidCallback? _bestLine(ReviewedMove move) {
    final best = _review?.positions[move.ply - 1].lines.firstOrNull;
    return best == null ? null : () => _showLine(move.ply - 1, best);
  }

  List<Widget> _exercise(BuildContext context) {
    final move = _reviewedMove!;
    final next = _exercises
        .where((candidate) => candidate.ply > move.ply)
        .firstOrNull;
    final played = reviewMoveLabel(
      widget.replayed.positions[_ply - 1],
      move.san,
    );
    final result = _retryResult;
    return [
      Text(
        'You are replaying $played.',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      Semantics(
        liveRegion: true,
        child: Text(
          _positionError ??
              (_busy
                  ? 'Checking your move with Stockfish…'
                  : result == null
                  ? 'Find a stronger move for ${sideLabel(move.side).toLowerCase()}.'
                  : result.acceptable
                  ? 'Well played. Your move preserves the position.'
                  : 'Stockfish still finds a stronger move. Try again.'),
        ),
      ),
      if (_busy) const LinearProgressIndicator(),
      Wrap(
        spacing: AppSpacing.s,
        children: [
          TextButton(
            onPressed: _bestLine(move),
            child: const Text('Show solution'),
          ),
          if (next != null)
            FilledButton(
              onPressed: () => _startExercise(next),
              child: const Text('Next exercise'),
            ),
          TextButton(
            onPressed: () => _goTo(_ply),
            child: const Text('Exit practice'),
          ),
        ],
      ),
    ];
  }
}

/// A branch has its own cursor and positions and never writes to the game.
class _Variation {
  const _Variation(this.basePly, this.positions, this.ucis, this.sans);

  factory _Variation.fromMoves(
    ReplayedGame game,
    int basePly,
    Iterable<String> moves,
  ) {
    var position = game.positions[basePly];
    final positions = [position];
    final ucis = <String>[];
    final sans = <String>[];
    for (final uci in moves) {
      final move = Move.parse(uci);
      if (move == null || !position.isLegal(move)) break;
      final (next, san) = position.makeSan(move);
      position = next as Chess;
      positions.add(position);
      ucis.add(uci);
      sans.add(san);
    }
    return _Variation(basePly, positions, ucis, sans);
  }

  final int basePly;
  final List<Chess> positions;
  final List<String> ucis;
  final List<String> sans;
}
