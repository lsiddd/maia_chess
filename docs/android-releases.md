# Android builds and releases

The source of truth is [.github/workflows/ci.yaml](../.github/workflows/ci.yaml)
and [android/app/build.gradle.kts](../android/app/build.gradle.kts). The workflow
builds with Flutter 3.47.4, JDK 17, SDK/build tools 36, NDK 28.2.13676358, and
CMake 3.22.1.

## Workflow behaviour

| Trigger | Checks | APK and publication |
| --- | --- | --- |
| Pull request targeting `main` | Analysis, formatting, Flutter tests, Python tests, native Android acceptance | No APK job or publication |
| Push to `main` | Same checks | Release-signed ARM64 artifact and moving nightly pre-release |
| Push of a tag matching `v*` | Same checks; tag must validate as `vX.Y.Z` | Release-signed ARM64 artifact and stable release |
| Daily at 06:17 UTC / 03:17 America/Belem | Same checks | Signed nightly from current `main` |
| Manual run on `main` with `publish_nightly: true` and empty `release_tag` | Same checks | Signed nightly from current `main` |
| Manual run with `publish_nightly: false` and empty `release_tag` | Same checks | Artifact only; debug-signed if no signing secrets are supplied |
| Manual run with an existing `release_tag` | Checks on tagged source | Signed artifact and stable release for that exact tag |

The `android-release` artifact contains the versioned APK and `SHA256SUMS` and
is retained for 14 days. Coverage is uploaded as `coverage-lcov`. Publication
jobs have `contents: write`; other jobs default to read-only repository access.
Pull requests do not run signing steps.

Nightlies are titled **Maia Chess Nightly** and contain
`maia-chess-nightly-arm64-v8a.apk` plus `SHA256SUMS`. The existing automation
moves the `nightly` tag and updates that pre-release in place. It serialises
publication and checks the latest `main` SHA before publishing so a superseded
build cannot replace the newer nightly. A build-number guard also prevents a
late-finishing build of the same commit from replacing an APK with a newer
Android version code. The release notes carry a machine-readable build marker;
existing notes are recognised by their version/build line. Unknown metadata
fails publication safely, and rerunning the same build can repair a partial
upload. This is the only tag/release designed
to be overwritten. It does not become the latest stable release.

Stable artifacts are named `maia-chess-X.Y.Z-arm64-v8a.apk`. The tag supplies
`--build-name`; `GITHUB_RUN_NUMBER` supplies `--build-number`. Nightly builds append `-nightly.RUN_NUMBER` to the version name from
`pubspec.yaml`, so Android identifies installed development builds clearly.
Other non-tag builds use the unmodified version name from `pubspec.yaml`. Nightly and stable APKs use the same release
key. Publication fails if the stable release already exists; use a new version
tag for a new publication.

Manual tag retries check out the full tag ref even if a branch has the same
name. Manual and tag-push publication share the same concurrency group. Before
publication, CI checks that the tag still points to the commit used for the APK.

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
publication, pushes to `main`, scheduled nightlies, and manual nightly publication. Partial secret configuration always fails.
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
git lfs pull
flutter pub get
dart run tool/verify_maia3.dart
flutter build apk --release --split-per-abi --target-platform android-arm64
dart run tool/verify_apk.dart build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify --verbose build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
"$ANDROID_HOME/build-tools/36.0.0/zipalign" -c -P 16 4 build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

The Dart content verifier requires Flutter libraries, ONNX Runtime, Stockfish,
exactly one Maia-3 model with the repository SHA-256, no legacy lc0/weights,
and ARM64 ELF LOAD segments aligned to at least 16 KB. CI fetches Git LFS and
runs the source-model verifier before building, then verifies the APK and its
signature and ZIP alignment. The verifier accepts only ARM64 APKs; emulator
builds must use the matching ABI.

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

Native Android acceptance is a publication gate alongside the verified ARM64
APK. The emulator's x86_64 ORT dependency is debug-only and is not distributed.
To rerun an older stable release, dispatch the workflow from that same tag so
its build/test configuration matches the source being released.
