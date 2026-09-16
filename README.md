# Xadrez Maia

Offline Android chess app, built in Flutter/Dart, against an AI that imitates
human playing styles across different rating bands using weights from the
[Maia Chess](https://github.com/CSSLab/maia-chess) project (running on the
lc0 engine). A second AI (Stockfish) provides the objectively best move, for
the hint system. Open source project, distributed as a direct APK (sideload),
with no runtime network dependency.

## How to run

Prerequisites: Flutter **3.47.4** (Dart 3.13.3, matching CI), Android SDK +
NDK `28.2.13676358` installed, JDK 17.

```bash
flutter pub get
flutter run          # with an Android emulator/device connected
flutter analyze
flutter test
flutter test integration_test/phase_4_android_test.dart -d <device>
```

## Checks before pushing

Use the same Flutter version as `.github/workflows/ci.yaml`. When updating
the SDK, update both the workflow and this prerequisite and rerun the checks.

```bash
flutter pub get
dart format lib test integration_test
flutter analyze --no-fatal-infos
dart format --output=none --set-exit-if-changed lib test integration_test
flutter test --coverage
```

Commit the formatting changes before pushing. The CI formatting step only
checks files; it does not apply or commit corrections. Native engine sources
are excluded from this formatting scope.

## Structure

Feature-first organization:

```
lib/
├── core/            # theming, constants
├── engine_ffi/       # lc0 (Maia) and Stockfish services via FFI
├── features/         # game, difficulty, hints, history, stats, settings, pgn
└── data/             # Drift database, repositories, Riverpod providers

native/                # vendored native dependencies
assets/maia_weights/   # Maia .pb.gz weights (1100-1900)
```

There is no dedicated DI folder: Riverpod providers live next to whoever
exposes them (`data/providers.dart` for repositories, and each
controller/service exposes its own, e.g.:
`GameController`/`lc0EngineFactoryProvider`), the idiomatic Riverpod
pattern.
