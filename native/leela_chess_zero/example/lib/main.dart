import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:leela_chess_zero/lc0.dart';
import 'package:path_provider/path_provider.dart';

import 'src/output_widget.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<StatefulWidget> createState() => _AppState();
}

class _AppState extends State<MyApp> {
  Lc0? lc0;
  String _status = 'Extracting weights...';
  String? _weightsPath;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeEngine();
  }

  Future<void> _initializeEngine() async {
    setState(() {
      _status = 'Extracting weights...';
      _isInitializing = true;
    });

    try {
      // First extract weights
      final dir = await getApplicationDocumentsDirectory();
      final weightsPath = '${dir.path}/maia-1900.pb.gz';

      if (!await File(weightsPath).exists()) {
        final data = await rootBundle.load('packages/leela_chess_zero/assets/weights/maia-1900.pb.gz');
        await File(weightsPath).writeAsBytes(data.buffer.asUint8List());
      }

      _weightsPath = weightsPath;
      setState(() => _status = 'Weights ready, starting engine...');

      // Now create lc0 with weights path
      lc0 = Lc0(weightsPath: weightsPath);

      setState(() {
        _status = 'Engine starting...';
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isInitializing = false;
      });
    }
  }

  void _resetEngine() {
    lc0?.dispose();
    lc0 = null;

    // Wait a moment for cleanup, then reinitialize
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_weightsPath != null) {
        lc0 = Lc0(weightsPath: _weightsPath);
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Leela Chess Zero (lc0) example'),
        ),
        body: _isInitializing
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_status),
                  ],
                ),
              )
            : lc0 == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_status),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initializeEngine,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: AnimatedBuilder(
                          animation: lc0!.state,
                          builder: (_, __) => Text(
                            'lc0.state=${lc0!.state.value}',
                            key: const ValueKey('lc0.state'),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Weights: maia-1900.pb.gz',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: AnimatedBuilder(
                          animation: lc0!.state,
                          builder: (_, __) => ElevatedButton(
                            onPressed: lc0!.state.value == Lc0State.disposed
                                ? _resetEngine
                                : null,
                            child: const Text('Reset lc0 instance'),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Custom UCI command',
                            hintText: 'go infinite',
                          ),
                          onSubmitted: (value) => lc0!.stdin = value,
                          textInputAction: TextInputAction.send,
                        ),
                      ),
                      Wrap(
                        children: [
                          'uci',
                          'isready',
                          'position startpos',
                          'go nodes 100',
                          'go movetime 3000',
                          'stop',
                          'quit',
                        ]
                            .map(
                              (command) => Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ElevatedButton(
                                  onPressed: () => lc0!.stdin = command,
                                  child: Text(command),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      Expanded(
                        child: OutputWidget(lc0!.stdout),
                      ),
                    ],
                  ),
      ),
    );
  }
}
