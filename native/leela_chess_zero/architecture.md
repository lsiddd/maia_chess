# Local lc0 plugin architecture

This describes the checked-in fork, rather than a generic or latest upstream
lc0 distribution. The Dart package version is 1.0.0;
`ios/lc0/src/version.inc` identifies the engine snapshot as **0.33.0-dev**.

## Dart and native boundary

| File | Responsibility |
| --- | --- |
| `lib/src/lc0.dart` | Singleton wrapper, state notifications, output stream, isolate startup, and cleanup |
| `lib/src/lc0_ffi.dart` | Resolve six exported native functions |
| `ios/FlutterLc0/ffi.cpp` | Private UCI pipes, weights path, engine entry point, partial-write handling, and shutdown EOF |
| `ios/lc0/src/mobile_uci_io.h` | Private input/output declarations used by the patched UCI loop |
| `ios/lc0/src/chess/uciloop.cc` | UCI command loop |

The exported functions are `lc0_init`, `lc0_abort_startup`, `lc0_set_weights`,
`lc0_main`, `lc0_stdin_write`, and `lc0_stdout_read`. Android loads `liblc0.so`;
iOS resolves symbols from `DynamicLibrary.process()`.

Deferred bootstrap creates the private pipes and supplies the weights path,
then spawns an engine isolate and a blocking output-reader isolate. The reader
buffers partial lines and sends complete lines to the Dart broadcast stream.
The main isolate reports its exit code. Both workers have exit notifications
registered when spawned; cleanup closes streams/subscriptions, sets terminal
state, and releases the singleton only after both have exited. An initialization
failure after the reader starts closes the output writer so the reader wakes on
EOF; a failure before either worker starts closes all pipe ends.

The bridge keeps lc0's pipes private instead of redirecting process-wide stdin
and stdout. Stockfish is another in-process engine; sharing those descriptors
previously caused competing blocking reads. The patched lc0 UCI loop uses
`ReadMobileUciInput` and `WriteMobileUciOutput` directly. Native exit writes
`quitok` and closes pipe ends so the reader observes EOF even when output is
coalesced.

Pipe descriptors start at `-1`; initialization rejects any surviving descriptors
or running engine. Descriptor changes and writes are synchronised, and stdout
reads retry interrupted system calls. The stdout reader drains to EOF instead
of treating a standalone `quitok` line as permission to close early.

The wrapper's `ready` state confirms bootstrap, while the application service
additionally waits for `isready`/`readyok` before searching. `dispose()` writes
`quit`, or records a shutdown request during bootstrap; it does not synchronously
join native isolates. See the
[API README](README.md) and application
[`Lc0Service`](../../lib/engine_ffi/lc0_engine/lc0_service.dart) for lifecycle rules.

## Android build

`android/build.gradle` enables `arm64-v8a` and `x86_64`, API 24 minimum, SDK 36,
NDK 28.2.13676358, JDK 17, and CMake 3.22.1. The main application matches the
NDK and ABI choices. `android/CMakeLists.txt` requires C++20 and builds the
shared library using `ios/lc0/src/` and the common FFI bridge.

CMake fetches Eigen 3.4.0 from its upstream Git repository. Android `cblas.h`
implements the BLAS calls used by the engine using Eigen. The default backend
is `blas` and the default search is `classic`. BLAS sources are included as
an OBJECT library; `blas_init.cc`, disabled function/data section splitting,
and `--no-gc-sections` preserve static backend registration. Linking uses NDK
zlib and Android logging, with 16 KB page-alignment flags. Release builds add
`-O3 -DNDEBUG` for both supported ABIs.

Generated Android configuration headers appear first on the include path so
they override the iOS defaults. Pre-generated protobuf headers remain under
`ios/lc0/build/proto/`. `Lc0Plugin.java` registers the Flutter plugin; command
transport uses FFI rather than a method channel.

## iOS configuration

`ios/leela_chess_zero.podspec` declares iOS 13, C++20, the common engine/bridge,
and Accelerate, Metal, MetalPerformanceShaders, MetalPerformanceShadersGraph,
and Foundation frameworks. Its script configures `blas` for simulators and
`metal` for other iOS targets, with `classic` search. Eigen headers are bundled
in `ios/eigen_header/`.

The podspec excludes tests, non-iOS GPU backends, Windows filesystem code, and
`dag_classic` search. Mobile sources use an Abseil compatibility shim and renamed
`lc0_string` files to avoid system-header conflicts. The pod script attempts
protobuf generation before compilation and tolerates generator failure, so
checked-in headers remain important. This is build configuration, not a claim
of current iOS validation: the main app CI builds only Android.

## Regenerate protobuf headers

From the repository root, if the corresponding definitions change:

```sh
cd native/leela_chess_zero/ios/lc0
python3 scripts/compile_proto.py proto/net.proto --proto_path=. --cpp_out=build
python3 scripts/compile_proto.py proto/onnx.proto --proto_path=. --cpp_out=build
python3 scripts/compile_proto.py proto/hlo.proto --proto_path=. --cpp_out=build
```

These arguments preserve the `proto/` prefix, producing
`build/proto/net.pb.h`, `onnx.pb.h`, and `hlo.pb.h` directly. Do not move them to
another include path or regenerate them merely to change documentation.

The lc0 and Eigen trees are external snapshots, not Git submodules. Preserve
upstream licences and historical documentation; review local bridge/build
changes against actual source paths before updating this guide.
