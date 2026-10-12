# Performance audit validation — 2026-10-11

This historical report preserves the original measurements and validation
results. It is not a claim that the English migration reran these benchmarks.
Current migration checks and limitations are recorded in
[documentation-audit.md](documentation-audit.md).

## Changes and verified regressions

- **Transitions:** a delayed restore, including an error, cannot replace a new
  game; a Maia response after disposal cannot persist another move. Opening
  controls reject concurrent requests before the first `await`.
- **Library:** two SELECT queries for 3, 20, and 1,100 games; one for an empty
  library. Previously, three games required four SELECTs. Tests check move
  ordering and replayed FENs.
- **Autosave:** unchanged history is neither deleted nor reinserted; appending
  writes only the new move; undo replaces only the changed suffix. A SQLite
  trigger-induced failure verifies rollback of position and moves. Timestamp
  comparison respects Drift's configured precision.
- **PGN:** Android file reading/decoding and validation run on isolates. The
  synchronous API remains available. Comments, variations, tags, FEN, and errors
  are preserved; iterative validation handles a sequence of 4,000 plies.
- **State:** `copyWith` reuses unchanged immutable histories. Termination and
  repetition are memoised and invalidated when position or history changes.
  Public inputs remain copied; tests cover mutable-list isolation, selection,
  undo, repetition, and mate.
- **Statistics:** queries, mapping, calculation, and batch generation use
  `computeWithDatabase` on the existing connection, including completion/deletion
  transactions. Tests cover uncommitted-data visibility, rollback of completion
  and rating on projection failure, and cross-connection notifications when a
  result changes without changing the game count.

## Diagnosis, root causes, priorities, and risks

| Priority / relative effort | Confirmed cause | Result / remaining risk |
| --- | --- | --- |
| P1 / medium | `restoreActiveGame` applied reads without validating generation after `await`; concurrent launches could compete for the controller | Discard stale responses and block pending launches; superseded requests return without opening a screen |
| P2 / low | `watchLibrary` hydrated each game with another query | Two queries total; the library still materialises all history, so pagination remains relevant at much larger volumes |
| P2 / medium | `_replaceSnapshot` deleted and reinserted all moves even for metadata-only updates | Write only the changed suffix; one extra SELECT compares history inside the existing transaction |
| P2 / medium | Import parsing, SAN replay, and recursive variation validation ran on the UI isolate | Workers and iterative traversal; isolate creation and transport have fixed costs |
| P2 / medium | `copyWith` copied five histories and `isGameOver` repeated FEN scans during selection | Share only immutable histories and invalidate cached facts by position/history; two additional internal flags per state |
| P2 / low | App and plugin bundled identical Maia 1900 bytes | Remove duplicate without changing app weights; the fork's implicit package asset key is removed |
| P2 / medium | SQLite ran in the background, but statistics mapping, projection, and batch construction used the UI isolate | Share connection/transaction with a worker; lower UI blocking at the cost of communication and longer total rebuild time |

Riverpod controllers, repositories, and Drift were retained. This change set
added no dependency, schema migration, or rating/campaign rule. Layout and themes
were preserved; opening controls are temporarily disabled during launch. Each
improvement has its own commit; reverts should account for shared test helpers.

## Comparable profile measurements

Flutter 3.47.4 / Dart 3.13.3; Android API 36 x86_64, AVD
`human_chess_phase0_api36`, SwiftShader rendering. The same emulator, SDK,
deterministic fixtures, and profile mode were used. Six samples per operation,
with the first discarded. No other suite or build ran during measurement.

Baseline: production code at `bed03de`, before the PGN and `GameState` changes.
After: `b2941c5` plus the `GameState` change later committed as `5a5392e`. Harness:
`integration_test/audit_performance_android_test.dart`. The baseline used
synchronous `parseImport`, matching the original import screen.

| Measurement (median of five samples) | Before | After |
| --- | ---: | ---: |
| 500 selections + `isGameOver`, history of 80 plies | 250.529 ms | 1.020 ms |
| PGN import/validation, 1,000 plies, total duration | 59.990 ms | 51.372 ms |
| Largest UI-isolate timer gap during import | 61.934 ms | 9.781 ms |

The 2 ms timer measures observed intervals, including scheduling, GC, and
inter-isolate transport; it does not directly measure frames. Results establish
improvement in these scenarios on this emulator, not RAM, battery, startup, or
physical-device latency improvements. Small files may have higher total latency
because isolate startup has a fixed cost.

Raw data: [before](performance/audit-before.json),
[after](performance/audit-after.json).

## Statistics with larger histories

`integration_test/stats_performance_android_test.dart` uses a temporary SQLite
file with `NativeDatabase.createInBackground`, as the app does, 1,000/5,000 rated
games, and six samples per scenario (first discarded). SDK, emulator, and
fixtures match before/after; no concurrent builds or suites. Before: `675b592`;
after: the statistics worker later committed as `6ece385`.

| Games / operation | Total time before → after | Largest timer gap before → after |
| --- | ---: | ---: |
| 1,000 / transactional rebuild | 101.452 → 143.582 ms | 18.259 → 15.567 ms |
| 1,000 / snapshot read | 32.884 → 30.182 ms | 15.660 → 5.697 ms |
| 5,000 / transactional rebuild | 118.246 → 135.134 ms | 30.423 → 11.776 ms |
| 5,000 / snapshot read | 92.423 → 93.381 ms | 27.735 → 9.706 ms |

The measured gain is UI-isolate responsiveness, with longer total rebuild time.
Worker startup and shared-connection communication have fixed costs. The rating
algorithm, campaign rules, and full reconstruction remain unchanged; there is no
incremental Elo calculation or schema migration. A lightweight observer query
receives initial state and `games`/`rating_history` notifications, then reads the
snapshot on a worker.

[Before data](performance/stats-before.json) /
[after data](performance/stats-after.json). The timer also observes GC and
scheduling during a short wait after each operation; it is not a frame measure.
Connection sharing follows the [Drift API](https://drift.simonbinder.eu/isolates/#simple-sharing),
verified against installed Drift 2.34.3 code. An induced SQLite worker failure
verified transaction atomicity.

## Rendering

A separate drag measurement collected 253 frames: mean build 0.389 ms, p99
1.913 ms, none over budget; mean raster 24.973 ms, p99 47.365 ms, 229 over budget.
[Raw data](performance/board-profile.json).

Raster delay remains on the software-GPU emulator. This change set has no
before/after raster comparison and did not change board appearance. Physical
hardware diagnosis remains outstanding.

## Android size and packaging

At duplicate removal (`5a5392e` → `675b592`), two consecutive builds used the
same SDK, Dart/native code, configuration, and command:
`flutter build apk --release --split-per-abi --target-platform android-arm64`.

| ARM64 APK | Bytes |
| --- | ---: |
| Before duplicate removal | 152,001,006 |
| After | 150,737,798 |
| Reduction | 1,263,208 |

The vendored plugin stopped declaring Maia 1900 as its asset; the file and
declaration moved into the example, which now declares its own asset. The
example bundle was built and contained the correct bytes at its declared path.
The app continues using `assets/maia_weights/maia-1900.pb.gz`. External users of
this fork's former implicit key
`packages/leela_chess_zero/assets/weights/maia-1900.pb.gz` must declare their own
weights, as described in the [plugin README](../native/leela_chess_zero/README.md).

All nine app networks and every `.so`, including `libapp.so`, were identical
between those APKs. The reduction comes from duplicate bytes and associated
metadata. [Instrumented comparison](performance/apk-size.json).
`libstockfish.so` remains the largest component; changing its NNUE would need
separate analysis-quality validation.

The original run passed `verify_apk.py`, `apksigner`, `zipalign -c -P 16 4`, and
ELF LOAD segment inspection. All seven ARM64 libraries had at least 16 KB ELF
alignment. Ten Python tests passed, including duplicate-network rejection.

Local builds used the configured debug-key fallback because no
`android/app/key.properties` was present. Distribution-key signing was not
exercised. The SDK warned about future AGP 8.11.1 and Kotlin 2.2.20 support
changes; builds completed successfully.

## Original final validation

- Formatting: 96 Dart files, no changes needed.
- `flutter analyze`: no issues. `flutter test --coverage`: 239 passing tests.
  The three worker tests passed again after the final lint adjustment.
- Python release tools: ten passing tests.
- Android API 36: 75 consolidated acceptance tests passed after the statistics
  worker change. Two additional native tests passed: Maia 1100 → 1900 with
  hints/cancellation and lc0 recovery after invalid weights.
- Selection/PGN, statistics, and drag benchmarks ran in profile mode; their
  results and limits are above.
- Final release build with
  `--split-per-abi --target-platform android-arm64,android-x64`: ARM64
  150,737,806 bytes; x86_64 152,463,137 bytes. All nine networks matched source,
  duplicate absent, ELF alignment at least 16 KB in both ABIs. ARM64 also passed
  the content verifier, `zipalign`, and `apksigner`.
  [Final sizes, hashes, and alignment](performance/final-release.json).
- The release x86_64 APK was installed on the emulator: statistics showed initial
  rating 1500 and zero rated games; Maia 1900 opened as White and replied to
  `e7e5`; observed history was `1. e4 e5 · 2. Nf3`; Stockfish highlighted Black's
  b8 knight. Labels and history were checked against UIAutomator accessibility
  assertions. [Smoke-test evidence](performance/release-smoke.json). This does
  not replace the complete release integration suite or test ARM64 hardware.

A concurrent x86_64 release build failed because integration-test generation
changed `GeneratedPluginRegistrant.java` to reference `integration_test`, absent
from that production compilation. A sequential retry and the final dual-ABI
build passed. No Android source fix was required.

## Reproduce

Use the [README prerequisites](../README.md#set-up-and-run), substitute `DEVICE`,
and run commands sequentially:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze --no-fatal-infos
flutter test --coverage
python3 -m unittest discover -s scripts -p 'test_*.py'
flutter drive --profile --no-dds --driver=test_driver/audit_performance.dart --target=integration_test/audit_performance_android_test.dart -d DEVICE
flutter drive --profile --no-dds --driver=test_driver/audit_performance.dart --target=integration_test/stats_performance_android_test.dart -d DEVICE
flutter drive --profile --no-dds --driver=test_driver/performance.dart --target=integration_test/board_performance_test.dart -d DEVICE
flutter test integration_test/android_acceptance_test.dart -d DEVICE
flutter test integration_test/phase_0_3_android_test.dart -d DEVICE
flutter build apk --release --split-per-abi --target-platform android-arm64
python3 scripts/verify_apk.py build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

The audit driver saves `build/audit_performance.json`. Benchmarks require profile
mode and use no timing assertions. For the selection/PGN baseline, use a separate
checkout of `bed03de`, copy the harness and driver, and replace
`await ...parseImportAsync` with `...parseImport` in the harness. Keep the SDK,
fixtures, and device identical.

The statistics target uses the same driver and overwrites its output. Save each
report before running another target. Its baseline is `675b592`, with this
statistics harness and driver copied in without changing the harness.

Framework references: [Flutter isolates](https://docs.flutter.dev/perf/isolates)
and [compute](https://api.flutter.dev/flutter/foundation/compute.html). Query/write
reductions are project instrumentation; timings are experimental evidence, not
framework guarantees.
