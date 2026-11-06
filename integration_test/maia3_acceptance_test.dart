// One Android build exercises the model, live engines, and existing app flows.
import 'android_acceptance_test.dart' as app;
import 'maia3_android_test.dart' as model;
import 'phase_0_3_android_test.dart' as engines;

void main() {
  model.main();
  engines.main();
  app.main();
}
