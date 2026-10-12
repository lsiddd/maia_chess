# Leela Chess Zero Flutter plugin

This repository vendors a local fork of `leela_chess_zero` 1.0.0. It exposes lc0
through Dart FFI and UCI on Android and iOS. Maia Chess uses its Android build
for opponent moves; the application's Stockfish service handles assistance.
The local copy is not interchangeable with the hosted package without reviewing
its native modifications and packaging.

## Requirements and dependency

- Android: API 24+, ARM64 or x86_64, JDK 17, SDK 36, NDK 28.2.13676358,
  CMake 3.22.1. CMake fetches Eigen 3.4.0 during setup.
- The plugin also contains iOS configuration for iOS 13+, CocoaPods, and C++20.
  That target is separate from the Android-only main app and is not checked by
  its CI.
- A neural-network weights file at an absolute filesystem path.

The main app declares the fork from the repository root:

```yaml
dependencies:
  leela_chess_zero:
    path: native/leela_chess_zero
```

Use the actual package name in imports:

```dart
import 'package:leela_chess_zero/lc0.dart';
```

## API and readiness

`Lc0(weightsPath: path)` starts asynchronously. `lc0Async(weightsPath: path)` waits
for native bootstrap and returns the same kind of engine. Both expose
`state` (`ValueListenable<Lc0State>`), `stdout` (`Stream<String>`), and the `stdin`
setter. The states are `starting`, `ready`, `disposed`, and `error`.

Native `ready` means the isolates have started. It does **not** establish that
weights have loaded. Subscribe before sending `isready`, wait for `readyok`, then
search. For example, inside an async function with an existing absolute weights
path:

```dart
final engine = await lc0Async(weightsPath: weightsPath);
final ready = engine.stdout
    .firstWhere((line) => line.trim() == 'readyok')
    .timeout(const Duration(seconds: 120));
engine.stdin = 'isready';
await ready;

final reply = engine.stdout
    .firstWhere((line) => line.startsWith('bestmove '))
    .timeout(const Duration(seconds: 10));
engine.stdin = 'position startpos moves e2e4';
engine.stdin = 'go nodes 1';
final bestMoveLine = await reply;
```

This fragment illustrates command ordering, not a complete lifecycle manager.
Callers must handle timeouts, cancel output subscriptions, and send `stop` or
dispose after a failed search before reusing the engine. Maia Chess provides
those behaviours in
[`Lc0Service`](../../lib/engine_ffi/lc0_engine/lc0_service.dart).

Only one native instance is allowed at a time. `dispose()` sends `quit` and
returns immediately; wait for `disposed` or `error` before constructing another
instance. Sending commands, including `quit`, while still starting or after
shutdown throws. The package has no force-kill API. Hot reload does not replace
explicit lifecycle management.

## Weights and assets

The plugin itself declares **no weights asset**. The host chooses and bundles
its networks. Maia Chess declares nine `.pb.gz` files under
`assets/maia_weights/`; `Lc0Service.extractWeightsAsset` copies the selected file
to application support storage before initialisation. No runtime download is
needed.

The [standalone example](example/README.md) declares its own
`assets/weights/maia-1900.pb.gz`. The former implicit key
`packages/leela_chess_zero/assets/weights/maia-1900.pb.gz` is unavailable in this
fork. Consumers relying on it must declare their own asset. See the
[Maia provenance notice](../../assets/maia_weights/NOTICE.md).

## Native maintenance

[architecture.md](architecture.md) describes private UCI pipes shared by the
platform builds, the Android BLAS/Eigen backend, iOS build configuration, and
protobuf header regeneration. [CHANGELOG.md](CHANGELOG.md) distinguishes local
changes from the inherited release history. The plugin's
[GPL-3.0 licence](LICENSE) and upstream notices remain intact.
