# Resource efficiency and Android maintenance

Follow-up to [audit-remediation.md](audit-remediation.md). This work preserves
stored game formats, campaign rules, move validation and the Maia-3 FP32 model.

## Data and application boundaries

- Home and paginated history observe `GameSummary`: metadata and an indexed move
  count. They no longer hydrate every move, FEN and PGN in a displayed page. The
  repository retains full snapshots for restore, export and replay.
- Replay validation and PGN export use a worker isolate from 128 plies onward.
  Short games avoid isolate startup overhead. Invalid histories are still
  rejected; the replay screen exposes loading, error and retry states. Restore
  and post-game review use the same path. Annotated export also moves to a worker
  for large PGN text, even when its mainline is short.
- `GamePersistence` owns snapshot serialization and FIFO writes. A failed write
  reaches its caller while subsequent writes can still proceed. Controller
  decisions and persistence mechanics now have separate responsibilities.
- Chronological completions append one rating point and update campaign progress
  from the current level's bounded window. Retroactive completion and deletion of
  a rated game retain full deterministic rebuilding. Qualification stays sticky.
  Deleting an unrated import does not rewrite rating or campaign history.

## Native resource lifetime

Leaving the game route pauses the clock, drains pending writes and releases Maia
and Stockfish. Returning restores the persisted game and initializes the engines
again. A generation guard prevents disposal of an old route from canceling a new
session. Backgrounding the app retains the existing pause/resume behavior.

The verified model file is cached per process, not the model's weights. Reopening
an engine avoids hashing 307 MB again if file size, modification time and change
time are unchanged. A fresh process, changed file or deleted file requires
verification again; simultaneous callers share the same pending verification.

## Android build and native CI

Gradle 9.3.1, AGP 9.1.0 and Kotlin 2.3.20 replace the legacy toolchain. AGP owns
Kotlin compilation; the compiler version is selected without applying the old
Kotlin Android plugin. Library modules compile against API 36 through AGP's
`finalizeDsl` hook; no plugin cache edits or API-level checks are bypassed. Compatible file picker, sharing, wake-lock and package
metadata plugins remove the remaining KGP applications. File import now handles
cancelation and bounded byte streams, including missing or inaccurate sizes.

Flutter 3.47 still needs `android.newDsl=false`. This follows its documented
migration path; dependency validation is enabled. AGP still reports that this
legacy DSL option will be removed in AGP 10, so that future upgrade requires a
Flutter version which supports the new DSL. Stockfish 1.8.1's obsolete
JCenter/AGP 3.5 build is replaced by a versioned Gradle adapter. The package's
original C++ source, CMake and neural networks remain unchanged.

Every CI run now executes the native acceptance suite on an Android x86_64
emulator. The debug emulator build obtains ORT 1.22.0 from Microsoft's official
Maven artifact. Its ARM64 library was compared byte-for-byte with the runtime
bundled by onnxruntime_plus 1.5.0. Distributed release APKs remain ARM64 and do
not include the extra emulator dependency. Nightly and stable publication depend
on both the verified release build and native integration passing.

`scripts/test_android_emulator.sh` requires an explicit emulator serial and
refuses physical devices. Personal campaign/history data is never a test fixture.

## Packaging tradeoff

Native ELF libraries use APK compression. This reduces the download while Android
extracts the libraries at installation. It trades download size for additional
installed storage; it does not reduce model parameters, inference precision or
resident model memory. The APK verifier still checks ARM64 contents, model hash
and native 16 KB alignment, and CI checks signature and ZIP alignment.

## Measurements and validation

Local ARM64 release APK: **379,009,578 bytes**, versus the prior
439,745,849-byte artifact: **60,736,271 bytes (13.81%) less**. Native entries
contain 153,067,248 uncompressed bytes and 92,434,839 compressed bytes. Because
Android now extracts them, the APK-plus-native-libraries installed footprint is
roughly 92 MB larger than before (before filesystem overhead and app data).
The 307,514,441-byte FP32 model is unchanged. This is a distribution tradeoff,
not a claim of lower installed storage or smaller neural weights.

The updated Dart suite passes **373 tests**, with **13 Python release-tool tests**.
The ARM64 acceptance suite passes **84 tests**. After the final worker-path
changes, five affected native session/restore/review flows were rerun and passed.
Release compilation, Android Lint, model/native APK verification, signature
verification and ZIP alignment pass. Lint retains three non-blocking warnings:
the back callback is used only on API 33+, a newer Gradle is available, and a
newer ORT is available. We retain the Flutter-compatible Gradle version and the
matching ORT 1.22 runtime intentionally.

On the ARM64 debug emulator, RSS moved from **980,217,856** bytes with Maia loaded
to **363,900,928** after release: about **588 MiB returned**. Restoring the same
saved game took **718 ms**. The subsequent 192 reference inferences passed with
maximum probability error **0.000010309** (tolerance 0.0001). The observed median
was 70 ms and p95 73 ms. These are single-run observations, not a claimed speedup
against earlier measurements. Exact data and context are in
[performance/resource-efficiency.json](performance/resource-efficiency.json).


Regression coverage includes library projections over 1,100 games, incremental
versus rebuilt rating/campaign state after every completion and deletion, failed
FIFO write recovery, resource disposal and generation races, worker replay
validation, model cache invalidation, and bounded file imports.

The native lifecycle test records RSS before inference, after inference and after
resource release, then verifies restoration of the same game ID and moves. These
are device-specific observations, not portable leak or performance thresholds.

## Upstream references

- [Flutter built-in Kotlin migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
- [Android Gradle Plugin 9 migration](https://developer.android.com/build/releases/agp-9-0-0-release-notes)
- [Android emulator runner](https://github.com/ReactiveCircus/android-emulator-runner)
- [Official ONNX Runtime Android 1.22.0](https://repo.maven.apache.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/1.22.0/)
