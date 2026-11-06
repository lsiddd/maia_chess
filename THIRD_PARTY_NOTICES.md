# Third-party notices

Original Maia Chess code, documentation, and assets are licensed under
`AGPL-3.0-or-later`, as declared in the [README](README.md#licence-and-credits).
Third-party material retains the licences and copyright notices supplied by its
authors. The root [LICENSE](LICENSE) does not replace those terms.

Package versions below reflect [pubspec.lock](pubspec.lock). Vendored native
sources and bundled assets have their own notices in this repository.

## Chess engines and rules

| Component | Licence | Source and notices |
| --- | --- | --- |
| `stockfish` 1.8.1 plugin and bundled Stockfish engine | GNU GPL v3; engine source headers permit later versions | [Package licence](https://pub.dev/packages/stockfish/versions/1.8.1/license), [upstream plugin](https://github.com/ArjanAswal/stockfish), [Stockfish](https://github.com/official-stockfish/Stockfish) |
| `dartchess` 0.13.1 | GNU GPL v3 | [Package licence](https://pub.dev/packages/dartchess/versions/0.13.1/license), [upstream dartchess](https://github.com/lichess-org/dartchess) |

The application imports dartchess directly and integrates Maia-3 and Stockfish
through in-process FFI. Preserve upstream notices when redistributing components.

## Bundled chess assets and networks

| Material | Authors / origin | Licence and notices |
| --- | --- | --- |
| Twelve Cburnett piece SVGs | Colin M. L. Burnett; unmodified copies from Lichess | GPL-2.0-or-later; [provenance](assets/chess_pieces/NOTICE.md), [licence text](assets/chess_pieces/LICENSE-GPL-2.0.txt) |
| Brown, Blue, Green, and Purple board PNGs | The lila authors and pirouetti; unmodified copies from Lichess | AGPL-3.0-or-later; [provenance](assets/chess_boards/NOTICE.md), [licence text](assets/chess_boards/LICENSE-AGPL-3.0.txt) |
| Lichess SFX move and capture sounds | Enigmahack; unmodified copies of [Move.ogg](https://github.com/lichess-org/lila/blob/3747530a154ab955bfbcd8e2bba58787479098d4/public/sound/sfx/Move.ogg) and [Capture.ogg](https://github.com/lichess-org/lila/blob/3747530a154ab955bfbcd8e2bba58787479098d4/public/sound/sfx/Capture.ogg) | AGPL-3.0-or-later; [licence text](assets/chess_boards/LICENSE-AGPL-3.0.txt) |
| Maia-3 79M FP32 policy, 16 levels from 600–2600 | CSSLab / University of Toronto | AGPL-3.0; [provenance and conversion notes](assets/maia3/NOTICE.md), [licence text](assets/maia3/LICENSE-AGPL-3.0.txt) |

The Lichess assets are pinned to commit
`3747530a154ab955bfbcd8e2bba58787479098d4`. Their respective licences are listed
in the upstream [COPYING.md](https://github.com/lichess-org/lila/blob/3747530a154ab955bfbcd8e2bba58787479098d4/COPYING.md).
The move and capture sounds are bundled as `chess_move.ogg` and
`chess_capture.ogg` in Android's raw resources. Lichess lists its default
Standard sound set among the non-free exceptions.

## Native inference runtime

| Component | Licence | Notices |
| --- | --- | --- |
| ONNX Runtime 1.22.0 (Android binary supplied by onnxruntime_plus) | MIT | [Upstream licence](https://github.com/microsoft/onnxruntime/blob/v1.22.0/LICENSE), [third-party notices](https://github.com/microsoft/onnxruntime/blob/v1.22.0/ThirdPartyNotices.txt) |
| onnxruntime_plus 1.5.0 Dart FFI bindings | MIT | [Package licence](https://pub.dev/packages/onnxruntime_plus/versions/1.5.0/license) |

## Flutter and Dart packages

| Component | Licence |
| --- | --- |
| Flutter and Dart SDK components | BSD-style licences and component-specific third-party notices supplied with the SDKs |
| `cupertino_icons` 1.0.9 | MIT |
| `flutter_riverpod` 2.6.1 | MIT |
| `flutter_svg` 2.3.0 | MIT |
| `path_provider` 2.1.6 | BSD-3-Clause |
| `path` 1.9.1 | BSD-3-Clause |
| `drift` 2.34.3 | MIT |
| `share_plus` 12.0.2 | BSD-3-Clause |
| `file_picker` 11.0.3 | MIT |
| `uuid` 4.6.0 | MIT |
| `wakelock_plus` 1.5.2 | BSD-3-Clause |
| `ffi` 2.2.0 | BSD-3-Clause |
| `archive` 4.6.0 | MIT |
| `crypto` 3.0.7 | BSD-3-Clause |
| Transitive `dbus` 0.7.14 | MPL-2.0 |

Each package supplies its own licence text. Additional transitive and development
dependencies are recorded in [pubspec.lock](pubspec.lock); preserve their licence
texts and notices when their material is redistributed. The app exposes package
licences through **Appearance → Credits and licences** and registers the bundled
piece, board, and sound licence texts in
[`registerChessAssetLicenses`](lib/core/constants/chess_asset_licenses.dart).
