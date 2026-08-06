# Requirements — Offline Chess App with Maia AI
**Platform:** Android · **Stack:** Flutter/Dart · **Distribution:** direct APK (sideload / open source)

## 1. Overview
Chess app for playing offline against an AI that imitates human playing styles at different levels, using weights from the **Maia Chess** project. The difficulty level determines which weight is loaded into the engine.

## 2. Technical Architecture
- **App UI and logic:** Flutter/Dart.
- **Chess rules:** Dart library for move generation/validation, game state, FEN/PGN (an existing package such as `chess` or a custom implementation).
- **"Opponent" AI (human style):** **lc0** engine compiled for Android via NDK (ABIs `arm64-v8a` and `armeabi-v7a`), run in-process and accessed via **Dart FFI**, speaking the UCI protocol internally. Loads the Maia weight corresponding to the chosen level, running with minimal search (nodes=1), which is Maia's intended/validated usage — it does not need deep search.
- **"Objectively best move" AI (for hints):** **Stockfish** engine compiled for Android, same approach via FFI.
- **100% offline:** no runtime network dependency.

> ⚠️ Running a native binary as an external process is not allowed on modern Android (W^X restrictions since API 29). lc0 and Stockfish must be integrated as native libraries (.so) called in-process via FFI — not as subprocesses launched from a file copied at runtime.

## 3. Difficulty Model
- **9 levels**, one per official Maia weight: 1100, 1200, 1300, ..., 1900 (100-point increments).
- All weight files (`.pb.gz`) **bundled in the APK** from install time.
- Switching levels reloads the corresponding weight in lc0.

## 4. Difficulty Navigation
- **Free Mode:** manual selection of any level at any time.
- **Campaign Mode (optional):** sequential progression 1100 → 1900. Unlocks the next level upon winning **X of Y games** at the current level (e.g., 2 of 3 — configurable).

## 5. Flow of a Game
1. Player chooses **side** (white/black) before each game.
2. Chooses level (free mode) or the level is set by the campaign.
3. Clock **disabled by default**, with the option to enable time controls (e.g., 5/10/30 min).
4. During the game:
   - **Undo** available.
   - **Hint button:** shows side by side (a) the move a player at that level would likely play (via Maia) and (b) the objectively best move (via Stockfish).
   - Using undo or a hint marks the game as **"unevaluated"**.
5. At the end: save to history and/or export PGN.

## 6. Persistence
- **Game in progress:** continuous autosave (closing and reopening the app resumes where it left off).
- **Game library:** history of finished games, with reopening/review and individual PGN export.
- **Import PGN:** load an external game for review.
- Local storage (e.g., Hive, Isar, or sqflite). No cloud sync.

## 7. Statistics and Rating
- Per level: wins, losses, draws.
- Current and record streaks.
- **Estimated player rating** based on performance against the Maia levels (e.g., a simplified Elo-like system).
- Chart of estimated rating evolution over time.
- "Unevaluated" games (with undo/hint used) appear in history but do **not** count toward rating/streak calculations.

## 8. UI/UX and Personalization
- Multiple selectable **piece sets**.
- **Dark/light mode.**
- Board: single theme in the MVP (no multiple board themes).
- Language: **Portuguese only** in v1.

## 9. Distribution
- Direct APK (sideload), open source project.
- No Google Play — so no store size limits, but the final installable size still deserves attention.

## 10. Non-Functional Requirements
- 100% offline functionality.
- Estimated app size: may exceed 200–300MB (9 Maia weights + Stockfish engine). Consider per-ABI builds (arm64-v8a / armeabi-v7a) to reduce per-device size.
- Performance: Maia's response (nodes=1) should be near-instant (<1s); Stockfish hint search configurable (e.g., 1–3s).
- Suggested minimum Android version: API 23+ (to be confirmed against NDK/lc0 build requirements).

## 11. Out of Scope for the MVP
- Online multiplayer.
- Multiple languages.
- Multiple board themes.
- Puzzle mode / opening trainer.
- Google Play / monetization.

## 12. Main Technical Risks
- **Compiling lc0 for Android and validating execution via FFI** is the biggest technical risk — an isolated technical spike validating this before building the rest of the app is recommended.
- Confirm availability and license of the official Maia weights (`CSSLab/maia-chess` repository).
- The same build/FFI work needs to be replicated for Stockfish.

## 13. Suggested Stack (summary)
| Layer | Technology |
|---|---|
| UI / app | Flutter (Dart) |
| Chess rules | Dart rules package (generation/validation, FEN/PGN) |
| "Human style" AI | lc0 + Maia weights, via FFI |
| "Best move" AI | Stockfish, via FFI |
| Storage | Hive / Isar / sqflite |
