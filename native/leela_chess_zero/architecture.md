# Leela Chess Zero (lc0) Flutter Package - Deep Dive

This package wraps the **Leela Chess Zero (lc0) neural network chess engine** (C++) for use in Flutter applications on Android and iOS. It uses **Dart FFI (Foreign Function Interface)** to communicate between Dart and native C++ code.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Dart Layer                               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Lc0 class (lib/src/lc0.dart)                               │ │
│  │  - stdin (setter) → sends UCI commands                      │ │
│  │  - stdout (stream) → receives engine output                 │ │
│  │  - state (ValueListenable) → tracks engine state            │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                       FFI Bindings                               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  lc0_ffi.dart - Loads native library & defines bindings     │ │
│  │  - nativeInit()       - nativeMain()                        │ │
│  │  - nativeStdinWrite() - nativeStdoutRead()                  │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                               │
                      DynamicLibrary.open()
                               │
┌─────────────────────────────────────────────────────────────────┐
│                      Native C++ Layer                            │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  ffi.cpp - Bridge between Dart and lc0                      │ │
│  │  - Creates pipes for stdin/stdout redirection               │ │
│  │  - Exposes C functions callable from Dart                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  lc0 Engine (ios/lc0/src/*)                                 │ │
│  │  - UCI protocol implementation                              │ │
│  │  - Neural network evaluation (BLAS/Metal backends)          │ │
│  │  - MCTS search algorithm                                    │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## How the Dart Layer Works

### 1. Lc0 Class (`lib/src/lc0.dart`)

The `Lc0` class is a **singleton** - only one instance can exist at a time. When created:

1. **Two Dart Isolates are spawned** (in separate compute contexts):
   - **Main Isolate**: Runs `nativeMain()` which starts the lc0 engine loop
   - **Stdout Isolate**: Continuously polls `nativeStdoutRead()` to get engine output

2. **State management** via `ValueListenable<Lc0State>`:
   - `starting` → Engine is initializing
   - `ready` → Engine is running and accepting commands
   - `disposed` → Engine has been shut down
   - `error` → Engine failed to start

### 2. FFI Bindings (`lib/src/lc0_ffi.dart`)

```dart
final _nativeLib = Platform.isAndroid
    ? DynamicLibrary.open('liblc0.so')
    : DynamicLibrary.process();

final int Function() nativeInit = _nativeLib
    .lookup<NativeFunction<Int32 Function()>>('lc0_init')
    .asFunction();

final int Function() nativeMain = _nativeLib
    .lookup<NativeFunction<Int32 Function()>>('lc0_main')
    .asFunction();

final int Function(Pointer<Utf8>) nativeStdinWrite = _nativeLib
    .lookup<NativeFunction<IntPtr Function(Pointer<Utf8>)>>('lc0_stdin_write')
    .asFunction();

final Pointer<Utf8> Function() nativeStdoutRead = _nativeLib
    .lookup<NativeFunction<Pointer<Utf8> Function()>>('lc0_stdout_read')
    .asFunction();
```

**Key difference between platforms:**
- **Android**: Loads `liblc0.so` as a separate shared library
- **iOS**: Uses `DynamicLibrary.process()` - symbols are linked into the main process

Four FFI functions are exposed:
| Function            | Purpose                                    |
| ------------------- | ------------------------------------------ |
| `lc0_init()`        | Creates pipes for stdin/stdout redirection |
| `lc0_main()`        | Starts the lc0 main loop                   |
| `lc0_stdin_write()` | Sends UCI commands to the engine           |
| `lc0_stdout_read()` | Reads output from the engine               |

---

## iOS Implementation

### Plugin Structure

```
ios/
├── Classes/
│   ├── Lc0Plugin.h              # Flutter plugin header
│   └── Lc0Plugin.mm             # Plugin registration (prevents dead code stripping)
├── FlutterLc0/
│   ├── ffi.cpp                  # FFI bridge implementation
│   └── ffi.h                    # C function declarations
├── eigen_header/                # Eigen 3.4.0 (vendored, header-only linear algebra)
├── lc0/                         # Full lc0 source code (vendored from GitHub)
│   ├── src/                     # Engine source (with mobile-specific modifications)
│   │   └── utils/
│   │       ├── absl_compat.h    # Abseil compatibility shim for iOS/Android
│   │       ├── lc0_string.h     # Renamed from string.h (avoids system header conflict)
│   │       └── logging.cc       # Modified for Android logcat support
│   ├── build/proto/             # Generated proto headers (net.pb.h, onnx.pb.h, hlo.pb.h)
│   ├── proto/                   # Protobuf definitions (.proto source files)
│   └── scripts/compile_proto.py # Proto header generator (used during setup)
└── LeelaChessZero.podspec       # CocoaPods configuration
```

### FFI Bridge (`ffi.cpp`)

The FFI bridge is shared between iOS and Android (`ios/FlutterLc0/ffi.cpp`):

```cpp
int lc0_init()
{
    pipe(pipes[PARENT_READ_PIPE]);
    pipe(pipes[PARENT_WRITE_PIPE]);
    return 0;
}

void lc0_set_weights(const char* path)
{
    weightsPath = path;  // Static string to pass weights path to main()
}

int lc0_main()
{
    // UCI uses lc0's private pipe functions directly. Do not redirect the
    // process-wide stdin/stdout: another in-process engine may use them.

    try {
        const char *argv[] = {"lc0", weightsArg.c_str()};
        exitCode = main(2, argv);
    } catch (std::exception& e) {
        LOGE("lc0 main threw exception: %s", e.what());
        exitCode = 1;
    }

    lczero::WriteMobileUciOutput("quitok");
    close(CHILD_WRITE_FD);
    return exitCode;
}

ssize_t lc0_stdin_write(char *data)
{
    return write(PARENT_WRITE_FD, data, strlen(data));
}

char *lc0_stdout_read()
{
    ssize_t count = read(PARENT_READ_FD, buffer, sizeof(buffer) - 1);
    if (count < 0) return nullptr;
    buffer[count] = '\0';
    if (strcmp(buffer, QUITOK) == 0) return nullptr;
    return buffer;
}
```

**How it works:**

1. **`lc0_init()`**: Creates two private Unix pipes for UCI input/output
2. **`lc0_set_weights()`**: Stores weights file path (called before `lc0_main`)
3. **`lc0_main()`**:
   - Keeps process-wide stdin/stdout untouched so Stockfish can coexist
   - Reads with `ReadMobileUciInput()` and writes UCI responses with
     `WriteMobileUciOutput()`
   - Keeps stderr going to logcat on Android
   - Wraps lc0 `main()` in try-catch to capture native exceptions
   - Calls lc0's `main()` function, entering the UCI loop
   - Outputs `quitok\n` when engine exits
4. **`lc0_stdin_write()`**: Writes data to lc0's private input pipe
5. **`lc0_stdout_read()`**: Reads from lc0's private output pipe (blocking)

### Build Configuration (`LeelaChessZero.podspec`)

Key points:
- Uses **BLAS** backend (default) with Apple's vecLib for CPU-based inference
- **Metal** backend available for GPU-accelerated inference
- **Accelerate** framework for optimized BLAS operations
- **Eigen** library for linear algebra (bundled as header-only)
- **C++20** standard required
- Minimum iOS deployment target: **13.0**

#### iOS-specific Modifications:
- `utils/string.h` renamed to `utils/lc0_string.h` to avoid conflicts with system `<string.h>`
- `utils/absl_compat.h` provides lightweight replacements for abseil dependencies:
  - `absl::Cleanup` RAII wrapper
  - `ABSL_UNREACHABLE()` macro
- Excluded backends: CUDA, DirectX, OpenCL, oneDNN, SYCL, XLA
- Excluded search: dag_classic (uses abseil extensively)

---

## Android Implementation

### Plugin Structure

```
android/
├── src/main/java/com/leelachesszero/
│   └── Lc0Plugin.java          # Empty Flutter plugin (no-op, FFI handles everything)
├── src/main/AndroidManifest.xml # Plugin manifest (namespace via build.gradle)
├── build.gradle                 # Gradle build (namespace: com.leelachesszero.flutter)
├── settings.gradle              # Gradle settings (rootProject.name = 'LeelaChessZero')
├── CMakeLists.txt              # CMake configuration for NDK
├── blas_init.cc                # Forces BLAS backend linkage via constructor attribute
├── cblas.h                     # CBLAS interface implemented using Eigen
├── cblas_eigen.h               # Alternative Eigen CBLAS header
└── *.h.in                       # Configuration header templates (build_id, default_backend, etc.)
```

### CMake Configuration

The Android build uses CMake via the NDK with the following architecture:

1. **Fetches Eigen 3.4.0** (header-only linear algebra library) via FetchContent
2. **Uses BLAS backend** (`blas`) as default for CPU-based neural network inference
3. **Reuses iOS lc0 source** - Android CMake references `ios/lc0/src/*` to avoid duplication
4. **Reuses FFI bridge** - `ios/FlutterLc0/ffi.cpp` is shared between platforms

**Key build details:**

```cmake
# Include directory order is CRITICAL - Android headers must override iOS ones
include_directories(
    ${CMAKE_CURRENT_BINARY_DIR}  # Generated headers (default_backend.h = "blas")
    ${LC0_SRC}                   # lc0 source
    ${LC0_BUILD}                 # iOS build headers (overridden by above)
    ...
)
```

**BLAS Backend Registration:**

The `blas_init.cc` file solves a critical linking issue: lc0's backend registration uses static constructors that can be stripped by the linker. This file forces linkage:

```cpp
// Uses __attribute__((constructor)) to run before main()
__attribute__((constructor))
static void InitBlasBackends() {
    volatile void* blas_ptr = reinterpret_cast<void*>(&MakeBlasNetwork<false>);
    volatile void* eigen_ptr = reinterpret_cast<void*>(&MakeBlasNetwork<true>);
}
```

Additionally, CMake uses `OBJECT` library for BLAS sources and `--no-gc-sections` linker flag to prevent dead code elimination.

**CBLAS Implementation:**

Android doesn't have a system BLAS library, so `cblas.h` provides a complete CBLAS implementation using Eigen:
- `cblas_sgemm()` - Matrix multiplication
- `cblas_sgemv()` - Matrix-vector multiplication
- `cblas_sdot()` - Dot product
- `cblas_saxpy()` / `cblas_sscal()` - Vector operations
- OpenBLAS compatibility stubs (`openblas_get_num_procs`, etc.)

### Android-specific Logging

The FFI bridge and lc0 logging are modified for Android debugging:

```cpp
// ffi.cpp - Uses Android logcat
#ifdef __ANDROID__
#include <android/log.h>
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "LC0_FFI", __VA_ARGS__)
#endif

// logging.cc - CERR/COUT redirect to logcat on Android
StderrLogMessage::~StderrLogMessage() {
#ifdef __ANDROID__
  __android_log_print(ANDROID_LOG_ERROR, "LC0", "%s", str().c_str());
#else
  std::cerr << str() << std::endl;
#endif
}
```

**Key Android build points:**
- Builds `liblc0.so` - a shared library loaded via `DynamicLibrary.open()`
- **C++20** standard required (`-std=c++20`)
- **NDK version**: 28.2.13676358
- Supported ABIs: `arm64-v8a`, `x86_64`
- Architecture-specific `IS_64BIT` flag for 64-bit platforms
- Release builds use `-O3 -DNDEBUG` optimizations

---

## Neural Network Backends

lc0 uses neural networks for position evaluation. This Flutter package supports:

| Platform | Backend | Default | Description                               |
| -------- | ------- | ------- | ----------------------------------------- |
| iOS      | blas    | ✓       | CPU BLAS via Apple's vecLib (Accelerate)  |
| iOS      | metal   |         | GPU-accelerated via Metal API             |
| iOS      | eigen   |         | CPU-based using Eigen library             |
| Android  | blas    | ✓       | CPU-based with Eigen CBLAS implementation |

**Available on both platforms:** trivial, random, check, roundrobin, recordreplay, multiplexing, demux (utility/testing backends)

**Note:** To use lc0, you need to load a neural network weights file. This package bundles **Maia-1900** (~1.2MB) for human-like play. See lc0 documentation for additional networks.

---

## Communication Flow

```
┌──────────────────┐     UCI Commands      ┌──────────────────────────────┐
│                  │  ─────────────────►   │                              │
│   Dart App       │      (via pipe)       │      lc0 Engine              │
│                  │  ◄─────────────────   │         (C++)                │
│                  │     UCI Output        │                              │
└──────────────────┘      (via pipe)       └──────────────────────────────┘

                    Dart Side                       Native Side
┌────────────────────────────────┐    ┌────────────────────────────────────┐
│ lc0.stdin = 'go nodes 1000'    │───►│ lc0_stdin_write() writes to        │
│                                │    │ pipe → lc0 reads via stdin         │
├────────────────────────────────┤    ├────────────────────────────────────┤
│ lc0.stdout.listen()            │◄───│ lc0 writes to stdout → pipe        │
│ receives "bestmove e2e4"       │    │ → lc0_stdout_read() returns        │
└────────────────────────────────┘    └────────────────────────────────────┘
```

---

## Usage Example

```dart
import 'package:LeelaChessZero/lc0.dart';

// Create engine instance
final lc0 = Lc0();

// Wait for engine to be ready
lc0.state.addListener(() {
  if (lc0.state.value == Lc0State.ready) {
    // Send UCI commands
    lc0.stdin = 'uci';
    lc0.stdin = 'setoption name WeightsFile value /path/to/weights.pb.gz';
    lc0.stdin = 'position startpos moves e2e4';
    lc0.stdin = 'go nodes 1000';
  }
});

// Listen to engine output
lc0.stdout.listen((line) {
  print(line);  // "bestmove d7d5"
});

// Dispose when done
lc0.dispose();  // or lc0.stdin = 'quit'
```

---

## Key Differences: iOS vs Android

| Aspect               | iOS                                                  | Android                            |
| -------------------- | ---------------------------------------------------- | ---------------------------------- |
| Package Name         | LeelaChessZero (podspec)                             | LeelaChessZero (settings.gradle)   |
| Library Loading      | `DynamicLibrary.process()` (linked into main binary) | `DynamicLibrary.open('liblc0.so')` |
| Build System         | CocoaPods (LeelaChessZero.podspec)                   | CMake via NDK                      |
| NN Backend           | BLAS (vecLib) / Metal (optional)                     | BLAS (CPU via Eigen)               |
| Linear Algebra       | Eigen (bundled) + Accelerate                         | Eigen (fetched via CMake)          |
| Dead Code Prevention | Fake function calls in plugin                        | Not needed (shared library)        |
| Minimum Version      | iOS 13.0                                             | Android SDK 24                     |
| C++ Standard         | C++20                                                | C++20                              |

---

## Vendored Dependencies

This package includes vendored copies of external dependencies (no git submodules):

| Dependency | Version | Location            | Purpose                              |
| ---------- | ------- | ------------------- | ------------------------------------ |
| **lc0**    | latest  | `ios/lc0/`          | Leela Chess Zero engine source       |
| **Eigen**  | 3.4.0   | `ios/eigen_header/` | Header-only linear algebra (iOS)     |
| **Eigen**  | 3.4.0   | Fetched via CMake   | Header-only linear algebra (Android) |

### lc0 Source Modifications

The vendored lc0 source includes mobile-specific modifications:

1. **`utils/string.h` → `utils/lc0_string.h`**: Renamed to avoid conflict with system `<string.h>` header
2. **`utils/absl_compat.h`**: Lightweight abseil replacements (`absl::Cleanup`, `ABSL_UNREACHABLE`)
3. **`utils/logging.cc`**: Android logcat integration via `__android_log_print()`
4. **`chess/board.cc`**: Uses `absl_compat.h` instead of full abseil
5. **`utils/weights_adapter.cc`**: Uses `absl_compat.h` for `ABSL_UNREACHABLE`
6. **`main.cc`**: Uses `CERR` macro for exception logging

### Proto Header Generation

lc0 uses a custom protobuf-like message system. The proto headers are pre-generated and committed:

```
ios/lc0/build/proto/
├── net.pb.h    # Neural network weights format
├── onnx.pb.h   # ONNX model format
└── hlo.pb.h    # HLO (XLA) format
```

To regenerate (if proto definitions change):
```bash
cd ios/lc0
python3 scripts/compile_proto.py --proto_path=proto --cpp_out=build proto/net.proto
python3 scripts/compile_proto.py --proto_path=proto --cpp_out=build proto/onnx.proto
python3 scripts/compile_proto.py --proto_path=proto --cpp_out=build proto/hlo.proto
mv build/*.pb.h build/proto/
```

---

## Neural Network Weights

lc0 requires a neural network weights file to function. Unlike Stockfish which embeds NNUE weights at compile time, lc0 loads weights at runtime.

Options for providing weights:
1. **Bundle with app**: Include a small network file in assets
2. **Download at runtime**: Fetch from lczero.org
3. **User-provided**: Let users select their preferred network

Recommended networks for mobile:
- **Maia networks**: Human-like play, smaller size (~10MB)
- **T80 networks**: Strong play, small size (~15MB)
- **Larger networks**: Strongest play but require more memory/CPU

See [lczero.org](https://lczero.org/play/networks/) for network downloads.
