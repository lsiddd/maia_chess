import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../game/application/game_controller.dart';
import '../../game/application/game_state.dart';

final visualHintProvider =
    NotifierProvider.autoDispose<VisualHintController, Square?>(
      VisualHintController.new,
    );

/// Guarda apenas a origem, sem expor destino ou notação à tela de partida.
class VisualHintController extends AutoDisposeNotifier<Square?> {
  int _revision = 0;
  bool _disposed = false;

  @override
  Square? build() {
    ref.listen<GameState>(gameControllerProvider, (previous, next) {
      if (previous?.position.fen != next.position.fen ||
          previous?.gameId != next.gameId ||
          previous?.selectedSquare != next.selectedSquare) {
        clear();
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _revision++;
    });
    return null;
  }

  void clear() {
    _revision++;
    state = null;
  }

  Future<void> toggle() async {
    final game = ref.read(gameControllerProvider.notifier);
    if (state != null || ref.read(gameControllerProvider).hintThinking) {
      clear();
      await game.cancelHint();
      return;
    }
    final revision = ++_revision;
    final hint = await game.getHint();
    if (!_disposed &&
        revision == _revision &&
        ref.read(gameControllerProvider).position.fen == hint.fen) {
      state = hint.move.from;
    }
  }
}
