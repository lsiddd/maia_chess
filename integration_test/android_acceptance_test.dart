// Consolidated suite: one build and installation on the emulator.
import 'board_interaction_android_test.dart' as board;
import 'game_review_android_test.dart' as review;
import 'move_sound_android_test.dart' as sounds;
import 'persistence_android_test.dart' as persistence;
import 'campaign_progress_android_test.dart' as campaign;
import 'game_screen_android_test.dart' as game;
import 'tactics_android_test.dart' as tactics;

void main() {
  sounds.main();
  tactics.main();
  review.main();
  persistence.main();
  campaign.main();
  game.main();
  board.main();
}
