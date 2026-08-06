# Architecture Decision Record (ADR)

This document records deviations from the original technical specification
(`docs/especificacao.md`, sections 2 and 9) and other relevant decisions
made during the autonomous implementation of the project.

---

## ADR-001 — Reuse of pub.dev packages for lc0 and Stockfish instead of a custom NDK build

**Status:** accepted
**Context:** the original specification (section 12) identifies compiling
lc0 for Android via NDK and validating execution via FFI as the project's
biggest technical risk, recommending an isolated spike before proceeding.

**Decision:** instead of building lc0 and Stockfish from scratch (checking
out the source code, configuring the NDK toolchain, meson/CMake, inference
backends, etc.), the project reuses two open source Flutter packages already
published on pub.dev, both under the GPL-3.0 license (compatible with this
project's open source distribution):

- [`leela_chess_zero`](https://pub.dev/packages/leela_chess_zero) (v1.0.0) —
  compiles lc0 from vendored source via CMake/NDK during the Gradle build
  itself, exposes `lc0_init`, `lc0_main`, `lc0_stdin_write`,
  `lc0_stdout_read` via Dart FFI (`DynamicLibrary.open('liblc0.so')`), runs
  lc0's UCI loop in a dedicated Isolate, with stdin/stdout redirected via
  Unix pipes. Already includes the Maia-1900 weight as an asset
  (`assets/weights/maia-1900.pb.gz`) and accepts custom weights via
  `setoption name WeightsFile value <path>`. Inference backend: BLAS (via a
  custom CBLAS implementation on top of header-only Eigen), since Android
  has no system libblas.
- [`stockfish`](https://pub.dev/packages/stockfish) (v1.8.1) — same
  architectural pattern (in-process FFI, no subprocess, dedicated Isolate),
  applied to the Stockfish engine.

**Rationale:**
1. Both packages already implement exactly the contract required by
   sections 4.1/4.2 of the technical document: **in-process** execution via
   FFI, no subprocess (respecting Android's W^X restriction since API 29).
2. Avoids rediscovering, by trial and error, an entire C++ cross-compilation
   process (lc0 proto headers, Eigen, abseil, CPU backends) that two open
   source teams have already solved and maintain publicly.
3. Drastically reduces Phase 0's technical risk surface, allowing
   development time to be invested in the rest of the app.

**Consequence:** the project depends on the continued maintenance of these
third-party packages. Should they become obsolete or incompatible with
future Flutter/AGP/NDK versions, the alternative is to vendor a private
copy (fork) inside the app's own `android/`, or fall back to the original
manual-build plan. The sources of both packages are already vendored inside
each package (no git submodules), which makes such a fork easier if
necessary.

**Addendum (Phase 0, spike execution):** the `leela_chess_zero` 1.0.0
package published on pub.dev **does not build out-of-the-box**. The Android
build fails with `fatal error: 'proto/net.pb.h' file not found`. Cause: the
package's own `architecture.md` documents that the pre-generated `.pb.h`
headers for lc0's messaging system (`net.proto`, `onnx.proto`, `hlo.proto`)
should be committed under `ios/lc0/build/proto/`, but that folder was not
included in the published tarball — almost certainly because `build/` is in
the author's `.gitignore` and `dart pub publish` packages content respecting
`.gitignore` by default.

Fix applied: the package was vendored into `native/leela_chess_zero/` (a
full copy of package 1.0.0) and the missing headers were regenerated
locally from the source `.proto` files (which **are** present in the
package), using lc0's own existing script:

```bash
cd native/leela_chess_zero/ios/lc0
uv run --no-project python3 scripts/compile_proto.py --proto_path=proto --cpp_out=build proto/net.proto
uv run --no-project python3 scripts/compile_proto.py --proto_path=proto --cpp_out=build proto/onnx.proto
uv run --no-project python3 scripts/compile_proto.py --proto_path=proto --cpp_out=build proto/hlo.proto
mkdir -p build/proto && mv build/*.pb.h build/proto/
```
(`--no-project` prevents `uv` from trying to sync/build lc0's full meson
project, which has its own `pyproject.toml` and doesn't build on desktop
with the mobile-specific modifications of the vendored source — we only
need the standalone Python script, with no third-party dependencies.)

**Addendum (Phase 2, dispose race condition):** when switching levels in a
game against the AI without leaving the app (e.g., playing against Maia
1900 and then, right after, starting a new game against Maia 1100), the app
threw `Bad state: Multiple instances are not supported, yet.`. Cause: both
`Lc0.dispose()` and `Stockfish.dispose()` (the underlying packages) only
send `"quit"` over stdin — the actual cleanup (which clears the package's
static `_instance` singleton) only happens afterward, asynchronously, once
the engine's isolate finishes processing `"quit"` and exits. The original
`Lc0Service.dispose()`/`StockfishService.dispose()` did not wait for this:
they returned as soon as `"quit"` was sent, so a subsequent `init()` tried
to build a new instance while the old one had not yet released the
package's singleton. Fixed by making `dispose()` listen to `state` until it
becomes `disposed`/`error` (with a 5s safety timeout) before returning.
Validated by fixing exactly the scenario that reproduced the bug (switching
from level 1900 → 1100 within the same session).

**Addendum (Phase 3, `Lc0State.ready`/`StockfishState.ready` do not mean
"ready to play"):** while implementing the hint button, `getBestMove` for
lc0 and Stockfish started timing out in an apparently random fashion, even
with both engines already in the `ready` state. logcat exposed the cause:
between the engine printing `Search algorithm: classic` and `Loading
weights file from: ...` (lc0), **23.6 seconds** elapsed — and parsing the
weight itself, once started, took only ~21ms. In other words,
`Lc0State.ready` (and, by the `stockfish` package's identical construction,
`StockfishState.ready`) only indicates that the native Isolates came up
(`Isolate.spawn` returned), **not** that the engine finished loading the
weight/network and is ready to process `go`. A `go` sent during that window
sits in the queue behind the still-in-progress loading, and our Dart-side
timeout (unaware of this) fired thinking the engine had hung.

Fixed in `Lc0Service.init`/`StockfishService.init`: after the state becomes
`ready`, we send the standard UCI `isready` handshake and only consider the
engine actually ready (`isReady`) once `readyok` arrives — which only
responds after the engine has processed everything queued before it on
stdin, guaranteeing loading has finished. This handshake's timeout: 60s.

**Open question:** it is not confirmed whether the ~24-38s loading times are
specific to this development environment or something to expect on real
hardware too. Strong evidence points to it being environment-specific: the
host where this project is being developed runs the agent session itself
inside a VM (QEMU), and the Android emulator is *another* layer of QEMU on
top of that — nested virtualization, known to heavily penalize CPU-intensive
operations (`ps aux` showed the emulator process and a second VM competing
for CPU alongside Gradle/Kotlin daemons, `uptime` showing a load average >5
during one of these timeouts). Loading/verifying neural network weights via
BLAS is exactly the kind of workload that suffers most in this scenario.
That is why the handshake timeout was raised to 120s (from 60s), purely to
make it possible to validate Phase 3 in this sandbox — **this should not be
read as an estimate of real time on physical hardware**. Worth measuring on
an actual device before Phase 7; if it is still slow there, consider
preloading the next likely level's weight in the background, or making the
timeout configurable.

`pubspec.yaml` points to this local copy via a `path:` reference instead of
the hosted version:
```yaml
leela_chess_zero:
  path: native/leela_chess_zero
```

**Additional consequence:** the 3 generated `.pb.h` files (a few KB each)
are committed inside `native/leela_chess_zero/ios/lc0/build/proto/` in this
repository. Should the package maintainer publish a fixed version on
pub.dev, reevaluate reverting to the hosted dependency.

**Spike result (validated on a real APK, x86_64 emulator, API 36):**
`liblc0.so` and `libstockfish.so` compile and link for `arm64-v8a` and
`x86_64`; with the debug APK installed, the diagnostic screen confirmed
end-to-end: loading the Maia-1900 weight → sending the initial FEN → `go
nodes 1` → receiving `bestmove e2e4` via FFI (lc0), and the same flow with
Stockfish (`go movetime 1000` → `bestmove e2e4`). **The project's biggest
technical risk (requirements section 12) is mitigated.**

**Robustness observation (non-blocking, revisit in Phase 3):** on the first
call to Stockfish in this test session, the search did not respond within
9s (timeout) and left the `stockfish` package's singleton stuck (`Bad
state: Multiple instances are not supported, yet.` on subsequent attempts,
requiring an app restart). On later runs (fresh process), it responded
quickly. Likely cause: the cold-start cost of the two embedded NNUE files
(a large `nn-c288c895ea92.nnue` plus a small `nn-37f18f62d772.nnue`) added
to the residual load from the heavy native build that had just run on the
same host. Recommendations for Phase 3 (`stockfish_service.dart`): (a) send
`uci`/`isready` and wait for `uciok`/`readyok` before the first
`position`/`go`, currently missing in both `Lc0Service` and
`StockfishService`; (b) increase the timeout margin or make it
configurable; (c) if the timeout occurs, expose a recovery path (restart
the isolate/engine) instead of leaving the singleton stuck.

**Addendum (Phase 3, root cause of the Stockfish + lc0 hang):** the wait of
over 400 seconds with essentially zero CPU usage was not the NNUE cost nor
a host scheduling issue. Both packages' FFI bridges called `dup2()` on file
descriptors 0/1 of the **same process**, and their UCI loops blocked on
`std::getline(std::cin)`. `stdin`, `stdout`, `std::cin`, and `std::cout` are
global to the process/C++ runtime, not private per Isolate. Since lc0
remained alive for the entire game, its loop stayed blocked waiting for the
next command, and Stockfish could sleep indefinitely contending for the
same stream. This behavior directly explains the observed absence of CPU
usage.

Fix: the vendored lc0 bridge no longer calls `dup2()` or uses
`std::cin/std::cout` for the UCI protocol. `engine_loop.cc` reads directly
from lc0's private pipe, and `StdoutUciResponder` writes directly to the
output pipe, with serialization and `EINTR` handling. This frees Stockfish
to use the package's legacy transport without contention between engines.

Additional Dart-side defenses:

- Stockfish handshake capped at 60s (lc0: 120s);
- stream end/error completes the `Future`s with an error, instead of
  waiting only for the timer;
- a delayed search receives `stop`, gets a 2s grace period and, if still
  stuck, the engine is discarded;
- the full hint operation has a 120s limit and always exits the spinner
  with a result or an error;
- requesting a hint marks the game as unevaluated immediately, before the
  engines run, and the computation is kicked off from the button's callback
  (outside Riverpod's build cycle).

Live validation (x86_64 emulator, API 36): Maia 1100 and Stockfish returned
`e4` for the starting position in under 10s; then, after Stockfish was
already active, the human move `1.e4` normally received `...e5` from the
same lc0. A second hint on the new position returned `Nf3` from both
engines. This confirms both the hint feature and the coexistence and reuse
of the two engines.

---

## ADR-002 — Android ABI set: `arm64-v8a` + `x86_64` (instead of `arm64-v8a` + `armeabi-v7a`)

**Status:** accepted
**Context:** the specification suggests ABI splits for `arm64-v8a` and
`armeabi-v7a` (section 10, section 7).

**Decision:** the app's `build.gradle.kts` uses `abiFilters "arm64-v8a", "x86_64"`.

**Rationale:** the `leela_chess_zero` package (lc0 engine) currently only
compiles, upstream, for `arm64-v8a` and `x86_64` (see the package's
`android/build.gradle`). `armeabi-v7a` (32-bit ARM) is increasingly limited
to devices from before ~2016, today a residual fraction of the Android
install base. Since the app depends on lc0 for its core functionality
(human-style AI), it makes no sense to keep an ABI the main engine doesn't
compile for. `x86_64` was kept because it enables emulator testing (used in
this very spike) and covers the few existing physical x86 devices. The
`stockfish` package compiles for all three ABIs (`arm64-v8a`,
`armeabi-v7a`, `x86_64`); the effective limitation comes from lc0.

**Consequence:** 32-bit ARM devices (rare, old) cannot run the app.
Reevaluate if `leela_chess_zero` gains upstream `armeabi-v7a` support.

---

## ADR-003 — `minSdk` 24 (instead of 23)

**Status:** accepted
**Context:** the specification (section 2, section 10) suggests API 23+
"to be confirmed against NDK/lc0 build requirements".

**Decision:** `minSdk = 24` in `android/app/build.gradle.kts`.

**Rationale:** the `leela_chess_zero` package declares `minSdk 24` as an
explicit requirement. The confirmation requested by the specification was
carried out: **API 23 is not sufficient**, API 24 (Android 7.0) is the real
minimum.

---

## ADR-004 — Chess rules library: `dartchess` (instead of `chess`)

**Status:** accepted
**Context:** the specification (section 4.3, section 13) cites the `chess`
pub.dev package as an example, but leaves the final choice open.

**Decision:** use [`dartchess`](https://pub.dev/packages/dartchess)
(maintained by the Lichess organization), not the `chess` package.

**Rationale:** `dartchess` is actively maintained by an organization with a
solid track record in open source chess engines (lichess.org), has an
immutable API (`Position` is immutable, `play()` returns a new position —
favoring use with declarative state management like Riverpod), supports
legal move generation, FEN, SAN/PGN, native
checkmate/stalemate/insufficient-material detection, and UCI parsing via
`Move.parse()` (needed to interpret lc0/Stockfish's `bestmove` output).

---

## ADR-005 — State management: Riverpod (as recommended)

**Status:** accepted, no deviation.
The original recommendation from section 2/9 is kept: Riverpod
(`flutter_riverpod`).

---

## ADR-006 — Build JDK: OpenJDK 17 via `flutter config --jdk-dir`

**Status:** accepted
**Context:** the development environment had OpenJDK 26 as the system's
default JDK, incompatible with the Gradle version used by the Flutter
template (compatible range: JDK 17 ≤ x < 25).

**Decision:** configured `flutter config
--jdk-dir=/usr/lib/jvm/java-17-openjdk` (JDK 17 available on the system via
`archlinux-java`), instead of changing the Gradle Wrapper version.

**Rationale:** minimizes changes to the default configuration generated by
`flutter create`, avoiding pulling in a Gradle version untested by the
Flutter team for this template.

---

## ADR-007 — Maia Weights License and Origin

**Status:** accepted
**Context:** the specification (section 9) leaves confirming the
availability and license of the official weights before embedding them in
the APK as an open item.

**Decision:** the 9 weights (`maia-1100.pb.gz` through `maia-1900.pb.gz`)
were downloaded directly from the official release of the
[`CSSLab/maia-chess`](https://github.com/CSSLab/maia-chess) repository, tag
`v1.0`
(`github.com/CSSLab/maia-chess/releases/download/v1.0/maia-<rating>.pb.gz`),
and live in `assets/maia_weights/`.

**On the license:** the `CSSLab/maia-chess` repository is licensed under
GPL-3.0. The README does not explicitly separate the code license from the
trained weights' license, but treats both as part of the same project
distributed under that license (the README itself points to both the local
`maia_weights/` folder and the GitHub releases as equivalent ways to obtain
the weights). This project (`maia_chess`, also open source) redistributes
the weights unmodified, with the origin attribution recorded here and in
`assets/maia_weights/NOTICE.md`. Should CSSLab publish a specific, more
restrictive license for the weights in the future, this decision should be
revisited.

**Rationale:** the weights are the product's central element (the
"human-style" AI does not exist without them) and are officially published
for external use, with over 13,000 recorded downloads for the 1100 file
alone at the time of checking — usage broadly expected by the maintainers.

---

## ADR-008 — Serialization, snapshotting, and recovery of engine operations

**Status:** accepted

**Context:** a hint involves two sequential native operations on the same
position. Closing the dialog does not automatically cancel the `Future`,
and a `Future.timeout` also does not by itself interrupt the native
computation. In addition, starting another game while Maia was responding
could leave two UCI searches contending on the same lc0 singleton.

**Decision:**

- `GameController.getHint()` is *single-flight*: repeated calls while a
  hint is in progress receive the same operation, with no new UCI commands;
- FEN and the `Chess` object are captured together at the start; the UCI →
  SAN conversion uses exclusively that snapshot;
- while the hint is computing, tap, drag, undo, and reset via the UI are
  blocked. Closing the dialog only hides the progress; the single operation
  continues and the state shows "Computing hint...";
- timeout, native error, invalid UCI output, game change, or shutdown
  invalidate the operation's generation and discard the involved engines
  before the next attempt;
- delayed AI responses carry a generation and the source FEN. A response is
  only applied if both still match the current game;
- starting/restarting a game during a search discards the previous lc0
  instance before creating another, avoiding concurrent commands;
- the engines are injected into the controller via Riverpod
  interfaces/factories, which allows testing timeout, error, disposal, and
  recovery without loading FFI in unit tests.

**Validation:** the test suite covers single-flight behavior, move
blocking, timeout with a later retry, initialization error, invalid UCI,
repeated switching 1100 → 1900 → 1100, and a delayed response after a game
change. An integration test on an Android x86_64/API 36 emulator runs real
engines through the sequence 1100 → hint → human move/Maia response → 1900
→ hint and explicitly shuts down both singletons.

---

## Addendum to ADR-004 — History-dependent rules and castling in the UI

`dartchess` ends games on checkmate, stalemate, and insufficient material,
but does not adjudicate repetition or the 50-move rule because those rules
depend on the game's history. `GameState` now:

- identifies repetition from the first four parts of the FEN (pieces, side
  to move, castling rights, and legal en passant), declaring a draw on the
  third occurrence;
- declares a draw when the half-move clock reaches 100;
- keeps histories in unmodifiable lists;
- translates `dartchess`'s internal castling encoding (king → rook,
  required for Chess960) into the classic g/c destination squares used by
  the UI.

These cases, together with en passant and the four legal promotions, have
dedicated regression tests.

---

## ADR-009 — Relational persistence, autosave, and PGN import

**Status:** accepted

**Context:** Phase 4 requires that a game survive process termination, that
completion/campaign updates be idempotent and transactional, and that PGN
import never leave partial records. Aggregated statistics in JSON would
duplicate data that can be computed from the games themselves.

**Decision:**

- Drift/SQLite is the durable source of truth, with relational tables
  `games`, `game_moves`, `difficulty_progress`, `rating_history`, and
  `app_settings`;
- there is at most one autosave in progress. The UI asks for confirmation
  before replacing it, and the repository performs the swap in a single
  transaction;
- the controller only writes after a move validated by `dartchess`. Undo
  replaces the snapshot and removes the undone moves;
- completion replaces the snapshot, saves the result/PGN, and rebuilds the
  rating/campaign projections in the same transaction. A second completion
  of the same ID does not count the game again;
- on resume, all UCIs are reapplied from the initial FEN. SAN, intermediate
  FENs, and the final FEN must match the database before the state is
  accepted;
- a resumed position only requests Maia's move when it is actually the
  AI's turn; the first automatic move that was already persisted is never
  replayed;
- import validates, in memory, the header, the starting position, all
  moves in the main line and variations. The count of the original tokens
  must also match the parser's tree, avoiding accepting text that a lenient
  parser silently ignored;
- imports are filed as unevaluated and do not affect campaign or rating.
  The write only happens after full validation;
- files are picked via the Storage Access Framework and exported through
  Android's share sheet, with no broad storage permissions.

**Validation:** tests with a temporary SQLite database cover schema
creation, versioning, defaults, foreign keys/cascade, snapshot replacement,
a single active game, idempotent completion, deletion of unevaluated wins,
settings, and PGN round-trip. On the Android x86_64/API 36 emulator, the
e4/e5 → undo → `evaluated=false` → forced process termination → new process
→ resume at e4 flow was confirmed live, with no state lost. The
library/replay, opening the native share sheet, and importing a four-move
PGN via DocumentsUI were also confirmed.

---

## ADR-010 — Estimated rating, streaks, and campaign progression

**Status:** accepted

**Context:** Phase 5 needs to produce deterministic statistics from
history, exclude games where a hint/undo was used, and allow all derived
data to be rebuilt after a game is deleted. It was also necessary to
precisely define what "estimated rating", "streak", and "X wins in Y
games" mean.

**Decision — eligible games:** statistics and rating only consider
finished games against Maia with a known level, player side, and result,
and `evaluated=true`. Local, imported, unfinished, or unevaluated games are
excluded from the calculations and also do not break streaks. The campaign
adds the requirement `campaignMode=true`.

**Decision — rating:**

- starting rating: **1500**;
- opponent rating: the selected Maia level (1100–1900);
- player result: win = 1, draw = 0.5, loss = 0;
- Elo expectation: `E = 1 / (1 + 10 ^ ((R_maia - R_player) / 400))`;
- update: `R_new = R_current + 32 * (result - E)`;
- defensive bounds: 600–2400;
- ordering: game end timestamp in UTC and, on ties, game ID.

Each eligible game generates exactly one point in `rating_history`. The
entire timeline is rebuilt within the same transaction that completes or
deletes a game, avoiding irreversible accumulators and keeping the
operation idempotent.

**Decision — streaks:** a "streak" means a sequence of **consecutive wins**
among eligible games, in chronological order. A draw or a loss resets the
current streak. `recordStreak` is the highest value ever reached.

**Decision — campaign:** each level declares `winsRequired=2` and
`windowSize=3`. The next level is permanently unlocked when, within any
sliding window of up to three eligible campaign games at the current level,
the player reaches two wins. Once reached within existing history, later
games do not revoke the unlock. Since progress is materialized from the
retained games, deleting the game that supported the achievement can
recompute and re-lock dependent levels. The UI warns about this effect
before deletion.

**Consequence:** `difficulty_progress` and `rating_history` are
rebuildable projections; `games` remains the source of truth. Migration v2
adds the campaign window's game count and rebuilds these projections for
existing databases.

---

## ADR-011: minification and resource shrinking turned off in the release build

**Status:** accepted

**Context:** the technical audit recorded in `AUDITORIA_TECNICA.md`
(AUD-007) found that `android/app/build.gradle.kts` does not set
`minifyEnabled`/`shrinkResources` in the `release` block, so they default
to `false` in the Android Gradle Plugin: the release APK comes out larger
and without Dart/Kotlin code obfuscation.

**Decision:** keep it off for now, as an explicit decision rather than an
omission.

**Rationale:** the project is open source, distributed by sideload (see
README), with no trade secret that obfuscation would protect. Enabling
minification would require ProGuard/R8 rules tested against a real release
build covering Drift (reflection via `sqlite3`) and the FFI plugins
(`leela_chess_zero`, `stockfish`), and the build environment used in
development has already proven heavy for native builds (see ADR-001,
robustness observation about nested virtualization). There is no immediate
gain that justifies this risk now.

**Consequence:** the APK stays larger and unobfuscated while this decision
holds. Revisit before publishing to a channel that charges by download
size, or if the Dart/Kotlin code volume grows enough to matter noticeably.

---

## ADR-012: chess clock fields are scaffolding for a future phase

**Status:** accepted, open item recorded

**Context:** `GameState`, `StoredGame`, the `games` table (Drift), and the
entire persistence path already carry `clockEnabled`/`initialTimeMs`/
`whiteTimeMs`/`blackTimeMs` (see `AUDITORIA_TECNICA.md`, AUD-011), but no
`Timer`/countdown decrements them and no screen displays a clock.

**Decision:** keep the fields as they are, without removing them for now.
This ADR documents that they are part of the design for a clock feature not
yet implemented, likely alongside the personalization work the README
lists as pending for Phases 6-7.

**Rationale:** the fields already persist and migrate correctly
(`schemaVersion` 2 in `AppDatabase`); removing them now would require a new
database migration with no real benefit, and the data structure already
reflects the intended design for when the feature is prioritized.

**Consequence:** until the feature is implemented (or the fields removed,
if it is dropped), someone reading the schema may assume the clock already
works. This ADR exists precisely to make that explicit.

---

## ADR-013: conditional release signing via `key.properties`

**Status:** accepted, keystore generation still pending

**Context:** `android/app/build.gradle.kts` unconditionally signed the
release build with the debug key (see `AUDITORIA_TECNICA.md`, AUD-006), a
practice documented as temporary by the file's own original `TODO`.

**Decision:** the `release` block now uses a dedicated `signingConfig` read
from `android/app/key.properties` when that file exists; without it, it
falls back to the debug key, preserving `flutter run --release` with no
extra setup in a development environment, but now with an explicit warning
printed during Gradle configuration. `key.properties` and the matching
`.jks` are never committed (`.gitignore`).

**On generating the keystore itself:** this agent did not generate the
keystore or its passwords. Creating and safeguarding the private key that
will permanently sign the app's updates is a decision for the project
owner (where to store the backup, how to rotate credentials, whether the
release will eventually be published by more than one person), not
something that should be automated silently. The command is documented as
a comment at the top of `build.gradle.kts`:

```bash
keytool -genkeypair -v -keystore android/app/release-keystore.jks \
  -alias maia_chess_release -keyalg RSA -keysize 2048 -validity 10000
```

followed by an `android/app/key.properties` with `storeFile`,
`storePassword`, `keyAlias`, and `keyPassword`.

**Consequence:** release builds keep signing with the debug key until
someone with access to the environment runs the command above. Validation
that the conditional `key.properties` reading works (and that Gradle
configures correctly with or without the file present) was done with
`./gradlew help`, without the file present: the warning appeared as
expected and configuration finished successfully.
