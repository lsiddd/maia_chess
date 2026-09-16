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

## Android APK and GitHub Releases

The CI workflow runs analysis, formatting, Flutter tests, and release-tool tests.
On pushes to `main` and manual runs, it then builds an ARM64 release APK and
uploads the `android-release` artifact (APK plus `SHA256SUMS`, retained 14 days).
Pull requests run the checks without receiving signing secrets or publishing.

Release signing uses these repository Actions secrets:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded keystore, without line breaks.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: signing alias.
- `ANDROID_KEY_PASSWORD`: private-key password.

Keep a secure backup of the keystore and passwords: future updates must use
the same signing key. Local signing uses the ignored `android/app/key.properties`
and `android/app/release-keystore.jks`. Never commit these files. An app installed
with the development key cannot be updated in place by this release key.

To publish, push a new version tag on the commit you want to distribute:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Use `vX.Y.Z` tags. The tag supplies the APK version name; the workflow run number
supplies its increasing Android version code. After all checks and the signed
build succeed, CI publishes a GitHub Release with the APK, SHA-256 checksum and
generated notes. Tags fail if signing secrets are missing. Main/manual builds
without any signing secrets produce only a development-signed test artifact.
Release names are unique: use a new version tag for a new publication; the
workflow does not overwrite an existing release. ARM64 targets modern Android
devices (Android 7.0/API 24 or later); this APK does not support 32-bit devices.

The Linux runner installs JDK 17, Android SDK 36, NDK `28.2.13676358` and CMake
`3.22.1`. Before uploading, it verifies the APK signature, ARM64 libraries for
Flutter/lc0/Stockfish, all nine Maia weights and ZIP integrity.

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
