# LeelaChessZero (lc0)

The Leela Chess Zero (lc0) neural network chess engine for Flutter.

## About

Leela Chess Zero (lc0) is an open-source chess engine that uses deep neural networks to evaluate positions. It's based on the same approach as AlphaZero, using Monte Carlo Tree Search (MCTS) guided by a neural network.

## Requirements

- iOS: `IPHONEOS_DEPLOYMENT_TARGET` >= 13.0
- Android: `minSdkVersion` >= 24
- Neural network weights file (see below)

## Installation

Add dependency to `pubspec.yaml`:

```yaml
dependencies:
  LeelaChessZero: ^1.0.0
```

## Usage

### Initialize engine

```dart
import 'package:LeelaChessZero/lc0.dart';

// create a new instance
final lc0 = Lc0();

// state is a ValueListenable<Lc0State>
print(lc0.state.value); // Lc0State.starting

// the engine takes a few moments to start
await Future.delayed(...)
print(lc0.state.value); // Lc0State.ready
```

### Async initialization

```dart
// Wait for engine to be ready
final lc0 = await lc0Async();
```

### UCI commands

Waits until the state is ready before sending commands.

```dart
lc0.stdin = 'uci';
lc0.stdin = 'setoption name WeightsFile value /path/to/weights.pb.gz';
lc0.stdin = 'position startpos moves e2e4 e7e5';
lc0.stdin = 'go nodes 1000';
lc0.stdin = 'stop';
```

Engine output is directed to a `Stream<String>`:

```dart
lc0.stdout.listen((line) {
  print(line);
});
```

### Dispose / Hot reload

```dart
// sends the UCI quit command
lc0.stdin = 'quit';

// or even easier...
lc0.dispose();
```

**Note:** Only one instance can be created at a time. The factory method `Lc0()` will throw `StateError` if called when an existing instance is active.

## Neural Network Weights

Unlike Stockfish which embeds evaluation weights at compile time, lc0 requires you to provide a neural network weights file at runtime.

### Bundled Weights

This package includes **Maia-1900** weights (~1.2MB) - a neural network trained to play like a ~1900 rated human player. Maia networks are from the [maia-chess project](https://github.com/CSSLab/maia-chess).

To use the bundled weights, first copy them from assets to a writable location:

```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<String> extractWeights() async {
  final dir = await getApplicationDocumentsDirectory();
  final weightsPath = '${dir.path}/maia-1900.pb.gz';

  if (!await File(weightsPath).exists()) {
    final data = await rootBundle.load('assets/weights/maia-1900.pb.gz');
    await File(weightsPath).writeAsBytes(data.buffer.asUint8List());
  }

  return weightsPath;
}

// Then configure lc0:
final weightsPath = await extractWeights();
lc0.stdin = 'setoption name WeightsFile value $weightsPath';
```

### Loading custom weights

```dart
lc0.stdin = 'setoption name WeightsFile value /path/to/weights.pb.gz';
```

### Other recommended networks

| Network                        | Size    | Strength   | Notes                               |
| ------------------------------ | ------- | ---------- | ----------------------------------- |
| [Maia](https://maiachess.com/) | ~1-10MB | Human-like | Plays like humans at various levels |
| T80                            | ~15MB   | Strong     | Good balance of strength/speed      |

Download networks from [lczero.org](https://lczero.org/play/networks/) or [maiachess.com](https://maiachess.com/).

## Differences from Stockfish

| Aspect     | lc0             | Stockfish             |
| ---------- | --------------- | --------------------- |
| Evaluation | Neural network  | NNUE + classical      |
| Search     | MCTS            | Alpha-beta            |
| Weights    | Runtime loaded  | Compile-time embedded |
| Speed      | Slower per node | Faster per node       |
| Style      | More strategic  | More tactical         |

## Credits

- [Leela Chess Zero](https://lczero.org/) - The lc0 project and team
- [LeelaChessZero/lc0](https://github.com/LeelaChessZero/lc0) - Source repository
