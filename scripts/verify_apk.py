"""Check that the distributable contains the engines and all Maia weights."""
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as apk:
    names = set(apk.namelist())
    if any(name.startswith("lib/") and not name.startswith("lib/arm64-v8a/")
           for name in names if not name.endswith("/")):
        raise SystemExit("APK ARM64 contém bibliotecas de outra arquitetura")
    required = {
        f"assets/flutter_assets/assets/maia_weights/maia-{rating}.pb.gz"
        for rating in range(1100, 2000, 100)
    }
    required.update({"lib/arm64-v8a/libapp.so", "lib/arm64-v8a/libflutter.so"})
    missing = required - names
    if missing:
        raise SystemExit("Arquivos ausentes: " + ", ".join(sorted(missing)))
    for engine in ("lc0", "stockfish"):
        if not any(name.startswith("lib/arm64-v8a/") and engine in name.lower()
                   and name.endswith(".so") for name in names):
            raise SystemExit(f"Motor nativo ausente: {engine}")
    if apk.testzip() is not None:
        raise SystemExit("APK contém arquivo corrompido")
print("APK ARM64 verificado: Flutter, lc0, Stockfish e nove pesos Maia.")
