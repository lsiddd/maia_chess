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