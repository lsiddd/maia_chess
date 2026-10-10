import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerChessAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Cburnett chess pieces',
    ], await rootBundle.loadString('assets/chess_pieces/LICENSE-GPL-2.0.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Lichess board themes',
    ], await rootBundle.loadString('assets/chess_boards/LICENSE-AGPL-3.0.txt'));
  });
}
