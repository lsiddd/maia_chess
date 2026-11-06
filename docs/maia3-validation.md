# Maia-3 79M validation — 2026-11-06

The application uses the official Maia-3 79M policy in FP32 at all 16 supported
Elos, with temperature 1 and top-p 1. Both Elo inputs receive the selected level.
The final ONNX file is in `assets/maia3/` with Git LFS attributes. Model loading,
streaming extraction, SHA-256 verification, history encoding, inference dispatch,
cancellation and legal-move sampling are implemented in Dart. ONNX Runtime 1.22.0
executes the numerical operations through FFI on a dedicated Dart isolate.
Android's small platform channel only returns the installed APK paths.

The initial checkpoint conversion took place outside the repository. There is
no Python model source, exporter, build step or runtime in the project. The
existing Python signing utility remains unrelated to model handling. Exact
source revisions, dependency versions and hashes are recorded in the
[model manifest](../assets/maia3/manifest.json) and
[model notice](../assets/maia3/NOTICE.md).

## Numerical fidelity

The conversion was compared with official PyTorch inference at all 16 Elos.
Across 224 case/level evaluations (192 with legal moves and 32 terminal), the
maximum absolute difference in legal move probabilities was
**0.00001099705696105957**, below the **0.0001** limit. Terminal cases were
checked for finite output and an empty legal-move set.

The production Android runtime was then independently compared with the saved
PyTorch probabilities in `test/fixtures/maia3_reference.dart`. Across 192
nonterminal case/level combinations, its maximum absolute error was
**0.000010308356891086667**. All passed. Dart encoding tests compare every
nonzero token and every legal move/index against the official fixtures,
including both sides to move, castling, en passant, all promotion pieces,
short/padded history, repetition, check, checkmate and stalemate.

## Functional checks

- All 283 host tests passed with coverage, including the controller test for
  exact history and Elo inputs after undo and autosave restoration.
- All 82 tests in `integration_test/maia3_acceptance_test.dart` passed on Android
  with airplane mode enabled and app data cleared before the run.
- These cover real Maia-3 moves, level changes using one session, native
  cancellation, dispose/reinitialization, failure/retry, Stockfish hints and
  review, restoration, undo, campaign progression, statistics, and existing
  board/promotion/result regressions.
- Model extraction tests cover cached reuse, repair of a same-size corrupt
  local file, rejection of a corrupt APK asset, and removal of partial files.
- Static analysis and formatting passed. All five existing signing-tool tests
  passed.

New installs start the campaign at 600, require two wins in a window of three,
and follow the explicit 16-level catalog through 2600. Achievement migration
from previous releases is outside this delivery's acceptance scope.

## Emulator measurements

Environment: Apple M1 host; Android API 36 ARM64 emulator `maia_test`, four
virtual CPUs, launched with 4096 MB RAM; Flutter 3.47.4 / Dart 3.13.3; debug
integration build. Airplane mode was enabled before the first model extraction.

| Measurement | Result |
| --- | ---: |
| Model size, uncompressed | 307,514,441 bytes |
| First extraction and SHA-256 verification | 6,243 ms |
| Native session initialization after extraction | 902 ms |
| Inference samples | 192 |
| Median inference latency | 70 ms |
| p95 inference latency | 81 ms |
| Process RSS after parity and recovery tests | 1,068,707,840 bytes |
| Peak process RSS | 1,073,172,480 bytes |

Latency includes token encoding, isolate messaging and native inference, but
excludes the application's intentional reply delay. RSS is for the full debug
process, measured after repeated session creation/recovery; it is not an
isolated model allocation or a minimum device RAM specification. These are
emulator measurements, not physical-device performance claims.

The console emits these values as `MAIA3_VALIDATION` JSON. Reproduce them on
an ARM64 device with:

```sh
git lfs pull
flutter pub get
dart run tool/verify_maia3.dart
flutter test integration_test/maia3_acceptance_test.dart -d DEVICE
```

Clear only the dedicated test installation's app data before measuring first
extraction. Test with airplane mode enabled. The integration tests create and
replace local test games.

## Physical devices

No physical Android device was available for this run. First-install loading,
inference latency, sustained memory/thermal behaviour and battery consumption
on physical hardware remain to be measured separately. The 79M FP32 model was
not quantized to reduce size or memory usage.

## Release artifact

`flutter build apk --release --split-per-abi --target-platform android-arm64`
produced `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`:

- Size: **439,678,689 bytes** (439.7 MB decimal).
- SHA-256: `1a85241f1e94f07216e459626051d659a3e2ceea44fa506cc7253a372f4af952`.
- Local release-mode build, signed with the Android debug key; no distribution
  signing key was configured. Nothing was published.
- `dart run tool/verify_apk.dart` passed: exactly one model with the expected
  SHA-256, no `.pb.gz`, lc0 or Leela entries, required Flutter/Stockfish/ONNX
  libraries present, ARM64 ELF segments aligned to at least 16 KB.
- Android `apksigner verify --verbose` passed, and
  `zipalign -c -P 16 4` returned success.
- The final APK was installed on the ARM64 emulator, its app data cleared,
  and launched in airplane mode. All 16 choices appeared; starting as Black
  against Maia-3 600 produced the legal opening move `Nf3` and returned control
  to the player. After that first move, `dumpsys meminfo` reported 738,710 KiB
  PSS and 851,576 KiB RSS for the release process with Stockfish still unloaded.
  This is a single memory snapshot, not a measured release peak.

This APK contains the model plus native runtime. First use installs one
additional 307.5 MB model copy in the app's private storage. No model download
or network permission is required.
