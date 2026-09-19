import 'package:integration_test/integration_test.dart';

import '../test/board_animation_lifecycle_test.dart' as regression;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  regression.main();
}
