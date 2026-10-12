import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/features/game/application/move_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('classifyMoveFeedback', () {
    test('recognises a quiet move', () {
      expect(classifyMoveFeedback('e4'), MoveFeedbackKind.move);
      expect(classifyMoveFeedback('Nf3'), MoveFeedbackKind.move);
    });

    test('recognises a capture', () {
      expect(classifyMoveFeedback('exd5'), MoveFeedbackKind.capture);
      expect(classifyMoveFeedback('Nxe5'), MoveFeedbackKind.capture);
    });

    test('recognises castling on both sides', () {
      expect(classifyMoveFeedback('O-O'), MoveFeedbackKind.castle);
      expect(classifyMoveFeedback('O-O-O'), MoveFeedbackKind.castle);
    });

    test('recognises promotion', () {
      expect(classifyMoveFeedback('e8=Q'), MoveFeedbackKind.promotion);
      expect(classifyMoveFeedback('e8=N'), MoveFeedbackKind.promotion);
    });

    test('check and mate take precedence over capture', () {
      expect(classifyMoveFeedback('Qxf7+'), MoveFeedbackKind.check);
      expect(classifyMoveFeedback('Qxf7#'), MoveFeedbackKind.checkmate);
    });

    test('castling with check is classified as check', () {
      expect(classifyMoveFeedback('O-O+'), MoveFeedbackKind.check);
    });

    test('promotion with capture and mate is classified as mate', () {
      expect(classifyMoveFeedback('exd8=Q#'), MoveFeedbackKind.checkmate);
    });
  });

  group('playMoveHaptic', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('each move type produces haptic feedback', () async {
      for (final kind in MoveFeedbackKind.values) {
        await playMoveHaptic(kind);
      }

      expect(calls, hasLength(MoveFeedbackKind.values.length));
      expect(
        calls.every((call) => call.method == 'HapticFeedback.vibrate'),
        isTrue,
      );
    });

    test('mate vibrates more strongly than a quiet move', () async {
      await playMoveHaptic(MoveFeedbackKind.move);
      await playMoveHaptic(MoveFeedbackKind.checkmate);

      expect(calls.first.arguments, 'HapticFeedbackType.selectionClick');
      expect(calls.last.arguments, 'HapticFeedbackType.heavyImpact');
    });
  });
}
