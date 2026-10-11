# Xadrez Maia

Offline Android chess app, built in Flutter/Dart, against an AI that imitates
human playing styles across different rating bands using weights from the
[Maia Chess](https://github.com/CSSLab/maia-chess) project (running on the
lc0 engine). A second AI (Stockfish) provides the objectively best move, for
the hint system. Open source project, distributed as a direct APK (sideload),
with no runtime network dependency.

The appearance menu (home palette icon or **Mais → Configurações** in a game) offers light,
dark and system modes, plus the original Lichess Brown, Blue, Green and Purple
boards. Brown is the default (#F0D9B5 / #B58863). The app bundles the Lichess
Cburnett SVG pieces and board images for offline use; selections are saved
locally and also apply to game replays. Sources, authors and licenses are in
`assets/chess_pieces/NOTICE.md` and `assets/chess_boards/NOTICE.md`, and available
under **Aparência → Créditos e licenças** in the app.

## Game screen and tactical aids

The board fits both available axes inside the system safe areas. Its geometry
stays fixed when tools load, fail, or change state. The toolbar contains
**Desfazer**, **Dica**, **Ataques**, **Planos** and **Mais**; landscape layouts
place the controls beside the board. **Mais** contains restart, rotation,
manual save, appearance, the attack filter and contextual help. Restart asks
for confirmation when moves have been played. Autosave and resume remain active.

**Dica** uses Stockfish exclusively and highlights only the origin square with
an amber outline, without a dialog or destination. Tap again or interact with
the board to clear it. Loading stays in the button. Pending hints are cancelled
on interaction, position changes and suspension; hint failures do not dispose
Maia, which only selects the opponent's moves.

**Ataques** draws an orange square border for attacked pieces without geometric
defence and a rounded double blue border for attacked, defended pieces. These
are geometric attacks (including pinned attackers), not a verdict about tactical
material loss. Legal en passant also marks the captured pawn. Both the toggle
and the own-pieces-only filter are saved locally. Help is available in **Mais**.

**Planos do adversário** shows one Stockfish candidate at a time for a hypothetical
opponent turn. The compact counter switches candidates. These are plans, not
proven threats or a prediction of Maia's move. Searches use MultiPV in the
background, are serialized with hints and discard stale results. Analysis pauses
in check, during Maia's turn, while calculating a hint and on app suspension.
No SAN, evaluations or legends are inserted above the board.

The collapsed history shows recent move pairs. Tap it to open a separate review
panel with a board, scrollable move pairs, selected-move highlight and
**Posição atual**. Review never changes the live game. Assistance and undo remove
the game from rating and campaign progression; undo returns to the human decision
against Maia and removes one ply in local play.

Run the native MultiPV smoke test on Android with
`flutter test integration_test/tactics_android_test.dart -d <device>`.

Run the Android acceptance suite (native Stockfish, SQLite, campaign, game UI,
promotion, castling and check escapes) with:

```bash
flutter test integration_test/android_acceptance_test.dart -d <device>
flutter test integration_test/phase_0_3_android_test.dart -d <device>
```

For the game-screen matrix, set the emulator display size, font scale and
navigation mode, then rerun `integration_test/section_2_android_test.dart`.
It checks fixed board geometry, origin-only hints, single-plan arrows, history
review, preferences, reset confirmation and resume using real engines/storage.

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
dart format lib test integration_test test_driver
flutter analyze --no-fatal-infos
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter test --coverage
python3 -m unittest discover -s scripts -p 'test_*.py'
```

Commit the formatting changes before pushing. The CI formatting step only
checks files; it does not apply or commit corrections. Native engine sources
are excluded from this formatting scope.

## Android APK and GitHub Releases

The CI workflow runs analysis, formatting, Flutter tests, and release-tool tests.
On pushes to `main` and manual runs, it then builds an ARM64 release APK and
uploads the `android-release` artifact (APK plus `SHA256SUMS`, retained 14 days).
Pull requests run the checks without receiving signing secrets or publishing.

Every push to `main` that passes the checks and signed build automatically
creates or updates the [Nightly pre-release](https://github.com/lsiddd/maia_chess/releases/tag/nightly).
The moving `nightly` tag points to the built commit, with
`maia-chess-nightly-arm64-v8a.apk`, `SHA256SUMS`, and notes linking to the commit
and CI run. The same release is updated in place and does not replace the
latest stable release. Publication is serialized; builds superseded by a newer
commit on `main` skip publication so they cannot replace a newer nightly.

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
generated notes. Tags and pushes to `main` fail if signing secrets are missing;
nightlies use the same signing key as stable releases. Manual builds without a
release tag or any signing secrets produce a development-signed test artifact.
Stable release names are unique: use a new version tag for a new publication;
the workflow only overwrites the `nightly` pre-release. ARM64 targets modern Android
devices (Android 7.0/API 24 or later); this APK does not support 32-bit devices.

If infrastructure fails before publication, fix the workflow on `main`, then
use **Actions → CI → Run workflow** on `main` with `release_tag` set to the
existing tag. This uses the corrected workflow while checking out and building
the exact tagged source. Leaving this input empty builds an artifact only.

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
