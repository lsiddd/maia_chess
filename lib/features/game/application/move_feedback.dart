import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final moveSoundPlayerProvider = Provider<Future<void> Function(String)>(
  (ref) => Platform.isAndroid ? playMoveSound : (_) async {},
);

const _moveSounds = MethodChannel('maia_chess/move_sounds');

/// Captures use their own sound even when they also give check or promote.
Future<void> playMoveSound(String san) async {
  try {
    await _moveSounds.invokeMethod<bool>(
      san.contains('x') ? 'capture' : 'move',
    );
  } on MissingPluginException {
    // A host without the Android audio bridge can still play the game.
  } on PlatformException catch (error) {
    debugPrint('Could not play chess sound: ${error.code}');
  }
}

/// Haptic move event derived from SAN. Enum order expresses priority: emit
/// only the most significant event when, for example, a capture also gives
/// check.
enum MoveFeedbackKind { checkmate, check, promotion, capture, castle, move }

/// Classify SAN using `x` for capture, `+` for check, `#` for mate, `O-O` for
/// castling, and `=` for promotion. This also detects en passant, whose
/// destination square was empty.
MoveFeedbackKind classifyMoveFeedback(String san) {
  if (san.contains('#')) return MoveFeedbackKind.checkmate;
  if (san.contains('+')) return MoveFeedbackKind.check;
  if (san.contains('=')) return MoveFeedbackKind.promotion;
  if (san.contains('x')) return MoveFeedbackKind.capture;
  if (san.startsWith('O-O')) return MoveFeedbackKind.castle;
  return MoveFeedbackKind.move;
}

/// Emit platform haptic feedback for [kind], with stronger feedback for check
/// and mate than for quiet moves. Actual vibration depends on platform and
/// device settings.
Future<void> playMoveHaptic(MoveFeedbackKind kind) {
  return switch (kind) {
    MoveFeedbackKind.checkmate => HapticFeedback.heavyImpact(),
    MoveFeedbackKind.check => HapticFeedback.mediumImpact(),
    MoveFeedbackKind.promotion => HapticFeedback.mediumImpact(),
    MoveFeedbackKind.capture => HapticFeedback.mediumImpact(),
    MoveFeedbackKind.castle => HapticFeedback.lightImpact(),
    MoveFeedbackKind.move => HapticFeedback.selectionClick(),
  };
}
