# Technical Audit: Xadrez Maia (maia_chess)

Audit performed by a full read of `lib/` (30 files, 6,177 lines not counting
generated code), `test/`, `integration_test/`, `android/`, `pubspec.yaml`,
`analysis_options.yaml`, and running the static analysis tools. Every
finding below cites a file and line; where the evidence is a command's
output, the command and its result are reproduced.

## Fix status

Report approved and fixed in reviewable batches (one commit per category,
`flutter analyze`/`flutter test` green on each). Full history in `git log`.

| ID | Finding | Status |
|---|---|---|
| AUD-001 | No version control | Fixed: `git init` + initial commit |
| AUD-002 | No CI pipeline | Fixed: `.github/workflows/ci.yaml` |
| AUD-003 | 0% coverage in lc0_service/stockfish_service | Partial: wait logic extracted to `uci_wait.dart` and tested (88%); `init()` remains verifiable only via `integration_test/` (see ADR-013 in the corresponding commit and the scope correction below) |
| AUD-004 | new_game_vs_ai_screen.dart barely tested | Fixed: 2% → 83% |
| AUD-005 | promotion_dialog/hint_dialog untested | Fixed: 0%/0% → 100%/98% |
| AUD-006 | Release signed with the debug key | Partial: `build.gradle.kts` ready for a real key via `key.properties`; generating the keystore itself is blocked by the session's permission classifier, documented in ADR-013 for the project owner to run |
| AUD-007 | minify/shrink decision not recorded | Fixed: ADR-011 |
| AUD-008 | Implicit allowBackup | Fixed: explicit in the Manifest |
| AUD-009 | Duplicated playerOutcome | Fixed: single function in `game_repository.dart` |
| AUD-010 | Dead SpikeScreen | Fixed: removed |
| AUD-011 | Clock fields with no UI or logic | Fixed (documented): ADR-012 |
| AUD-012 | Empty core/theming and core/di | Fixed: `AppTheme` extracted, `core/di` removed |
| AUD-013 | Dependencies with a newer major available | Not applied: `flutter_riverpod` 2.x→3.x and `share_plus` 12→13 are breaking major bumps; the regression risk cannot be verified with this project's tests without dedicating a separate batch to it, as the finding itself already recommended |
| AUD-014 | Lint limited to the flutter_lints default set | Fixed: 7 additional rules, a 5-occurrence diff |
| AUD-015 | dart format fails on the vendored package | Fixed: CI restricted to `lib test integration_test` |

Test coverage after the batches: **53.2%** (2,355/4,425 lines), up from
50.4% in the original report.

## Executive summary

- 🔴 Critical: 0
- 🟠 High: 4
- 🟡 Medium: 5
- 🟢 Low: 5
- Informational (out of the app's scope): 1
- Test coverage (`flutter test --coverage`, unit/widget): **50.4%**
  (2,243/4,451 instrumented lines). The two files with the app's most
  delicate logic, `lc0_service.dart` and `stockfish_service.dart`, are at
  **0%**: only exercised by `integration_test/` on a real device.
- Detected stack: Riverpod (`flutter_riverpod` 2.6.1, `Notifier`/
  `ConsumerWidget`, no mixing with raw `setState` outside purely local
  visual state), feature-first architecture with a `data/repositories`
  layer separate from the UI (repository pattern + Drift/SQLite),
  consistent organization across all modules. Flutter 3.41.9 (via `fvm`) •
  Dart 3.11.5 • minSdk 24 / targetSdk 36 / compileSdk 36.
- `flutter analyze --no-fatal-infos`: **no issues found**.
- `flutter test`: **50/50 tests passing**.
- The project **was not under version control** (no `.git` directory) and
  **had no CI/CD pipeline** (see AUD-001/AUD-002).

Overall code quality is high by this checklist's standards: no `print()`,
no empty `catch` or one that merely swallows the exception, `context.mounted`/
`mounted` usage after `await` is correct at every point checked, no
hardcoded secrets/keys, the app requests no network permission in
`AndroidManifest.xml` (consistent with the promise of a 100% offline app),
and the decision history in `ADR.md` honestly documents concurrency bugs
already found and fixed (a race in the FFI engines' `dispose()`, a
`stdin`/`stdout` collision between lc0 and Stockfish). The findings below
are, therefore, mostly process-related (versioning, CI, coverage) and
targeted technical debt, not correctness issues in the chess domain itself.

## Top 10 priorities (recommended order of action)

1. **AUD-001**: Initialize the git repository before any other action (prerequisite for the following items).
2. **AUD-006**: Replace the debug signature in the release build before any real APK distribution.
3. **AUD-002**: Add a minimal CI pipeline (`flutter analyze`, `dart format --set-exit-if-changed lib test integration_test`, `flutter test --coverage`).
4. **AUD-003**: Cover `Lc0Service`/`StockfishService` with tests that directly exercise the handshake, the timeout, and the `dispose()` routine (not only via `GameController` with fakes).
5. **AUD-009**: Unify the `PlayerGameOutcome` calculation rule, currently duplicated in `app_database.dart` and `drift_stats_repository.dart`.
6. **AUD-004**: Write widget tests for `NewGameVsAiScreen` (entry screen for AI mode, 2% coverage).
7. **AUD-007**: Explicitly decide on `minifyEnabled`/`shrinkResources` and, if enabled, add a `proguard-rules.pro` covering Drift/FFI before testing in release.
8. **AUD-010**: Remove or move `SpikeScreen` out of `lib/` (Phase 0 debt, no route reaches it).
9. **AUD-011**: Decide the fate of `clockEnabled`/`whiteTimeMs`/`blackTimeMs`: implement the clock countdown or remove the field until the feature is prioritized.
10. **AUD-014**: Evaluate additional lint rules (e.g., `very_good_analysis` or manual `analysis_options.yaml` rules) beyond the `flutter_lints` default.

## Detailed findings

### CI/CD, version control, and tooling (section 6.15)

#### [AUD-001] 🟠 No version control
- **Category:** 6.15, CI/CD and tooling
- **File:** project root (`/home/lucas/maia_android`)
- **Evidence:** `ls -la /home/lucas/maia_android/.git` returns "No such file
  or directory"; the session environment also reports `Is a git
  repository: false`. At the same time, `ADR.md` (ADR-001, addendum)
  describes generated files that "are committed in this repository", and
  `.gitignore` has specific rules to avoid versioning native build
  artifacts — that is, the project was designed assuming version control,
  but was not under one.
- **Problem:** without git there is no history, no way to review diffs,
  revert a change that breaks the native build (which has already proven
  fragile, see the three ADR-001 addenda), or open a pull request for the
  batch process described in section 2 of this very audit process. Any CI
  also needs a repository to exist.
- **Suggestion:** `git init`, an initial commit covering the current state
  (excluding `build/`, `.dart_tool/`, etc., already covered by the existing
  `.gitignore`), and adopting a branch workflow before the next change.
- **Estimated effort:** S

#### [AUD-002] 🟠 No CI/CD pipeline configured
- **Category:** 6.15, CI/CD and tooling
- **File:** N/A. Absence confirmed in `.github/workflows`,
  `.gitlab-ci.yml`, `codemagic.yaml`, and `bitrise.yml` at the project
  root. The three `.gitlab-ci.yml` files found by `find` belong to Eigen, a
  vendored third-party dependency inside
  `native/leela_chess_zero/android/.cxx/.../eigen-src/`, not the project.
- **Evidence:** `find /home/lucas/maia_android -maxdepth 2 -iname "*.yml" -o -iname "*.yaml"` only returns `analysis_options.yaml` and `pubspec.yaml`.
- **Problem:** `ADR.md` itself documents at least two serious concurrency
  bugs (a `dispose()` race between FFI engines; a `stdin`/`stdout`
  collision between lc0 and Stockfish) that were only caught through manual
  integration testing on an emulator. Without CI running `flutter
  analyze`, `dart format --set-exit-if-changed`, and the test suite on
  every change, regressions of this kind can silently return.
- **Suggestion:** a minimal workflow (GitHub Actions or equivalent) with
  this audit process's three Phase 1 gates. `integration_test/` depends on
  an Android emulator and can be left out of the mandatory gate initially,
  but the unit/widget tests (50 today, all passing) have no such
  restriction.
- **Estimated effort:** S

### Tests (section 6.10)

#### [AUD-003] 🟠 0% coverage in the FFI engine services
- **Category:** 6.10, Tests
- **File:** `lib/engine_ffi/lc0_engine/lc0_service.dart` (0/138 lines),
  `lib/engine_ffi/stockfish_engine/stockfish_service.dart` (0/132 lines)
- **Evidence:** direct calculation over the `coverage/lcov.info` generated
  by `flutter test --coverage`:
  ```
  lib/engine_ffi/lc0_engine/lc0_service.dart          0/138 (0%)
  lib/engine_ffi/stockfish_engine/stockfish_service.dart  0/132 (0%)
  ```
  `test/game_controller_test.dart` tests `GameController` using fakes
  injected via `lc0EngineFactoryProvider`/`stockfishEngineFactoryProvider`
  (see `game_controller.dart:23-28`), by design (ADR-008), so as not to
  depend on FFI in unit tests. This, however, means the real
  `Lc0Service`/`StockfishService` implementation (the `isready`/`readyok`
  handshake, search timeout with `stop`, and the `_terminateEngine` routine
  that avoids the `Bad state: Multiple instances are not supported`
  documented in ADR-001) is only exercised by the
  `integration_test/*_android_test.dart` files, which require an
  emulator/physical device and do not run under `flutter test`.
- **Problem:** exactly the logic that has already caused two documented
  production bugs in `ADR.md` itself has no automated safety net outside
  manual execution on a device. A regression in this area would only be
  noticed by manually playing against the AI.
- **Suggestion:** extract the state-waiting logic (`_waitReadyOk`,
  `_terminateEngine`, timeout handling with `stop`) so it can be tested
  with a fake `Lc0`/`Stockfish` that simulates state transitions
  (`Lc0State`/`StockfishState`) via `ValueNotifier`, without needing real
  FFI. The packages already expose these classes as injectable.
- **Estimated effort:** M

#### [AUD-004] 🟡 New game vs. AI screen nearly untested
- **Category:** 6.10, Tests
- **File:** `lib/features/difficulty/presentation/new_game_vs_ai_screen.dart`
- **Evidence:** `coverage/lcov.info` reports 1/45 lines (2%) covered for
  this file; there is no test in `test/` that imports `NewGameVsAiScreen`.
- **Problem:** this is the main entry point for "free mode against the AI"
  (side/level selection, `new_game_vs_ai_screen.dart:24-49`), including the
  error path when `startVsAi` fails (lines 33-41). None of these paths has
  widget test coverage.
- **Suggestion:** a widget test covering side/level selection and the
  error SnackBar when `controller.startVsAi` returns `false`, following the
  same pattern as `test/game_screen_responsive_test.dart`.
- **Estimated effort:** S

#### [AUD-005] 🟡 Promotion and hint dialogs with no widget test at all
- **Category:** 6.10, Tests
- **File:** `lib/features/game/presentation/promotion_dialog.dart` (0/11),
  `lib/features/hints/presentation/hint_dialog.dart` (0/41)
- **Evidence:** `coverage/lcov.info` reports 0% for both files.
- **Problem:** `promotion_dialog.dart` fires on every promotion move
  (covered by chess-rule tests, but with no UI test for the dialog
  itself); `hint_dialog.dart` covers the three `FutureBuilder` states
  (loading, error, success with both moves side by side) with no test
  forcing the error path (`snapshot.hasError`, `hint_dialog.dart:36-56`).
- **Suggestion:** isolated widget tests, with a manually controlled
  `Future` (`Completer`) to force each of the three `FutureBuilder` states.
- **Estimated effort:** S

### Android-specific: Gradle/Manifest/build (section 6.12)

#### [AUD-006] 🟠 Release build signed with the debug key
- **Category:** 6.12, Android-specific
- **File:** `android/app/build.gradle.kts:40-45`
- **Evidence:**
  ```kotlin
  buildTypes {
      release {
          // TODO: Add your own signing config for the release build.
          // Signing with the debug keys for now, so `flutter run --release` works.
          signingConfig = signingConfigs.getByName("debug")
      }
  }
  ```
- **Problem:** every `flutter build apk --release` generated today is
  signed with the debug key (shared across every Flutter/Android Studio
  development environment, not safely rotatable). This blocks publishing
  to any channel that requires a proper release signature and, more
  seriously, an APK distributed this way by mistake would have a
  predictable/shared signing key.
- **Suggestion:** generate a dedicated release keystore, configure it via
  `key.properties` (not committed) read from `build.gradle.kts`, as the
  existing TODO already indicates. Already flagged by the team as pending
  for Phase 7 ("final packaging"); this finding merely formalizes the
  priority.
- **Estimated effort:** S

#### [AUD-007] 🟡 No resource minification/shrinking or ProGuard/R8 rules in release
- **Category:** 6.12, Android-specific
- **File:** `android/app/build.gradle.kts:40-46`; no `proguard-rules.pro`
  file found under `android/app/`.
- **Evidence:** the `release {}` block only sets `signingConfig` (see
  AUD-006); `minifyEnabled`/`shrinkResources` do not appear anywhere in the
  file, so they default to `false` in the Android Gradle Plugin. `find
  android -iname "proguard*"` returned no files.
- **Problem:** the release APK comes out larger and without native
  Dart/Kotlin code obfuscation. Not urgent for an open source app
  distributed by sideload (there is no trade secret obfuscation would
  protect), but it is the recommended default configuration, and if
  enabled in the future without ProGuard/R8 rules for Drift (reflection via
  `sqlite3`) and the FFI plugins (`leela_chess_zero`, `stockfish`), the app
  runs a real risk of "works in debug, breaks in release", the classic
  symptom of checklist item 6.12.
- **Suggestion:** an explicit decision recorded in an ADR: keep it off (and
  document why) or enable it with a `proguard-rules.pro` tested against a
  real release build on a device, covering the FFI and Drift points.
- **Estimated effort:** S (document decision) / M (if enabling and validating)

#### [AUD-008] 🟢 `android:allowBackup` not explicitly set
- **Category:** 6.11/6.12, Security / Android
- **File:** `android/app/src/main/AndroidManifest.xml:2-4`
- **Evidence:** the `<application>` tag does not declare
  `android:allowBackup`, so it inherits Android's `true` default: the
  `maia_chess.sqlite` database (games, campaign progress, settings) is
  included in the user's automatic Android backup to their Google account.
- **Problem:** the stored data is not sensitive (local chess games, no
  account or personal data), so the actual risk is low; still, this is a
  security setting currently inherited by omission, not by decision.
- **Suggestion:** an explicit decision between `android:allowBackup="true"`
  (keeping current behavior, but documented) and `"false"`, according to
  the team's preference for the device-restore experience.
- **Estimated effort:** S

### Code quality, smells, and technical debt (section 6.9)

#### [AUD-009] 🟡 Duplicated business rule: player outcome calculation
- **Category:** 6.9 / 6.1, Smells / duplicated logic
- **File:** `lib/data/local/app_database.dart:224-240` (`_evaluatedSummary`) and `lib/data/repositories/drift_stats_repository.dart:72-91` (`_summary` + `playerOutcome`)
- **Evidence:** the two functions independently implement the same rule
  ("win if the player's side matches the result, draw if `draw`, otherwise
  loss"):
  ```dart
  // app_database.dart:227-232
  final outcome = result == StoredGameResult.draw
      ? PlayerGameOutcome.draw
      : (side == Side.white && result == StoredGameResult.whiteWin) ||
            (side == Side.black && result == StoredGameResult.blackWin)
      ? PlayerGameOutcome.win
      : PlayerGameOutcome.loss;
  ```
  ```dart
  // drift_stats_repository.dart:85-91
  PlayerGameOutcome playerOutcome(StoredGameResult result, Side playerSide) {
    if (result == StoredGameResult.draw) return PlayerGameOutcome.draw;
    final playerWon =
        (playerSide == Side.white && result == StoredGameResult.whiteWin) ||
        (playerSide == Side.black && result == StoredGameResult.blackWin);
    return playerWon ? PlayerGameOutcome.win : PlayerGameOutcome.loss;
  }
  ```
- **Problem:** today the two copies are in fact behaviorally identical, but
  nothing prevents one from being changed (e.g., a new `StoredGameResult`
  variant) without the other following along, exactly the scenario
  described in checklist item 6.1 ("duplicated formulas in two places with
  small divergences"). `rebuildDerivedState` (called on every game
  completion/deletion) and `DriftStatsRepository.watch()` (used by the
  stats screen) could silently diverge.
- **Suggestion:** move `playerOutcome` to `player_stats.dart` (where
  `PlayerGameOutcome`/`EvaluatedGameSummary` already live) and use it at
  both database read points.
- **Estimated effort:** S

#### [AUD-010] 🟡 `SpikeScreen` is dead code
- **Category:** 6.9, Smells / dead code
- **File:** `lib/features/spike/spike_screen.dart` (178 lines)
- **Evidence:** `grep -rn "SpikeScreen" lib/ test/ integration_test/` only
  returns the class's own declaration; no route in `main.dart` or any other
  widget references it.
- **Problem:** the Phase 0 diagnostic screen (initial validation that
  lc0/Stockfish responded via FFI) served its purpose but stayed in the
  binary: it adds ~180 lines and two unused `Lc0Service`/`StockfishService`
  instances to the APK, besides confusing anyone browsing the `features/`
  tree looking for active screens.
- **Suggestion:** move it to `integration_test/` (as a manual harness, if
  still useful for debugging) or remove it; if deliberately kept as a
  diagnostic tool, add an explicit hidden/debug route and a comment in
  `README.md` justifying its presence.
- **Estimated effort:** S

#### [AUD-011] 🟢 Chess clock modeled across 4 layers with no countdown logic at all
- **Category:** 6.9 / 6.8, Smells / organization
- **File:** `lib/features/game/application/game_state.dart:39-42,123-126`;
  `lib/data/repositories/game_repository.dart:54-57,74-77`;
  `lib/data/local/app_database.dart:35-38`;
  `lib/data/repositories/drift_game_repository.dart:158-161,233-236`
- **Evidence:** `clockEnabled`/`initialTimeMs`/`whiteTimeMs`/`blackTimeMs`
  exist in `GameState`, `StoredGame`, the Drift `Games` table, and the
  entire persistence path (confirmed search with `grep -rn
  "clockEnabled\|whiteTimeMs\|blackTimeMs" lib/`), but no `Timer`/countdown
  decrements them and no screen displays a clock: `_StatusBar` in
  `game_screen.dart` does not reference any of these fields.
- **Problem:** not a bug (the value just sits idle, without affecting the
  game), but it is dead surface across four layers simultaneously, with a
  maintenance cost for anyone reading the schema and assuming the feature
  exists.
- **Suggestion:** if the clock is a feature planned for Phases 6-7 (the
  README mentions "personalization" as pending), record this explicitly in
  `ADR.md`/`docs/especificacao.md` so it doesn't look forgotten; otherwise,
  remove the fields until the feature is prioritized.
- **Estimated effort:** S (document) / M (remove or implement)

### Architecture and folder organization (section 6.8)

#### [AUD-012] 🟢 Empty `core/theming` and `core/di`
- **Category:** 6.8, Architecture and organization
- **File:** `lib/core/theming/`, `lib/core/di/`
- **Evidence:** `find lib/core/theming lib/core/di -type f` returns no
  files; the theme is defined inline in `main.dart:27-37`
  (`ThemeData`/`darkTheme`), and dependency injection is done via Riverpod
  providers spread across `data/providers.dart` and `game_controller.dart`,
  not in `core/di`.
- **Problem:** these folders were created by the initial scaffolding (the
  README lists them in the "Structure" section) but never received any
  content. Not a bug per se, but it indicates the documented README
  structure slightly diverges from the real one.
- **Suggestion:** move `ThemeData` from `main.dart` into
  `core/theming/app_theme.dart` (consistent with the rest of the
  feature-first organization) or remove the empty folders and update the
  README.
- **Estimated effort:** S

### Dependencies (section 6.13)

#### [AUD-013] 🟢 Two direct dependencies with a newer major version already resolvable
- **Category:** 6.13, Dependencies
- **File:** `pubspec.yaml:11,19`
- **Evidence:** `flutter pub outdated`:
  ```
  flutter_riverpod   *2.6.1    *2.6.1      *3.3.2      3.4.2
  share_plus         *12.0.2   *12.0.2     13.3.0      13.3.0
  ```
- **Problem:** both have an entire new major version already resolvable
  alongside the project's other dependencies (the "Resolvable" column), not
  just transitively. There is no indication of a known vulnerability in the
  current versions, but the project is a full major version behind on two
  central dependencies (state management and PGN sharing).
- **Suggestion:** evaluate `riverpod` 3.x's changelog (non-trivial API
  changes between major versions) and `share_plus` 13.x at a dedicated
  moment, separate from other changes, with the test suite as a safety net.
- **Estimated effort:** M

### Lint and static analysis (section 6.9 / Phase 1)

#### [AUD-014] 🟢 `analysis_options.yaml` uses only the `flutter_lints` default set
- **Category:** 6.9, Code quality
- **File:** `analysis_options.yaml:10,30-33`
- **Evidence:**
  ```yaml
  include: package:flutter_lints/flutter.yaml
  ...
  linter:
    rules:
      # avoid_print: false  # Uncomment to disable the `avoid_print` rule
      # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule
  ```
  No rule is added beyond the default set; `flutter analyze
  --no-fatal-infos` already runs clean today ("No issues found!"), which
  suggests the code would also pass a stricter set.
- **Problem:** the `flutter_lints` default is deliberately permissive. A
  stricter set (`very_good_analysis`, or manual rules like
  `public_member_api_docs`, `prefer_final_locals`, `avoid_dynamic_calls`)
  would catch style regressions before they reach human review, especially
  relevant given the volume of autonomously generated code that `ADR.md`
  describes.
- **Suggestion:** try `very_good_analysis` on a branch and evaluate the
  volume of required adjustments before adopting it.
- **Estimated effort:** S

### Informational (outside `lib/`'s scope)

#### [AUD-015] ℹ️ `dart format --set-exit-if-changed .` fails because of the vendored package
- **Category:** Phase 1, automated static analysis
- **File:** `native/leela_chess_zero/example/lib/main.dart`,
  `native/leela_chess_zero/lib/lc0.dart`,
  `native/leela_chess_zero/lib/src/lc0_state.dart`
- **Evidence:**
  ```
  $ dart format --output=none --set-exit-if-changed .
  Changed native/leela_chess_zero/example/lib/main.dart
  Changed native/leela_chess_zero/lib/lc0.dart
  Changed native/leela_chess_zero/lib/src/lc0_state.dart
  Formatted 49 files (3 changed) in 0.29 seconds.
  ```
  The three files belong to the vendored third-party package (ADR-001),
  already excluded from `flutter analyze` via `analyzer.exclude:
  [native/**]` in `analysis_options.yaml:14-17`, but `dart format .` does
  not respect that `exclude` since it runs outside the analyzer.
- **Problem:** not a problem with the app's own code; it is purely a
  consequence of running this process's generic Phase 1 command over the
  entire directory. If a CI gate (AUD-002) adopts `dart format
  --set-exit-if-changed .` literally, it will always fail because of the
  vendored code, masking real regressions in the app's own code.
- **Suggestion:** in CI, restrict the command to `dart format
  --set-exit-if-changed lib test integration_test`, mirroring the same
  `native/**` exclude already used by the analyzer.
- **Estimated effort:** S

## Appendices

### Commands run (Phase 0/1)

```
$ flutter --version
Flutter 3.41.9 • channel stable • Dart 3.11.5 • DevTools 2.54.2

$ flutter analyze --no-fatal-infos
Analyzing maia_android...
No issues found! (ran in 1.6s)

$ flutter test --coverage
00:03 +50: All tests passed!

$ flutter pub outdated
(see AUD-013 for the relevant lines)
```

### Coverage per file (extracted from `coverage/lcov.info`)

| File | Coverage |
|---|---|
| `lc0_service.dart` | 0% (0/138) |
| `stockfish_service.dart` | 0% (0/132) |
| `promotion_dialog.dart` | 0% (0/11) |
| `hint_dialog.dart` | 0% (0/41) |
| `new_game_vs_ai_screen.dart` | 2% (1/45) |
| `app_database.g.dart` (generated) | 29% (545/1894) |
| `providers.dart` | 33% (8/24) |
| `main.dart` | 51% (42/83) |
| `app_database.dart` | 57% (81/143) |
| `history_screen.dart` | 61% (92/152) |
| `game_replayer.dart` | 69% (24/35) |
| `difficulty_levels.dart` | 71% (5/7) |
| `game_screen.dart` | 73% (160/218) |
| `campaign_screen.dart` | 74% (111/150) |
| `chess_board_widget.dart` | 76% (107/141) |
| `drift_progress_repository.dart` | 79% (15/19) |
| `drift_settings_repository.dart` | 79% (23/29) |
| `game_controller.dart` | 79% (319/403) |
| `pgn_service.dart` | 81% (127/156) |
| `drift_game_repository.dart` | 86% (140/163) |
| `player_stats.dart` | 93% (66/71) |
| `stats_screen.dart` | 93% (195/210) |
| `drift_stats_repository.dart` | 94% (48/51) |
| `game_state.dart` | 99% (80/81) |
| `piece_assets.dart`, `game_repository.dart`, `progress_repository.dart`, `settings_repository.dart`, `chess_piece_widget.dart`, `hint_result.dart` | 100% |

### Methodological caveat

This audit was carried out through static reading and running analysis
tools; it did not involve installing the app on a physical device or
measuring real-world performance (lc0/Stockfish CPU/memory usage on real
hardware), which `ADR.md` itself already flags as a Phase 7 open item
("Open question", at the end of ADR-001). The checklist's performance
items (section 6.4) produced no findings because reading the code did not
reveal the patterns being searched for (`FutureBuilder` recreating its
`Future` on every build, large lists without `.builder`, missing `const`
in hot paths). The board uses `GridView.builder` with 64 fixed items, and
`RepaintBoundary` is already present in `ChessPieceWidget`
(`chess_piece_widget.dart:21`).
