# Maia Chess

Maia Chess is an offline Android chess app built with Flutter and Dart. Play
against nine human-style Maia networks, practise with Stockfish assistance, or
play another person on the same device. Games, preferences, campaign progress,
and statistics are stored locally; no account or runtime network connection is
required.

The app bundles the original [Maia networks](https://github.com/CSSLab/maia-chess)
for rating bands 1100–1900 and runs them through lc0 with `go nodes 1`. These
bands describe the human play the models imitate, not a guaranteed opponent
strength. Stockfish independently provides hints and opponent plans.

## Features

- **Free play:** choose any Maia level and play as White or Black.
- **Campaign:** start at Maia 1100 and unlock successive levels by winning two
  games in a rolling window of three rated campaign games. Later losses do not
  revoke an earned qualification; deleting saved games rebuilds progress.
- **Local play:** two players share one device, with tap and drag moves,
  promotion choice, board rotation, animations, and haptic feedback.
- **Persistence:** one active autosave, saved after each move, plus a game
  library with replay and validated UTF-8 PGN import/export through Android's
  file picker and share sheet.
- **Statistics:** an estimated local rating, rating history, results by Maia
  level, and winning streaks. Completed, unassisted AI games count; local and
  imported games do not. The estimate starts at 1500 and uses Elo with K = 32,
  bounded to 600–2400. It is not an online or federation rating.
- **Appearance and accessibility:** light, dark, or system theme; Lichess Brown
  (default), Blue, Green, and Purple boards; Cburnett SVG pieces; square labels,
  semantic move actions, and last-move/result announcements. Appearance settings
  also apply to replays. The screen stays awake while a game screen is active.

The application target is **Android 7.0/API 24 or later**, using `arm64-v8a` or
`x86_64`. Published APKs contain ARM64 only. The lc0 plugin contains an iOS
example, but the main app has no iOS, desktop, or web runner. Clock fields and
preferences exist in storage; a playable timed-game mode is not implemented.

## Game tools

The toolbar offers **Undo**, **Hint**, **Attacks**, **Plans**, and **More**.
**More** includes restart, rotation, save, appearance, an attack filter, and help.
The board fits within the available safe area in portrait and landscape;
loading indicators and errors do not change its geometry.

**Hint** highlights only the origin of a Stockfish move with an amber outline.
Tap it again or interact with the board to clear it. Position changes and app
suspension invalidate pending results. Hint failure does not dispose Maia.

**Attacks** highlights attacked pieces: orange for no geometric defence, double
blue for defended pieces. Pinned attackers count; legal en passant also marks
its captured pawn. These highlights do not prove a material gain or loss. The
visibility toggle and own-pieces-only filter are saved locally.

**Plans** displays one Stockfish candidate for a hypothetical opponent turn.
The counter switches between up to three candidates. These are possible plans,
not proven threats or predictions of Maia's reply. Analysis shares Stockfish
with hints and pauses during check, Maia's turn, hints, or suspension.

Assistance and undo make a game **unrated**, excluding it from rating, streaks,
and campaign progress. Undo returns to the previous human decision against
Maia, or takes back one ply in local play. The collapsed move history opens an
independent review panel; **Current position** returns that panel to the live
position without changing the game.

## Set up and run

Use the toolchain pinned in [.github/workflows/ci.yaml](.github/workflows/ci.yaml):

| Tool | Project configuration |
| --- | --- |
| Flutter / Dart | Flutter 3.47.4 / Dart 3.13.3 in CI; package SDK constraint `^3.11.5` |
| Java | JDK 17 |
| Android SDK | Platform 36 and build tools 36.0.0 |
| Android NDK | 28.2.13676358 |
| CMake | 3.22.1 |

Install Flutter and the Android SDK, add their command-line tools to `PATH`,
and configure `ANDROID_HOME` if the SDK is outside its default location. Install
the native tools with `sdkmanager` from the Android command-line tools:

```sh
sdkmanager 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'
flutter doctor --android-licenses
flutter doctor -v
flutter pub get
flutter devices
flutter run -d DEVICE
```

Replace `DEVICE` with a connected Android device or emulator ID. Use a 64-bit
emulator. Dependencies and the Android CMake build require network access during
setup, including fetching Eigen 3.4.0; the installed app runs offline. All nine
Maia weight files are already tracked. No `.env` file, server, API key, or runtime
environment variables are needed.

## Development and validation

Run from the repository root:

```sh
dart format lib test integration_test test_driver
flutter analyze --no-fatal-infos
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter test --coverage
python3 -m unittest discover -s scripts -p 'test_*.py'
```

For native engines and SQLite on Android, run these suites **sequentially**:

```sh
flutter test integration_test/android_acceptance_test.dart -d DEVICE
flutter test integration_test/phase_0_3_android_test.dart -d DEVICE
```

[CONTRIBUTING.md](CONTRIBUTING.md) explains test scope, code generation,
performance measurements, and English commit conventions. Historical
[interaction](docs/interaction-validation.md) and
[performance](docs/performance-validation.md) reports preserve their original
measurement dates and limitations.

## Build and distribution

```sh
flutter build apk --release --split-per-abi --target-platform android-arm64
python3 scripts/verify_apk.py build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

This creates `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Local
release builds use the debug signing key unless `android/app/key.properties`
is configured. The content verifier checks packaging and ZIP integrity;
`apksigner` separately verifies the signature.

CI checks pull requests. Successful signed pushes to `main` update the
[Nightly pre-release](https://github.com/lsiddd/maia_chess/releases/tag/nightly);
`vX.Y.Z` tags publish stable releases. See
[Android releases](docs/android-releases.md) for signing secrets, local signing,
artifacts, versioning, and retries. Install the APK through Android's package
installer after enabling installation from the source used to download it.

## Architecture and repository layout

Riverpod controllers coordinate the feature UI, chess rules, repositories, and
engine services. Drift runs SQLite in the background; PGN validation and derived
statistics also run on workers. See [architecture](docs/architecture.md) for
state, persistence, engine lifecycle, and eligibility rules.

```text
lib/
  main.dart             App bootstrap and home screen
  core/                 Assets, themes, and shared widgets
  data/                 Drift schema, repositories, and providers
  engine_ffi/           lc0/Stockfish services and UCI waiters
  features/             Difficulty, game, hints, history, PGN, settings, stats, tactics
android/                Main application runner and signing/build configuration
native/leela_chess_zero/ Local lc0 plugin, native sources, and standalone example
assets/                 Maia networks, board images, piece SVGs, and attribution
scripts/                Signing setup, APK verification, and Python tests
test/                   Unit, widget, persistence, and regression tests
integration_test/       Android acceptance tests and profile benchmarks
test_driver/            Profile report writers
docs/                   Architecture, releases, audit notes, and measurement records
```

## Troubleshooting

- **Native build fails:** check SDK, NDK, CMake, and Java versions against the
  table above, and allow CMake to fetch Eigen. The local lc0 fork is required;
  substituting the hosted plugin is not covered by this project's checks.
- **No suitable device:** use an ARM64 device or x86_64/ARM64 emulator. A 32-bit
  Android device cannot run the bundled engines.
- **First game or hint loads slowly:** weights extraction and native network
  loading precede the UCI readiness handshake. Allow startup to finish; use
  **Try again** if Maia reports a failure. For failed hints or plans, use the
  retry action described in the UI.
- **APK update cannot be installed:** the existing installation may use a
  different signing key. Uninstalling removes local app data, so export useful
  games as PGN first.
- **Tests/builds interfere:** run Android targets sequentially. After integration
  tests, use the normal production build command so Flutter refreshes dependency
  registration; `--no-pub` can retain an integration-test plugin registrant.

## Attribution

Bundled third-party material has its own notices and licences:
[Maia networks](assets/maia_weights/NOTICE.md),
[Cburnett pieces](assets/chess_pieces/NOTICE.md),
[Lichess boards](assets/chess_boards/NOTICE.md), and the
[lc0 plugin](native/leela_chess_zero/LICENSE). Review those terms before
redistribution. This repository currently has no root application licence;
no project-wide licence is inferred from dependency licences. Outstanding
limitations and preserved language exceptions are recorded in the
[documentation audit](docs/documentation-audit.md).
