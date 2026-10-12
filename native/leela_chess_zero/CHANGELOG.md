# Changelog

## Unreleased — local Maia Chess fork

- Use private lc0 UCI pipes so Stockfish can run in the same process.
- Handle partial pipe writes and expose EOF reliably on native shutdown.
- Guard Dart cleanup against duplicate notifications and delayed startup.
- Include generated protobuf headers required by native builds.
- Remove the implicit Maia 1900 package asset; the standalone example declares
  its own network, while the main app declares all nine networks.

The entries below are inherited upstream release notes. Their bundled-weight
claim describes the original release, not the current local fork.

## [0.0.1] - December 2025

* Initial release.

## [1.0.0] - December 2025

* **Leela Chess Zero (lc0) engine**:
* Added neural network support with BLAS backend for Android
* Added Metal/Accelerate backend support for iOS
* Bundled Maia-1900 weights for human-like play
* New API: `lc0Async()` for async engine initialization
* New API: `weightsPath` parameter for custom neural network weights
* Requires C++20 for native builds
