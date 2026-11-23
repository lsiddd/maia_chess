import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';

class CampaignWins {
  const CampaignWins({this.white = 0, this.black = 0});

  static const requiredPerSide = 2;
  final int white;
  final int black;

  bool get completed => white >= requiredPerSide && black >= requiredPerSide;
  double get fraction => (white + black) / (2 * requiredPerSide);

  CampaignWins add(Side side, [int count = 1]) => switch (side) {
    Side.white => CampaignWins(
      white: math.min(requiredPerSide, white + count),
      black: black,
    ),
    Side.black => CampaignWins(
      white: white,
      black: math.min(requiredPerSide, black + count),
    ),
  };
}
