import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maia_chess/features/game/presentation/chess_board_widget.dart';

// flutter drive --profile --no-dds --driver=test_driver/performance.dart
//   --target=integration_test/board_performance_test.dart -d DEVICE
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('profile: tempo de frame durante arraste', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(dimension: 320, child: ChessBoardWidget()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final from = tester.getCenter(
      find.byKey(const ValueKey('board-square-6-4')),
    );
    final to = tester.getCenter(find.byKey(const ValueKey('board-square-4-4')));
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(to);
    await tester.pumpAndSettle();
    await binding.watchPerformance(() async {
      for (var frame = 0; frame < 180; frame++) {
        await gesture.moveTo(to + Offset((frame % 80) - 40, (frame % 60) - 30));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }, reportKey: 'board_drag');
    await gesture.cancel();
    await tester.pumpAndSettle();
    debugPrint('BOARD_PROFILE ${jsonEncode(binding.reportData)}');
    expect(tester.takeException(), isNull);
  }, skip: !kProfileMode);
}
