# Application architecture

## Components

`lib/main.dart` registers bundled asset licences and creates the Riverpod
`ProviderScope`. `MaiaChessApp` watches stored appearance settings, and the home
screen opens campaign, free play, local play, statistics, or the game library.
Controllers use repository and engine contracts rather than constructing those
dependencies inside presentation widgets.

| Area | Implementation and responsibility |
| --- | --- |
| Rules and live state | `dartchess`, `GameState`, and `GameController`: legality, SAN/UCI, turn management, undo, and termination |
| Maia opponent | `MaiaService`, with one bundled Maia-3 79M FP32 model and Dart ONNX Runtime FFI |
| Assistance | `StockfishService`: single-move hints and up to three MultiPV opponent plans; geometric attack detection is separate |
| Persistence | `GamePersistence` serializes snapshots and orders writes; `AppDatabase` and Drift repositories: autosave, archived games, settings, campaign progress, and rating history |
| Replay and exchange | `GameReplayer` validates stored moves/FENs; `PgnService` validates and exports PGN; `PgnFileService` handles Android files/sharing |
| Presentation | Feature screens, board widgets, shared themes, and accessibility announcements |

Providers are beside their owners: repositories in `lib/data/providers.dart`,
controllers and engine factories in their application/service files. There is
no separate dependency-injection directory.

## Live state and asynchronous work

`GameState` copies public history inputs into immutable lists. `copyWith` reuses
unchanged histories and cached game-over/repetition facts when their inputs are
identical. `dartchess` supplies legal moves, mate, stalemate, and insufficient
material. The app automatically adjudicates threefold repetition and the
fifty-move rule, with checkmate taking precedence over draw counters.

`GameController` uses generations and captured positions to discard stale
restores, engine replies, hints, and plans. Writes are queued in order by `GamePersistence`. A pending
promotion cannot apply its result after a restart or another position change.
The home screen blocks duplicate opening requests before the first await.

AI starts prepare a separate candidate, including Maia's opening move, before
replacing the autosave. Leaving the setup screen cancels preparation. The
replacement transaction checks cancellation after its writes and rolls back
if needed. Once the final commit check accepts the candidate, back navigation
waits for the commit to finish. Startup and cleanup are serialised so cancelled
requests cannot create a late engine over a newer game.

Maia replies in the live turn flow use a random 500–1,100 ms minimum wait
that runs alongside the model inference. A search that takes longer
can play as soon as its result arrives. Invalidating the current game cancels
any pending wait, and the controller checks the position before playing.

Hints use Stockfish only and retain the suggested origin in
`VisualHintController`. Board interaction cancels a hint. `LiveThreatController`
refreshes plans on position/availability changes, not selection or drag. Plans
analyse a copy with the side to move reversed and en passant cleared; this copy
never enters game history. Requests are serialised through the one Stockfish
instance, and results for stale positions are discarded.

## Game review

Review analyzes a replay with the same local Stockfish instance as live-game
assistance. It passes the reversible move history with each position so the
engine can detect repetition. Known terminal positions use their exact result.
Review and trial moves use separate positions and leave the stored game and its
rating unchanged.

Each review route acquires a lease on the shared Stockfish session. Leaving the
last review cancels its request and releases Stockfish without disposing Maia or
changing the live game. Starting another game invalidates old leases so a late
route disposal cannot close the newer game's engine.

The full scan covers up to 400 half-moves, searching each position for 160 ms.
If Stockfish returns no usable line, the scan retries that position once with
a 400 ms single-line search. A three-minute limit bounds the scan between
searches. Cancellation discards any in-flight result and stops queuing searches.
Individual positions and trial moves can still be analyzed in longer games.

Scores are normalized to White's perspective. Move labels depend on the loss in
estimated winning chances. Review blends a volatility-weighted average of move
accuracy with a harmonic mean and reports average centipawn loss separately.
The [Lichess accuracy guide](https://lichess.org/page/accuracy) describes the
underlying metric. The search budget and classification thresholds are local to
this app.

## Native engines

Maia-3 uses one ONNX session on a dedicated Dart isolate. Dart constructs eight
historical square-token frames, pads short histories with the earliest frame,
and passes the chosen rating as both self and opponent Elo. The policy is
masked to legal moves and sampled at temperature 1, top-p 1. The same loaded
session serves every rating. Restoring or undoing uses the current game history,
so there is no hidden engine history to reset. See [model provenance](../assets/maia3/NOTICE.md).

Android exposes APK paths through a small metadata channel. Dart streams the
bundled model from the APK into application support storage, validates size and
SHA-256, and renames it atomically. Building and verifying the bundled model
require no Python. The final artifact is versioned with Git LFS; its initial
conversion happened outside the repository. A process-local verification cache
reuses the extracted file only while its size and timestamps remain unchanged.
Leaving the game route drains writes and releases native engines; restoring the
autosave initializes them again without changing the game identity or moves.

Initialization, tensor allocation, inference and native disposal run on a Dart
worker. Cancellation signals ONNX Runtime's thread-safe RunOptions termination;
the worker exposes its command port before loading the model so close can be
queued during startup. Shutdown waits at most five seconds, then fails pending
requests and detaches the session. A queued close still releases the worker's
native handles if its native call returns; Dart cannot force that call to return.
Native workers are not killed in a way that would skip their cleanup.
The controller also rejects
stale generations and positions. Failed initialization or inference can be retried.

Stockfish retains its UCI handshake and isolated native implementation. It loads
on demand for assistance and review; background warmup defaults to disabled to
reduce memory use with the 79M model. A Stockfish failure does not dispose Maia-3.

## Storage and eligibility

SQLite lives in `maia_chess.sqlite` in the application documents directory and
runs through `NativeDatabase.createInBackground`. Schema version 6 contains
`games`, `game_moves`, `difficulty_progress`, `rating_history`, and `app_settings`.
Foreign keys are enabled; deleting a game cascades to its moves and rating rows.
Opening the database also ensures a library index on modification time and ID.

Only one ongoing autosave is retained. Starting a new game removes the old
ongoing game transactionally. Saving compares move histories and writes only
the changed suffix, including undo. Completion is idempotent. Normal chronological
completions append a rating point and update the current
campaign window in the same transaction. Retroactive completions and deletion of
a rated game rebuild derived state with `computeWithDatabase`, sharing the
executor and notifications with a worker. Unrated deletion needs no rebuild.
Game reads hydrate metadata and moves within one read transaction. Reactive
reads subscribe to updates before the initial snapshot and observe both tables.
The library shows pages of 50 games, reading one extra row to determine whether
another page exists. The UI summary projection uses one SELECT and an indexed
move count without
loading move/FEN/PGN payloads; full snapshots are fetched on demand. The repository's
unbounded `watchLibrary()` remains available for existing callers. Library and
statistics providers dispose their subscriptions when unused.

Statistics include completed AI games with a human side, a known result, and
`evaluated == true`. Outside the campaign, assistance and undo clear that flag.
Campaign games disable these tools and ignore the saved attack overlay setting.
Previously saved campaign games keep their recorded eligibility. Campaign
progression uses only eligible campaign games. Imported games are completed and
unrated. Only their mainline is persisted for replay, while the stored PGN preserves
parsed headers, comments, and variations. Validation checks mainline and
variation legality before writing anything. Android file content is streamed
asynchronously with a byte cap; UTF-8 decoding
and PGN validation run on workers. Replay and export move to a worker at 128
plies, including restore and post-game review. Annotated export also uses a
worker for PGNs of 65,536 characters or larger, even with a short mainline.
Imports are limited to 4 MiB, 20,000 plies across
mainline and variations, and 64 nested variation levels. File reads have a byte
cap even if the file grows after its size check.

Android backup and device transfer exclude the extracted `maia3` and legacy `maia_weights`
directory in application support storage. SQLite games, progress, rating history,
and settings retain their default backup eligibility.

Time controls are shared by free play, campaign, and local setup. `TimeControl`
validates 0–180 minutes and 0–180 seconds of Fischer increment, with unlimited
play as the default. For 0+increment, each side starts with one increment.
`GameController` uses a monotonic stopwatch; periodic ticks only update
`gameClockProvider`, so the board is not rebuilt on every tick. Balances are
checkpointed on moves, undo, save, backgrounding, and leaving the board. Engine
startup and time away from the game are excluded. Engine failures pause the
clock until retry. An in-flight reply can finish while paused.

Flag fall is checked both on ticks and immediately before a move, invalidates
pending engine/promotion results, and persists completion through the normal
statistics/campaign transaction. Insufficient material for the opponent gives
a draw. Undo keeps current balances; restart restores the chosen initial time.
Schema 6 adds `games.increment_ms` with a zero default for older autosaves;
PGN export records `TimeControl` and time-forfeit termination.
Settings currently expose app theme, board theme, attack visibility, and its
own-pieces filter. The only selectable piece set is Cburnett.
