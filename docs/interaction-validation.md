# Interaction validation — 2026-09-19

This is a historical measurement record. The coverage summary below reflects
current regression targets; the profile figures remain those recorded on
2026-09-19 and have not been remeasured by the English documentation migration.

## Coverage

- Tap and drag promotion: keep the pawn at its destination during selection;
  cover confirmation, barrier dismissal, Back, rotation, restart, and app
  suspension. Delayed choices cannot change a new game.
- Undo: synchronise selection, position, history, and animation layers. Replay
  checks start, next, previous, and final positions against saved FENs.
- Game over: retain the result and draw reason; checkmate takes precedence over
  the fifty-move counter.
- Visual hints: repeated taps, board interaction, position changes, screen exit,
  and suspension clear or cancel hints. Delayed results are discarded. Native
  integration verifies that Maia can continue after cancellation. The former
  dismissible hint dialog has been removed.
- Drag: rotation, position changes, suspension, and pointer cancellation.
  Castling synchronises king and rook; illegal drops return without duplication.
- King in check: legal escapes and captures in all four corners, both colours
  and orientations, using taps and drags.

## Recorded performance

Flutter 3.47.4, **profile** mode, Android 16/API 36 ARM64 emulator (`maia_test`),
320 logical-pixel board. The benchmark made 180 pointer updates and collected
337 frames through `watchPerformance`.

| Measurement | Result |
| --- | ---: |
| Square rebuilds in 30 updates, before | 1,920 |
| Square rebuilds in 30 updates, after | 0 |
| Mean / p99 / worst build time | 0.590 / 2.608 / 3.733 ms |
| Frames over the build budget | 0 |
| Mean / p99 / worst raster time | 16.631 / 33.528 / 134.466 ms |
| Frames over the raster budget | 178 of 337 |

A `ValueNotifier` updates only moving layers; the grid is reused and has a
`RepaintBoundary`. Rebuild counts come from a debug regression test. Timings
come from a separate profile sample after the drag settled. The raw JSON for
this older 337-frame sample is not tracked; the
[later profile record](performance/board-profile.json) contains 253 frames.

Raster delays remain in this emulator. These figures do not establish smooth
rendering on physical hardware; physical-device measurement was not available
for the original report.

## Reproduce current checks

Use the [README toolchain](../README.md#build-from-source), substitute a connected
Android device ID for `DEVICE`, and run targets sequentially:

```sh
flutter test --coverage
flutter analyze --no-fatal-infos
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
python3 -m unittest discover -s scripts -p 'test_*.py'
flutter test integration_test/android_acceptance_test.dart -d DEVICE
flutter test integration_test/phase_0_3_android_test.dart -d DEVICE
flutter drive --profile --no-dds --driver=test_driver/performance.dart --target=integration_test/board_performance_test.dart -d DEVICE
```

The benchmark skips non-profile runs. `--no-dds` lets timeline collection connect
directly to the VM service. The driver writes `build/board_performance.json`.
New runs measure the current code; they do not reproduce the old commit or
emulator conditions automatically.
