# Xadrez Maia

Offline Android chess app, built in Flutter/Dart, against an AI that imitates
human playing styles across different rating bands using weights from the
[Maia Chess](https://github.com/CSSLab/maia-chess) project (running on the
lc0 engine). A second AI (Stockfish) provides the objectively best move, for
the hint system. Open source project, distributed as a direct APK (sideload),
with no runtime network dependency.

Reference documentation:
- [`docs/requisitos.md`](docs/requisitos.md) — product requirements.
- [`docs/especificacao.md`](docs/especificacao.md) — technical specification
  and implementation phases.
- [`ADR.md`](ADR.md) — architecture decisions and deviations from the
  original specification, with rationale.

## Status

Phases 0–5 implemented: native lc0/Stockfish engines, games against Maia,
dual hint, Drift persistence, autosave/resume, library/replay, PGN
import/export, estimated rating, statistics, and 2-of-3 campaign. Phases 6–7
(personalization and final packaging) remain in development. See `ADR.md`
for the decisions and validations already carried out.

## How to run

Prerequisites: Flutter (managed in this environment via `fvm`), Android SDK +
NDK `28.2.13676358` installed, JDK 17.

```bash
flutter pub get
flutter run          # with an Android emulator/device connected
flutter analyze
flutter test
flutter test integration_test/phase_4_android_test.dart -d <device>
```

## Structure

Feature-first organization — see `docs/especificacao.md` section 3 for the
full rationale:

```
lib/
├── core/            # theming, constants
├── engine_ffi/       # lc0 (Maia) and Stockfish services via FFI
├── features/         # game, difficulty, hints, history, stats, settings, pgn
└── data/             # Drift database, repositories, Riverpod providers

native/                # vendored native dependencies (see ADR-001)
assets/maia_weights/   # Maia .pb.gz weights (1100-1900), from Phase 2 on
```

There is no dedicated DI folder: Riverpod providers live next to whoever
exposes them (`data/providers.dart` for repositories, and each
controller/service exposes its own, e.g.:
`GameController`/`lc0EngineFactoryProvider`), the idiomatic Riverpod
pattern.
