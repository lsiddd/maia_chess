import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maia_chess/features/game/application/move_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('classifyMoveFeedback', () {
    test('reconhece lance simples', () {
      expect(classifyMoveFeedback('e4'), MoveFeedbackKind.move);
      expect(classifyMoveFeedback('Nf3'), MoveFeedbackKind.move);
    });

    test('reconhece captura', () {
      expect(classifyMoveFeedback('exd5'), MoveFeedbackKind.capture);
      expect(classifyMoveFeedback('Nxe5'), MoveFeedbackKind.capture);
    });

    test('reconhece roque dos dois lados', () {
      expect(classifyMoveFeedback('O-O'), MoveFeedbackKind.castle);
      expect(classifyMoveFeedback('O-O-O'), MoveFeedbackKind.castle);
    });

    test('reconhece promoção', () {
      expect(classifyMoveFeedback('e8=Q'), MoveFeedbackKind.promotion);
      expect(classifyMoveFeedback('e8=N'), MoveFeedbackKind.promotion);
    });

    test('xeque e mate têm precedência sobre captura', () {
      expect(classifyMoveFeedback('Qxf7+'), MoveFeedbackKind.check);
      expect(classifyMoveFeedback('Qxf7#'), MoveFeedbackKind.checkmate);
    });

    test('roque com xeque é tratado como xeque', () {
      expect(classifyMoveFeedback('O-O+'), MoveFeedbackKind.check);
    });

    test('promoção com captura e mate é tratada como mate', () {
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

    test('cada tipo de lance emite retorno tátil', () async {
      for (final kind in MoveFeedbackKind.values) {
        await playMoveHaptic(kind);
      }

      expect(calls, hasLength(MoveFeedbackKind.values.length));
      expect(
        calls.every((call) => call.method == 'HapticFeedback.vibrate'),
        isTrue,
      );
    });

    test('mate vibra mais forte que um lance comum', () async {
      await playMoveHaptic(MoveFeedbackKind.move);
      await playMoveHaptic(MoveFeedbackKind.checkmate);

      expect(calls.first.arguments, 'HapticFeedbackType.selectionClick');
      expect(calls.last.arguments, 'HapticFeedbackType.heavyImpact');
    });
  });
}
