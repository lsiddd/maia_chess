"""Check that the distributable contains the engines and all Maia weights."""
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as apk:
    names = set(apk.namelist())
    if any(name.startswith("lib/") and not name.startswith("lib/arm64-v8a/")
           for name in names if not name.endswith("/")):
        raise SystemExit("ARM64 APK contains libraries for another architecture")
    required = {
        f"assets/flutter_assets/assets/maia_weights/maia-{rating}.pb.gz"
        for rating in range(1100, 2000, 100)
    }
    required.update({"lib/arm64-v8a/libapp.so", "lib/arm64-v8a/libflutter.so"})
    missing = required - names
    if missing:
        raise SystemExit("Missing files: " + ", ".join(sorted(missing)))
    duplicated_weights = (
        "assets/flutter_assets/packages/leela_chess_zero/"
        "assets/weights/maia-1900.pb.gz"
    )
    if duplicated_weights in names:
        raise SystemExit("Maia 1900 weights duplicated by the lc0 plugin")
    for engine in ("lc0", "stockfish"):
        if not any(name.startswith("lib/arm64-v8a/") and engine in name.lower()
                   and name.endswith(".so") for name in names):
            raise SystemExit(f"Missing native engine: {engine}")
    if apk.testzip() is not None:
        raise SystemExit("APK contains a corrupted file")
print("ARM64 APK verified: Flutter, lc0, Stockfish, and all nine Maia networks.")
