# Documentation and English migration audit — 2026-10-12

## Scope and source of truth

The audit started from 2,223 tracked files, with no tracked working-tree changes.
The pre-existing untracked `.vscode/` directory was left untouched. Review covered
app bootstrap and screens, rules and controllers, native service contracts,
Drift schema/migrations and repositories, PGN handling, Android configuration,
Python release tools, tests/profile harnesses, CI, every maintained Markdown
file, asset notices, and package metadata.

The checked-in implementation determined supported features and commands.
Comments referencing deleted architecture decisions or audit reports were
replaced with current explanations. The README now covers actual modes,
assistance, eligibility, storage, prerequisites, commands, supported Android
ABIs, and troubleshooting. Contributor, architecture, and release guides give
those topics one maintained home. Historical performance reports retain their
measurement dates, figures, and limitations.

English migration includes UI and accessibility labels, engine logs/errors,
PGN/share descriptions, test names/assertions and fixtures, Dart documentation,
Gradle/manifest/ProGuard comments, workflow steps and release bodies, Python
messages, and package descriptions. Existing technical identifiers, stored
values, schema, assets, and native protocols were preserved. Piece-label word
order was adjusted to natural English without renaming its legacy helper API.

No root changelog, contribution guide, commit template, issue template, or pull
request template existed at audit start. The new contribution guide documents
the recent Conventional Commit format in English. The native plugin changelog
now distinguishes local fork changes from inherited release notes. Future
nightly and stable release bodies use English templates with source/CI links;
historical titles are not copied into automatic summaries.

## Preserved exceptions and excluded material

- **Historical observation:** `performance/release-smoke.json` preserves the
  original Portuguese UIAutomator label observed in the 2026-10-11 release
  smoke test. It is evidence from the former UI, not a current application
  string or localisation resource. Its English meaning is “Piece suggested by
  Stockfish, b8, Black knight.” Measurement JSON, hashes, sizes, and timings were
  not rewritten during translation.
- **Unicode fixture:** `scripts/test_release_tools.py` retains `ç` in a synthetic
  password to verify Java properties Unicode escaping to `\u00e7`. This is a
  deliberate encoding test, not Portuguese prose.
- **Compatibility names:** `GameResult.emAndamento`, `vitoriaBrancas`,
  `vitoriaPretas`, and `empate`, plus `roleLabelPt`/`pieceLabelPt`, retain their
  existing Dart identifiers. The helpers now return English. The shared PGN
  filename prefix `partida_` remains unchanged because file paths were outside
  the rename scope. These names are not language resources.
- **External snapshots:** 1,955 tracked files under
  `native/leela_chess_zero/ios/lc0/` and `ios/eigen_header/` are vendored upstream
  material, including historical documentation and licences. They were scanned
  for Portuguese candidates but excluded from prose modernisation. Local plugin
  guides, wrapper documentation, bridge/build configuration, and example guides
  were reviewed separately.
- **Generated/binary material:** Drift's `app_database.g.dart`, dependency
  lockfiles, the session lock `.claude/scheduled_tasks.lock`, SVG artwork,
  raster images, and compressed networks were kept intact. Human-readable
  metadata was scanned where decodable; generated/native headers and licence
  texts were not regenerated or translated. No required `pt-BR` localisation
  bundle was found in the maintained app.

## Historical Git and external releases

Before committing this migration, all 62 locally available commit subjects
were reviewed; 29 are Portuguese.
Historical message bodies also contain Portuguese.
Examples by hash are `1081c1f` (initial implementation), `04390de` (earlier
README translation), and `23ea842` (last-move highlight). Existing commit messages and hashes were not rewritten, and published tags
were not changed. No existing commits were amended.

Translating those messages would rewrite each affected commit and descendant,
requiring backups, an agreed scope, explicit authorisation, coordinated branch
and tag handling, remote updates, and contributor re-cloning or rebasing. It
cannot be accomplished as an ordinary documentation edit. Published GitHub
release notes were not modified. The existing moving-nightly automation remains
in place; this migration did not execute publication or move its tag.

## Licensing follow-up

No root application licence was tracked at the time of this audit. The maintainer
subsequently selected `AGPL-3.0-or-later` for original project material. The root
[LICENSE](../LICENSE), [README](../README.md#licence-and-credits), and
[third-party notices](../THIRD_PARTY_NOTICES.md) record that decision and preserve
the separate terms of upstream components.

## Findings requiring separate work

- Clock fields and preferences are stored but no timed-game UI/countdown exists.
  The README now says so rather than implying timed play is supported.
- The inherited plugin example's reset path calls `dispose()` on an already
  disposed wrapper, and the wrapper rejects commands in that state. Its fixed
  startup/exit delays also do not validate the weights readiness handshake.
  These example defects were recorded without changing runtime behaviour.
- Native service shutdown is bounded and best effort; no force-kill API exists.
  Timeout does not guarantee singleton release. Comments now describe that
  limit instead of promising synchronous termination.
- Physical ARM64 performance and iOS plugin behaviour are not established by
  current CI. The older 337-frame interaction measurement has no tracked raw
  JSON; the later 253-frame record is a different sample.

## Migration validation

Executed with Flutter 3.47.4 / Dart 3.13.3:

- `flutter pub get`: succeeded; `pubspec.lock` unchanged.
- App Dart formatting and `flutter analyze --no-fatal-infos`: passed, no issues.
- `flutter test --no-pub --coverage --reporter expanded`: **239 tests passed**
  after correcting a translated PGN fixture/assertion mismatch found by the
  first run.
- Python release-tool suite: **10 tests passed**.
- Workflow YAML and all embedded shell steps parsed successfully.

- Android API 36 x86_64 emulator: **75 consolidated acceptance tests passed**,
  including real SQLite/Stockfish/Maia flows and the board regression matrix.
- Native engine suite: **2 tests passed**, covering level changes, hints,
  cancellation, and lc0 recovery after invalid weights.
- The three home-screen widget tests passed again after strengthening the
  translated autosave-removal assertion.
- Final formatting: **96 files checked, no changes required**. Final analysis:
  **no issues**.
- `actionlint` 1.7.7: passed. Maintained YAML, tracked JSON, and workflow shell
  syntax parsed successfully.
- **43 maintained Markdown relative links/anchors checked**, none broken.
- Final language review combined accented/unaccented phrase searches, quoted
  labels, comment blocks, configuration text, and contextual review. The only
  remaining Portuguese prose is the deliberately preserved historical label
  described above.
- A Dart parser/token comparison of **82 changed Dart files** found no changes
  outside comments, string literals, and formatter-managed trailing commas.
  Dependency/asset configuration, analyzer rules, generated schema, lockfile,
  historical measurements, and upstream licence texts are unchanged.

- The documented ARM64 release build succeeded, producing
  `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (150.7 MB as reported
  by Flutter). The ARM64 content/ZIP verifier, `apksigner verify --verbose`,
  and `zipalign -c -P 16 4` all passed.
- The initial release command using `--no-pub` failed because the generated
  registrant still referenced `integration_test` after native testing. Repeating
  the documented build command with dependency refresh succeeded; the guides
  now explain that recovery. No Android source change was needed.
- The release build reported future support warnings for existing Gradle
  8.14.0, AGP 8.11.1, and Kotlin 2.2.20. These tool versions were not upgraded.
  Local release signing used the existing debug-key fallback; distribution-key
  signing and external publication were not exercised.
- Final diff review and `git diff --check`: no whitespace errors; changes are
  limited to English communication, documentation, matching assertions,
  formatter output, and release-note source metadata.

No historical benchmark was remeasured during this documentation migration.
