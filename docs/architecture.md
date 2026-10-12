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

## Storage and eligibility

SQLite lives in `maia_chess.sqlite` in the application documents directory and
runs through `NativeDatabase.createInBackground`. Schema version 4 contains
`games`, `game_moves`, `difficulty_progress`, `rating_history`, and `app_settings`.
Foreign keys are enabled; deleting a game cascades to its moves and rating rows.

Only one ongoing autosave is retained. Starting a new game removes the old
ongoing game transactionally. Saving compares move histories and writes only
the changed suffix, including undo. Completion is idempotent. Completion and
deletion rebuild rating/campaign state in the same transaction, using
`computeWithDatabase` to share the executor and notifications with a worker.
The library reads all games and moves in two queries; it is not paginated.

Statistics include completed AI games with a human side, a known result, and
`evaluated == true`. Assistance and undo clear that flag. Campaign progression
uses only eligible campaign games. Imported games are completed and unrated;
only their mainline is persisted for replay, while the stored PGN preserves
parsed headers, comments, and variations. Validation checks mainline and
variation legality before writing anything. Android file reading/decoding and
PGN validation run on workers.

Clock settings and times are stored but no countdown or timed-game flow runs.
Settings currently expose app theme, board theme, attack visibility, and its
own-pieces filter. The only selectable piece set is Cburnett.
