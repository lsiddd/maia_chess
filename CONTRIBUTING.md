# Contributing

Start with the [README](README.md) for the pinned Android toolchain and setup,
and [architecture](docs/architecture.md) for the current implementation. Run all
commands below from the repository root unless a different directory is shown.

## Change scope

Keep changes focused and document the behaviour that the source actually
implements. Update relevant tests and user-facing English text together. Keep
identifiers, stored enum names, asset paths, UCI commands, PGN tags, and migration
contracts stable unless the change explicitly requires a migration.

The `native/leela_chess_zero` package is a local fork. Avoid unrelated changes to
its lc0 and Eigen snapshots. Native fixes need Android integration validation;
unit tests with fake engines cannot establish native lifecycle correctness.

## Checks

Use Flutter 3.47.4 / Dart 3.13.3, matching CI. When changing the SDK pin, update
[the workflow](.github/workflows/ci.yaml), the README, and rerun the checks.

```sh
flutter pub get
dart format lib test integration_test test_driver
flutter analyze --no-fatal-infos
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter test --coverage
python3 -m unittest discover -s scripts -p 'test_*.py'
```

CI checks formatting without applying it and uploads `coverage/lcov.info`.
Analysis excludes `native/`, `build/`, and `android/`; formatting covers only app
Dart code and tests. Review native changes separately. The Python tests exercise
signing configuration and APK contents without requiring real signing secrets.

## Android tests

Connect an ARM64 or x86_64 Android device/emulator, obtain its ID with
`flutter devices`, and substitute it for `DEVICE`:

```sh
flutter test integration_test/android_acceptance_test.dart -d DEVICE
flutter test integration_test/phase_0_3_android_test.dart -d DEVICE
```

The consolidated suite imports board/promotion/result regressions, persistence,
campaign/statistics, game-screen flows, and native MultiPV tests. The second
suite covers Maia level changes, hints/cancellation, and recovery after invalid
weights. Individual targets remain available in `integration_test/`. CI does
not launch an emulator or run these tests.

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
Dart or native protobuf headers solely to edit prose.

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
