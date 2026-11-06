// Consolidated suite: one build and installation on the emulator.
import 'board_interaction_android_test.dart' as board;
import 'move_sound_android_test.dart' as sounds;
import 'phase_4_android_test.dart' as persistence;
import 'phase_5_android_test.dart' as campaign;
import 'section_2_android_test.dart' as game;
import 'tactics_android_test.dart' as tactics;

void main() {
  sounds.main();
  tactics.main();
  persistence.main();
  campaign.main();
  game.main();
  board.main();
}
