# Contributing

Start with the [README](README.md) for the pinned Android toolchain and setup,
and [architecture](docs/architecture.md) for the current implementation. Run all
commands below from the repository root unless a different directory is shown.

## Change scope

Keep changes focused and document the behaviour that the source actually
implements. Update relevant tests and user-facing English text together. Keep
identifiers, stored enum names, asset paths, UCI commands, PGN tags, and migration
contracts stable unless the change explicitly requires a migration.

The Maia-3 model is tracked by Git LFS. Run `git lfs pull` and
`dart run tool/verify_maia3.dart` before building. Model handling lives in Dart;
no Python conversion tools or sources are required. Native inference changes
need Android integration validation; fake engines cannot establish FFI safety.

## Checks

Use Flutter 3.47.4 / Dart 3.13.3, matching CI. When changing the SDK pin, update
[the workflow](.github/workflows/ci.yaml), the README, and rerun the checks.

```sh
flutter pub get
dart run tool/verify_maia3.dart
dart format lib test integration_test test_driver tool
flutter analyze --no-fatal-infos
dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool
flutter test --coverage
python3 -m unittest discover -s scripts -p 'test_*.py'
```

CI checks formatting without applying it and uploads `coverage/lcov.info`.
The APK job also runs `./gradlew :app:lintRelease` from `android/` after the
production build. Run this locally after Android resource or build changes.

Analysis excludes `native/`, `build/`, and `android/`; formatting covers only app
Dart code, tests, and tools. Review native changes separately. The Python tests exercise
signing configuration without requiring real signing secrets. APK and model
checks live in Dart under `tool/`.

## Android tests

Connect an ARM64 Android device/emulator, obtain its ID with
`flutter devices`, and substitute it for `DEVICE`:

```sh
flutter test integration_test/maia3_acceptance_test.dart -d DEVICE
```

The consolidated suite imports board/promotion/result regressions, persistence,
campaign/statistics, game-screen flows, native MultiPV tests, Maia-3 level changes,
hints/cancellation, and recovery after invalid models. Its parity test compares
Android inference with the official PyTorch reference fixtures, including all
levels and special moves. Individual targets remain available in
`integration_test/`. CI runs the same acceptance suite on an x86_64 Android 35
emulator and gates publication on success. Debug x86_64 builds resolve the
official ONNX Runtime Android 1.22.0 AAR; release distribution remains ARM64.
Use `scripts/test_android_emulator.sh SERIAL` for an explicit emulator-only run.
The script refuses personal devices and keeps its output in
`build/android-integration.log`. Native ARM64 parity still needs an ARM64
emulator/device when changing inference or packaging.

For the screen matrix, vary emulator orientation, display size, font scale, and
navigation mode, then run `integration_test/section_2_android_test.dart`. Widget
tests also exercise narrow screens and enlarged text. Run Android tests and
production builds sequentially: concurrent Flutter targets can race while
generating `GeneratedPluginRegistrant.java`. After integration tests, use the
normal production build command so dependency registration refreshes; a
`--no-pub` build can retain the integration-test registrant.

## Drift code generation

The schema is in `lib/data/local/app_database.dart`; the tracked
`app_database.g.dart` file is generated. After changing schema or annotations:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Include the generated changes, review whether `schemaVersion` and migration
steps need updating, and run persistence and worker tests. Do not regenerate
generated sources solely to edit prose.

## Profile measurements

Use the same SDK, mode, device, and fixtures for comparisons. These targets skip
ordinary non-profile execution and do not enforce timing thresholds:

```sh
flutter drive --profile --no-dds --driver=test_driver/performance.dart --target=integration_test/board_performance_test.dart -d DEVICE
flutter drive --profile --no-dds --driver=test_driver/hint_latency.dart --target=integration_test/hint_latency_android_test.dart -d DEVICE
flutter drive --profile --no-dds --driver=test_driver/audit_performance.dart --target=integration_test/audit_performance_android_test.dart -d DEVICE
flutter drive --profile --no-dds --driver=test_driver/audit_performance.dart --target=integration_test/stats_performance_android_test.dart -d DEVICE
```

Outputs are `build/board_performance.json`, `build/hint_latency.json`, and
`build/audit_performance.json`. The last two targets overwrite the same audit
output; copy each report before running the next target. Keep measurement
records dated, link raw evidence, and distinguish emulator results from physical
device results. See the [historical performance report](docs/performance-validation.md).

## English communication and commits

Use English for documentation, comments, UI/accessibility text, test descriptions,
logs, errors, pull request titles/descriptions, and release notes. Explain why
non-obvious code exists; remove comments tied to obsolete development phases.
Keep upstream licence notices intact. Preserve language-specific fixtures when
language or Unicode is what the test verifies, and document the exception.

Follow the Conventional Commit format used by recent project commits:

```text
docs: document Android signing and release retries
fix(game): preserve legal king escapes while in check
test: cover cancellation of pending visual hints
```

Use an imperative description and a scope when it clarifies the change. Describe
the problem, resulting behaviour, and checks actually executed in the pull
request. There is no commit hook or commit-message validator configured.

Historical commits may contain Portuguese. Do not amend published history,
force-push branches, or recreate published version tags to translate it.
Migrating that history requires a separately coordinated and authorised history
rewrite. Release automation uses English templates with source links; review any
additional feature notes when publishing a stable release. See
[release documentation](docs/android-releases.md) and the
[language audit](docs/documentation-audit.md).
