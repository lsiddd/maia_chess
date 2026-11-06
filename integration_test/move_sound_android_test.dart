import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android plays both bundled chess samples', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    const channel = MethodChannel('maia_chess/move_sounds');

    for (final sound in ['move', 'capture']) {
      var played = false;
      for (var attempt = 0; attempt < 40 && !played; attempt++) {
        played = await channel.invokeMethod<bool>(sound) ?? false;
        if (!played) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      }
      expect(
        played,
        isTrue,
        reason: 'SoundPool did not play the $sound sample',
      );
    }
  });
}
