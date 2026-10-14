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
| Maia opponent | `Lc0Service` and the local `leela_chess_zero` FFI plugin, using bundled networks and a one-node search |
| Assistance | `StockfishService`: single-move hints and up to three MultiPV opponent plans; geometric attack detection is separate |
| Persistence | `AppDatabase` and Drift repositories: autosave, archived games, settings, campaign progress, and rating history |
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
restores, engine replies, hints, and plans. Writes are queued in order. A pending
promotion cannot apply its result after a restart or another position change.
The home screen blocks duplicate opening requests before the first await.

AI starts prepare a separate candidate, including Maia's opening move, before
replacing the autosave. Leaving the setup screen cancels preparation. The
replacement transaction checks cancellation after its writes and rolls back
if needed. Once the final commit check accepts the candidate, back navigation
waits for the commit to finish. Startup and cleanup are serialised so cancelled
requests cannot create a late engine over a newer game.

Hints use Stockfish only and retain the suggested origin in
`VisualHintController`. Board interaction cancels a hint. `LiveThreatController`
refreshes plans on position/availability changes, not selection or drag. Plans
analyse a copy with the side to move reversed and en passant cleared; this copy
never enters game history. Requests are serialised through the one Stockfish
instance, and results for stale positions are discarded.

## Native engines

Both engines run in-process on isolates through Dart FFI. Native wrapper ready
states indicate bootstrap completion; service readiness additionally requires
`isready`/`readyok`. Maia weights are extracted to application support storage
before lc0 loads them. The file is rewritten only if absent or a different size.

Each native package permits one active engine instance. Disposal sends `quit`
and waits within bounded timeouts; there is no force-kill API. A failed hint or
plan disposes Stockfish when necessary without disposing Maia. Android can warm
up Stockfish in the background; failure is retried on a later request. See the
[plugin architecture](../native/leela_chess_zero/architecture.md) for private UCI
pipes, native build configuration, and generated headers.

The lc0 wrapper retains its singleton until both the engine and stdout reader
report isolate exit. Shutdown during bootstrap is deferred until commands can
be sent, and partial startup failures close unused pipe ends. Native pipe
initialisation also rejects descriptors left by an earlier instance.

## Storage and eligibility

SQLite lives in `maia_chess.sqlite` in the application documents directory and
runs through `NativeDatabase.createInBackground`. Schema version 4 contains
`games`, `game_moves`, `difficulty_progress`, `rating_history`, and `app_settings`.
Foreign keys are enabled; deleting a game cascades to its moves and rating rows.
Opening the database also ensures a library index on modification time and ID.

Only one ongoing autosave is retained. Starting a new game removes the old
ongoing game transactionally. Saving compares move histories and writes only
the changed suffix, including undo. Completion is idempotent. Completion and
deletion rebuild rating/campaign state in the same transaction, using
`computeWithDatabase` to share the executor and notifications with a worker.
Game reads hydrate metadata and moves within one read transaction. Reactive
reads subscribe to updates before the initial snapshot and observe both tables.
The library shows pages of 50 games, reading one extra row to determine whether
another page exists. Metadata and page moves use two SELECTs. The repository's
unbounded `watchLibrary()` remains available for existing callers. Library and
statistics providers dispose their subscriptions when unused.

Statistics include completed AI games with a human side, a known result, and
`evaluated == true`. Assistance and undo clear that flag. Campaign progression
uses only eligible campaign games. Imported games are completed and unrated;
only their mainline is persisted for replay, while the stored PGN preserves
parsed headers, comments, and variations. Validation checks mainline and
variation legality before writing anything. Android file reading/decoding and
PGN validation run on workers. Imports are limited to 4 MiB, 20,000 plies across
mainline and variations, and 64 nested variation levels. File reads have a byte
cap even if the file grows after its size check.

Android backup and device transfer exclude only the extracted `maia_weights`
directory in application support storage. SQLite games, progress, rating history,
and settings retain their default backup eligibility.

Clock settings and times are stored but no countdown or timed-game flow runs.
Settings currently expose app theme, board theme, attack visibility, and its
own-pieces filter. The only selectable piece set is Cburnett.
