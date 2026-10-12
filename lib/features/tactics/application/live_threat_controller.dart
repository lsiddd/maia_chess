import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/application/game_controller.dart';
import '../../game/application/game_state.dart';
import '../domain/tactical_analysis.dart';

final liveThreatControllerProvider =
    NotifierProvider.autoDispose<LiveThreatController, LiveThreatState>(
      LiveThreatController.new,
    );

class LiveThreatState {
  const LiveThreatState({
    this.enabled = false,
    this.loading = false,
    this.paused = false,
    this.result,
    this.error,
  });

  final bool enabled;
  final bool loading;
  final bool paused;
  final ThreatResult? result;
  final Object? error;
}

/// Refresh on position or availability changes. Selection and drag do not
/// trigger searches; revisions prevent stale results from being published.
class LiveThreatController extends AutoDisposeNotifier<LiveThreatState> {
  late GameController _game;
  int _revision = 0;
  bool _disposed = false;

  @override
  LiveThreatState build() {
    _game = ref.read(gameControllerProvider.notifier);
    ref.listen<GameState>(gameControllerProvider, (previous, next) {
      if (previous?.gameId != next.gameId) {
        setEnabled(false);
      } else if (previous?.position.fen != next.position.fen ||
          (previous != null && _available(previous) != _available(next))) {
        _refresh();
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _revision++;
      _game.cancelOpponentThreats();
    });
    return const LiveThreatState();
  }

  static bool _available(GameState game) =>
      !game.isGameOver &&
      !game.position.isCheck &&
      !game.isAiTurn &&
      !game.aiThinking &&
      !game.hintThinking;

  void setEnabled(bool enabled) {
    state = LiveThreatState(enabled: enabled, paused: state.paused);
    _refresh();
  }

  void setPaused(bool paused) {
    if (state.paused == paused) return;
    state = LiveThreatState(enabled: state.enabled, paused: paused);
    _refresh();
  }

  void retry() => _refresh();

  void _refresh() {
    final revision = ++_revision;
    _game.cancelOpponentThreats();
    final loading =
        state.enabled &&
        !state.paused &&
        _available(ref.read(gameControllerProvider));
    state = LiveThreatState(
      enabled: state.enabled,
      paused: state.paused,
      loading: loading,
    );
    if (loading) {
      // Coalesce synchronous changes such as a move and AI turn transitions.
      scheduleMicrotask(() {
        if (!_disposed && revision == _revision) {
          unawaited(_calculate(revision));
        }
      });
    }
  }

  Future<void> _calculate(int revision) async {
    try {
      final result = await _game.getOpponentThreats();
      if (_disposed || revision != _revision) return;
      state = LiveThreatState(enabled: true, result: result);
    } on HintCancelledException {
      // Position, screen, or analysis availability has already changed.
    } catch (error) {
      if (_disposed || revision != _revision) return;
      state = LiveThreatState(enabled: true, error: error);
    }
  }
}
