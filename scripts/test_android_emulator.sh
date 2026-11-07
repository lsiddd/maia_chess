#!/usr/bin/env bash
set -euo pipefail
# Never select a connected personal device implicitly.
device="${1:?Pass an emulator serial}"
if [[ "$(adb -s "$device" shell getprop ro.kernel.qemu | tr -d '\r')" != '1' ]]; then
  echo 'Android acceptance requires an emulator; refusing a physical device.' >&2
  exit 1
fi
mkdir -p build
flutter test integration_test/maia3_acceptance_test.dart -d "$device" 2>&1 | tee build/android-integration.log
