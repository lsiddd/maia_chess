import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic time avoids clock jumps when the device's date changes.
final clockNowMsProvider = Provider<int Function()>((ref) {
  final watch = Stopwatch()..start();
  ref.onDispose(watch.stop);
  return () => watch.elapsedMilliseconds;
});

class ClockReading {
  const ClockReading({
    required this.whiteMs,
    required this.blackMs,
    this.runningSide,
  });

  final int whiteMs;
  final int blackMs;
  final Side? runningSide;
}

/// Tick notifications are separate from board state: only the clock widgets
/// rebuild as time passes. The controller checkpoints balances on moves/save.
final gameClockProvider = StateProvider<ClockReading?>((ref) => null);
