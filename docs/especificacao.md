# Technical Specification — Offline Chess App with Maia AI
**Reference document for an autonomous development agent**
Platform: Android · Framework: Flutter/Dart · Distribution: direct APK (sideload)

---

## 0. How to use this document
- Follow the **Implementation Phases (section 6)** in order. Each phase has an acceptance criterion; validate it before moving to the next.
- **Phase 0 is blocking**: if the technical spike fails, replan the architecture before proceeding with the rest of the document.
- Architecture decisions already made (section 2) must be followed. Any necessary deviation must be documented (e.g., in an `ADR.md` in the repository) with a rationale.
- Where this document leaves a decision open (section 9), the implementing AI may decide, as long as it records and justifies the choice.

---

## 1. Product Overview
Chess app for playing **offline** against an AI that imitates human playing styles across different rating bands, using weights from the **Maia Chess** project (based on Leela Chess Zero/lc0). The chosen difficulty level determines which weight is loaded into the engine. A second AI (Stockfish) provides an objectively best move suggestion, for the hint system.

---

## 2. Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Design pattern | **Feature-first** | Pragmatic, scales well for a medium-sized app, makes it easy to locate code by feature |
| State management | **Riverpod** (recommended) | Testable, good integration with async native calls (FFI in an Isolate), less boilerplate than Bloc, more structure than plain Provider. May be replaced if the agent identifies a better fit — document the decision |
| Persistence | **Drift (SQLite)** | Relational queries/aggregations needed for statistics (wins per level, streaks, rating evolution) benefit from SQL; supports reactive streams, integrating well with Riverpod |
| "Human style" AI | **lc0 + Maia weights**, via FFI, nodes=1 | Faithful to Maia's intended behavior (see section 4.1) |
| "Best move" AI | **Stockfish**, via FFI | Strong engine with existing precedent for Android/mobile builds |
| Chess rules | **Pure Dart** library (no dependency on a native engine) | Source of truth for board state; native engines only receive a FEN and return a suggested move |
| Min Android SDK | API 23+ (Android 6.0) — **to be confirmed in Phase 0** against NDK/lc0 build requirements | |

---

## 3. Folder Structure (Feature-First)

```
lib/
├── core/
│   ├── theming/
│   ├── di/                      # dependency injection setup / global providers
│   └── constants/
├── engine_ffi/
│   ├── lc0_engine/
│   │   ├── lc0_binding.dart      # raw FFI bindings
│   │   └── lc0_service.dart      # Dart-friendly API, runs in a dedicated Isolate
│   └── stockfish_engine/
│       ├── stockfish_binding.dart
│       └── stockfish_service.dart
├── features/
│   ├── game/                     # game in progress, board, interaction
│   ├── difficulty/               # level selection, campaign logic
│   ├── hints/                    # dual hint logic and UI (Maia + Stockfish)
│   ├── history/                  # saved games library
│   ├── stats/                    # statistics, estimated rating, charts
│   ├── settings/                 # piece sets, dark/light theme
│   └── pgn/                      # PGN import/export
└── data/
    ├── local/                    # Drift database, DAOs
    └── repositories/             # abstractions between features and the local layer

assets/
├── maia_weights/                 # 9 .pb.gz files (1100–1900)
└── native/                       # liblc0.so and libstockfish.so per ABI

android/
└── app/
    └── build.gradle              # ABI split configuration, NDK
```

---

## 4. Native Layer and FFI Contracts

### 4.1 lc0 Engine (Maia)
- Native library `liblc0_maia.so`, compiled via Android NDK for `arm64-v8a` and `armeabi-v7a`.
- Runs **in-process** (not as a subprocess — Android blocks execution of binaries written at runtime since API 29).
- Conceptual contract (signature, to be refined in Phase 0):
  ```
  int   lc0_init(const char* weights_path)
  char* lc0_get_best_move(const char* fen, int nodes)   // nodes = 1
  void  lc0_dispose(int handle)
  ```
- `nodes = 1` reproduces Maia's intended/validated usage: a single pass through the network (policy evaluation), with no tree search — that is how Maia was designed to imitate human moves.
- Wrap in `lc0_service.dart` exposing an async API (`Future<String> getBestMove(String fen)`), running the call in a **dedicated Isolate** so it does not block the UI.

### 4.2 Stockfish Engine (objective hint)
- Native library `libstockfish.so`, same build process (NDK) and same Isolate isolation pattern.
- Conceptual contract:
  ```
  char* stockfish_get_best_move(const char* fen, int depth_or_time_ms)
  ```

### 4.3 Chess Rules (pure Dart)
- Legal move generation/validation, check/checkmate/stalemate/draw detection, FEN ↔ PGN conversion.
- Use an existing Dart package (e.g., `chess` on pub.dev) or a custom implementation if the package doesn't cover everything.
- This layer is the sole authority on actual board state. Native engines only receive a FEN and return a move suggestion in UCI notation — final move validation still goes through the Dart rules layer.

---

## 5. Data Models (contracts)

### `GameRecord`
| Field | Type | Note |
|---|---|---|
| id | String/int | |
| startDate, endDate | DateTime | |
| difficultyLevel | int | 1100–1900 |
| playerSide | enum | white / black |
| result | enum | win / loss / draw |
| evaluated | bool | `false` if undo or hint was used |
| pgn | String | full game notation |
| campaignMode | bool | |
| timeUsed | Duration? | if clock active |

### `DifficultyLevel`
| Field | Type | Note |
|---|---|---|
| rating | int | 1100–1900 |
| weightAssetPath | String | path to the `.pb.gz` |
| winsRequired | int | e.g., 2 (of Y) to unlock the next, campaign |
| currentWins | int | current campaign progress |

### `PlayerStats`
| Field | Type | Note |
|---|---|---|
| estimatedRating | double | simplified Elo, computed from evaluated results |
| ratingHistory | List\<{date, value}\> | for the evolution chart |
| resultsByLevel | Map\<int, {wins, losses, draws}\> | |
| currentStreak, recordStreak | int | |

### `AppSettings`
| Field | Type | Note |
|---|---|---|
| pieceSet | enum | selected piece set |
| themeMode | enum | light / dark |
| clockEnabledByDefault | bool | default `false` |
| defaultTimeMinutes | int | used if clock is enabled |

---

## 6. Implementation Phases

### Phase 0 — Technical Spike (blocking)
**Goal:** validate the feasibility of running native lc0 and Stockfish on Android via FFI.
**Acceptance criterion:** minimal app with a button that loads a Maia weight, sends a fixed FEN, and receives a move via FFI, displayed as text. Repeat for Stockfish.
**If it fails:** replan the AI layer before proceeding (see section 9).

### Phase 1 — Rules Engine and Basic Board
- Chess rules in Dart + board UI (move pieces by tap/drag), no AI yet.
- **Acceptance criterion:** full game playable locally (two human players on the same device), with checkmate/stalemate correctly detected.

### Phase 2 — Maia AI Integration
- Connect `lc0_service` to the game flow; level selection loads the corresponding weight.
- **Acceptance criterion:** full game playable against the AI at at least 2 different difficulty levels.

### Phase 3 — Stockfish Hints
- Integrate `stockfish_service` and the dual hint button (Maia-style + Stockfish-objective, side by side).
- Implement "unevaluated" marking when a hint or undo is used.

### Phase 4 — Persistence
- Drift schema (tables for `GameRecord`, `DifficultyLevel`, `PlayerStats`), migrations.
- Autosave of the game in progress; game library; PGN import/export.

### Phase 5 — Statistics and Campaign Mode
- Estimated rating calculation, streaks, evolution chart.
- Level-unlock logic for the campaign (X of Y wins).

### Phase 6 — Personalization and Polish
- Multiple piece sets, dark/light mode, optional clock, basic sounds/animations.

### Phase 7 — Final Packaging
- ABI splits (`arm64-v8a` / `armeabi-v7a`) to reduce per-device size.
- Signed release build for direct distribution (sideload).

---

## 7. Non-Functional Requirements
- Maia response (nodes=1): p95 target < 1s on a mid-range reference device (define specific model in Phase 0).
- Stockfish hint response: configurable, default ~1–2s search.
- App 100% functional in airplane mode.
- Size per ABI: measure after Phase 0 and Phase 7; 9 Maia weights + Stockfish engine likely add up to 200–300MB+ before splits.

---

## 8. Out of Scope for the MVP
- Online multiplayer.
- Multiple languages (Portuguese only in v1).
- Multiple board themes (only piece sets vary).
- Puzzle mode / opening trainer.
- Google Play / monetization.

---

## 9. Known Ambiguities / Open Decisions
- **Maia weights license:** confirm terms of use/redistribution in the official repository (`CSSLab/maia-chess`) before embedding the `.pb.gz` files in the APK.
- **Feasibility of in-process FFI for lc0:** if Phase 0 shows that compiling/running the full lc0 is not viable within the timeframe, a fallback alternative is to convert the weights to TensorFlow Lite and implement only the network inference (without the full search engine) — see the caveat already recorded about the risk of behavioral divergence.
- **Riverpod vs. Bloc:** Riverpod is the recommendation; the agent may switch if prototyping shows a better fit, as long as it is documented.
- **Drift vs. another local solution:** Drift is the recommendation because of the statistics aggregations; only reevaluate if Phase 4 reveals significant friction.
