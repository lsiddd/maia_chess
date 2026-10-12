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
| Local `leela_chess_zero` 1.0.0 plugin | GNU GPL v3 | [Vendored licence](native/leela_chess_zero/LICENSE), [fork documentation](native/leela_chess_zero/README.md), [upstream plugin](https://github.com/ArjanAswal/LeelaChessZero) |
| Vendored lc0 engine, snapshot 0.33.0-dev | GPL-3.0-or-later, with additional permissions in source-file notices | [COPYING](native/leela_chess_zero/ios/lc0/COPYING), source headers under `native/leela_chess_zero/ios/lc0/src/`, [upstream lc0](https://github.com/LeelaChessZero/lc0) |
| `stockfish` 1.8.1 plugin and bundled Stockfish engine | GNU GPL v3; engine source headers permit later versions | [Package licence](https://pub.dev/packages/stockfish/versions/1.8.1/license), [upstream plugin](https://github.com/ArjanAswal/stockfish), [Stockfish](https://github.com/official-stockfish/Stockfish) |
| `dartchess` 0.13.1 | GNU GPL v3 | [Package licence](https://pub.dev/packages/dartchess/versions/0.13.1/license), [upstream dartchess](https://github.com/lichess-org/dartchess) |

The application imports dartchess directly and integrates both engines through
in-process FFI. The local lc0 bridge and build changes are described in the
[plugin architecture](native/leela_chess_zero/architecture.md) and
[changelog](native/leela_chess_zero/CHANGELOG.md). Preserve the upstream notices
when redistributing these components or their modifications.

## Bundled chess assets and networks

| Material | Authors / origin | Licence and notices |
| --- | --- | --- |
| Twelve Cburnett piece SVGs | Colin M. L. Burnett; unmodified copies from Lichess | GPL-2.0-or-later; [provenance](assets/chess_pieces/NOTICE.md), [licence text](assets/chess_pieces/LICENSE-GPL-2.0.txt) |
| Brown, Blue, Green, and Purple board PNGs | The lila authors and pirouetti; unmodified copies from Lichess | AGPL-3.0-or-later; [provenance](assets/chess_boards/NOTICE.md), [licence text](assets/chess_boards/LICENSE-AGPL-3.0.txt) |
| Maia networks, ratings 1100–1900 | CSSLab/maia-chess, official v1.0 release; unmodified weights | Source repository uses GNU GPL v3; see [provenance](assets/maia_weights/NOTICE.md) and the [upstream licence](https://github.com/CSSLab/maia-chess/blob/master/LICENSE). |

The Lichess assets are pinned to commit
`3747530a154ab955bfbcd8e2bba58787479098d4`. Their respective licences are listed
in the upstream [COPYING.md](https://github.com/lichess-org/lila/blob/3747530a154ab955bfbcd8e2bba58787479098d4/COPYING.md).

## Native supporting code

| Component | Licence | Notices |
| --- | --- | --- |
| Eigen 3.4.0 fetched for Android; Eigen snapshot vendored for iOS | Primarily MPL-2.0; individual files contain other licence notices | [COPYING.README](native/leela_chess_zero/ios/eigen_header/COPYING.README) and the adjacent `COPYING.*` files; [Eigen upstream](https://gitlab.com/libeigen/eigen) |
| OpenXLA PJRT C API header | Apache-2.0 | Header notice in `native/leela_chess_zero/ios/lc0/third_party/pjrt_c_api.h` |
| Khronos OpenCL C++ header | Apache-2.0 | Header notice in `native/leela_chess_zero/ios/lc0/third_party/opencl.hpp` |
| Microsoft D3D12 helper header | MIT | Header notice in `native/leela_chess_zero/ios/lc0/third_party/d3dx12.h` |
| zlib | zlib licence | [Upstream licence](https://www.zlib.net/zlib_license.html); Android uses the NDK library and iOS uses the system library |

These notices cover supporting material present in the native sources; the
headers included in a build depend on the selected platform and backend.
Eigen's `COPYING.README` describes its file-specific exceptions, including LGPL
code. Retain the applicable file notices and licence texts.

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
| `logging` 1.3.0 | BSD-3-Clause |
| Transitive `dbus` 0.7.14 | MPL-2.0 |

Each package supplies its own licence text. Additional transitive and development
dependencies are recorded in [pubspec.lock](pubspec.lock); preserve their licence
texts and notices when their material is redistributed. The app exposes package
licences through **Appearance → Credits and licences** and registers the bundled
piece and board licence texts in
[`registerChessAssetLicenses`](lib/core/constants/chess_asset_licenses.dart).
