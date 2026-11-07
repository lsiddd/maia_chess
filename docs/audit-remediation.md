# Audit remediation — 2026-11-07

The audit baseline is c4e15a0 (1.2.0). Regression tests cover:

- Retrying a failed autosave before restoring an older database snapshot; a
  failed retry preserves the in-memory moves, and a saved resignation cannot
  become an ongoing game again.
- Pausing the human clock until the AI reply has finished saving and the board
  accepts input; restarting the clock only after that barrier.
- Starting local chess while cancelled native initialization drains. Shutdown
  remains tracked, so subsequent AI sessions cannot overlap native resources.
  AI initialization and waiting for previous shutdown have a 30-second limit.
- Reading game totals and rating history in one SQLite read transaction.
- Importing adjacent NAGs, spaced move numbers and percent escape lines.
- Updating the open move-history panel when the live game advances.

Ongoing autosaves retain structured moves and clock values, without repeatedly
building PGN. Explicit export already falls back to generating PGN from those
moves. Completed games still persist PGN, including termination metadata.

Widget tests inject an in-memory settings repository instead of opening the
production database. The migration test runs in its own suite without an unrelated fixture
database. Drift warnings are not suppressed.
Android lint now runs after the production APK build in CI. The redundant v21
launch resource was removed and a dedicated alpha-only king drawable supports
themed launcher icons.

## Deliberate limits

No database schema, stored enum, signing identity, bundled model or native
inference implementation changes. No physical-device data is cleared or used
as a test fixture. Engine tests inject delays and failures; they do not establish
that a hung native call can be forcibly interrupted. A stuck native shutdown
remains tracked to prevent unsafe concurrent sessions, while local chess stays
available.

The audit's memory sample (about 737 MiB PSS) and 439.7 MB APK are baseline
observations, not evidence of a leak. Reducing model/native weight requires
separate parity and device performance evidence. Library hydration, synchronous
replay of very large imports, full derived-state rebuilding and controller
responsibility splitting remain scalability/architecture work, not resolved by
these fixes.

Dependency updates are not security fixes merely because newer versions exist.
The pinned Gradle/AGP/Kotlin versions still build, but Flutter emits future-support
warnings. A coordinated toolchain migration and Android integration automation
remain outstanding; the new lint job does not replace device tests. The manifest
back-callback attribute is intentionally ignored below API 33.
