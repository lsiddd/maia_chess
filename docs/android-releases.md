# Android builds and releases

The source of truth is [.github/workflows/ci.yaml](../.github/workflows/ci.yaml)
and [android/app/build.gradle.kts](../android/app/build.gradle.kts). The workflow
builds with Flutter 3.47.4, JDK 17, SDK/build tools 36, NDK 28.2.13676358, and
CMake 3.22.1.

## Workflow behaviour

| Trigger | Checks | APK and publication |
| --- | --- | --- |
| Pull request targeting `main` | Analysis, formatting, Flutter tests, Python tests | No APK job or publication |
| Push to `main` | Same checks | Release-signed ARM64 artifact and moving nightly pre-release |
| Push of a tag matching `v*` | Same checks; tag must validate as `vX.Y.Z` | Release-signed ARM64 artifact and stable release |
| Manual run on `main` with empty `release_tag` | Same checks | Artifact only; debug-signed if no signing secrets are supplied |
| Manual run with an existing `release_tag` | Checks on tagged source | Signed artifact and stable release for that exact tag |

The `android-release` artifact contains the versioned APK and `SHA256SUMS` and
is retained for 14 days. Coverage is uploaded as `coverage-lcov`. Publication
jobs have `contents: write`; other jobs default to read-only repository access.
Pull requests do not run signing steps.

Nightlies are titled **Maia Chess Nightly** and contain
`maia-chess-nightly-arm64-v8a.apk` plus `SHA256SUMS`. The existing automation
moves the `nightly` tag and updates that pre-release in place. It serialises
publication and checks the latest `main` SHA before publishing so a superseded
build cannot replace the newer nightly. This is the only tag/release designed
to be overwritten. It does not become the latest stable release.

Stable artifacts are named `maia-chess-X.Y.Z-arm64-v8a.apk`. The tag supplies
`--build-name`; `GITHUB_RUN_NUMBER` supplies `--build-number`. Non-tag builds use
the version name from `pubspec.yaml`. Nightly and stable APKs use the same release
key. Publication fails if the stable release already exists; use a new version
tag for a new publication.

Both release bodies use English templates with source and CI links. Stable
notes link to the SHA actually checked out, including manual tag retries. They
do not derive summaries from historical commit or PR titles. A maintainer can
add reviewed English feature notes when preparing a release. Previously
published external notes are unchanged by repository edits.

## Signing secrets

Configure all four repository Actions secrets together:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded keystore without line breaks |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Signing alias |
| `ANDROID_KEY_PASSWORD` | Private-key password |

`scripts/configure_android_signing.py` requires signing for tags, manual tag
publication, and pushes to `main`. Partial secret configuration always fails.
An artifact-only manual run on a branch without any signing secrets falls back to debug
signing. The script escapes Java properties, writes private files with mode
0600, and avoids logging secret values. The APK job removes its generated
`android/app/key.properties` and `android/app/ci-release.jks` even after failure.

Keep a backup of the key and passwords. Android updates require the same signing
key; a debug-signed installation cannot be updated with the release-signed APK.

## Local signing and build

Generate a dedicated key, or use the existing distribution key:

```sh
keytool -genkeypair -v -keystore android/app/release-keystore.jks -alias maia_chess_release -keyalg RSA -keysize 2048 -validity 10000
```

Create ignored `android/app/key.properties`:

```properties
storeFile=release-keystore.jks
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=maia_chess_release
keyPassword=YOUR_KEY_PASSWORD
```

`storeFile` is resolved relative to `android/app`. Escape spaces, backslashes,
and other Java properties characters when entering passwords manually. Keep
both files out of Git.

```sh
flutter pub get
flutter build apk --release --split-per-abi --target-platform android-arm64
python3 scripts/verify_apk.py build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify --verbose build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
"$ANDROID_HOME/build-tools/36.0.0/zipalign" -c -P 16 4 build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

The content verifier requires Flutter libraries, lc0, Stockfish, all nine Maia
networks, no other ABI, no duplicate plugin Maia 1900 asset, and valid ZIP
entries. CI executes that verifier and `apksigner`; ZIP alignment is an
additional local check, not a current CI step. The Python verifier accepts only
an ARM64 APK. To build a separate x86_64 emulator APK, use
`--target-platform android-x64`; do not pass it to the ARM64 verifier.

Without `key.properties`, Gradle warns and uses debug signing even for
`--release`. That is useful for testing and does not produce a distribution-key
artifact. Run Android builds and integration tests sequentially. After integration
tests, allow the normal build command to refresh dependencies and plugin
registration; `--no-pub` can reuse a stale integration-test registrant.

## Publish or retry a stable release

After the checks pass, tag the intended commit with a new version:

```sh
git tag v1.0.1
git push origin v1.0.1
```

The version here is an example; choose an unused `vX.Y.Z` tag. CI validates the
format and publishes only after the signed build and packaging checks pass.
This document does not authorise rewriting an existing published version tag.

If infrastructure fails before publication, fix the workflow on `main`, then
use **Actions → CI → Run workflow** on `main` with `release_tag` set to the
existing tag. The corrected workflow checks out and builds the exact tagged
source. Source/build defects require a corrected commit and new version tag.
If a release already exists, investigate it separately instead of assuming a
retry will overwrite it. Never translate published history or external release
notes by force-pushing tags.
