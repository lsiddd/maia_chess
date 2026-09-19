import 'package:integration_test/integration_test.dart';

import '../test/board_animation_lifecycle_test.dart' as regression;
import '../test/king_in_check_test.dart' as king_regression;
import '../test/game_result_test.dart' as result_regression;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  regression.main();
  king_regression.main();
  result_regression.main();
}
