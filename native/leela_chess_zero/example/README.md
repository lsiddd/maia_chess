# lc0 standalone example

This separate Flutter app demonstrates the local `leela_chess_zero` plugin.
It extracts its declared Maia 1900 asset to application documents storage,
starts lc0, displays native state and output, and accepts UCI commands through
buttons or a text field. It is a diagnostic console, not the Maia Chess game UI.

## Run on Android

Use the [main project's Android prerequisites](../../../README.md#set-up-and-run).
From the repository root:

```sh
cd native/leela_chess_zero/example
flutter pub get
flutter run -d DEVICE
```

Replace `DEVICE` with a connected 64-bit Android device/emulator ID. The example
uses `assets/weights/maia-1900.pb.gz` from its own `pubspec.yaml`; the plugin
package does not supply an implicit network asset.

Wait for native ready, send **isready**, and wait for **readyok** in output before
searching. The example exposes raw commands and does not provide the main app's
readiness, cancellation, timeout, or error-recovery coordination. See the
[plugin API guide](../README.md).

```sh
flutter test integration_test/app_test.dart -d DEVICE
```

`integration_test/execute.sh` runs that test from this package without selecting
a device. The inherited smoke test uses fixed startup/exit delays and checks
wrapper state, not a complete weights handshake or move search.

## Other inherited tooling

The example contains an iOS runner for use on macOS with Xcode/CocoaPods and the
plugin's iOS 13+ configuration. It is not covered by the main app's Android CI.
`run_example.sh` is an inherited clean/build/install helper; inspect it and run
`./run_example.sh --help` before use. Its default runs Android and iOS paths and
removes local caches and lockfiles, including matching Runner derived-data
folders on macOS. Ordinary development can use `flutter run` above.
