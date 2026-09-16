"""Prepare Gradle signing files without printing secrets."""
import base64
import os
from pathlib import Path

names = (
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
)
values = {name: os.environ.get(name, "") for name in names}
release = (os.environ.get("GITHUB_REF_TYPE") == "tag" or
           os.environ.get("REQUIRE_RELEASE_SIGNING") == "true")
if not any(values.values()) and not release:
    print("::warning::Sem secrets de assinatura: APK de teste, sem publicação de release.")
else:
    missing = [name for name, value in values.items() if not value]
    if missing:
        raise SystemExit("Secrets ausentes: " + ", ".join(missing))

    def escape(value):
        # java.util.Properties uses ISO-8859-1 and treats backslashes specially.
        return "".join(
            "\\\\" if c == "\\" else
            "\\n" if c == "\n" else
            "\\r" if c == "\r" else
            "\\t" if c == "\t" else
            "\\ " if c == " " else
            c if 32 <= ord(c) <= 126 else
            "".join("\\u%04x" % int.from_bytes(unit, "big") for unit in
                    (c.encode("utf-16-be")[i:i + 2] for i in range(0, len(c.encode("utf-16-be")), 2)))
            for c in value
        )

    os.umask(0o077)
    root = Path("android/app")
    root.joinpath("ci-release.jks").write_bytes(
        base64.b64decode(values[names[0]], validate=True)
    )
    properties = {
        "storeFile": "ci-release.jks",
        "storePassword": values[names[1]],
        "keyAlias": values[names[2]],
        "keyPassword": values[names[3]],
    }
    root.joinpath("key.properties").write_text(
        "".join(f"{key}={escape(value)}\n" for key, value in properties.items()),
        encoding="ascii",
    )
    print("Assinatura release configurada.")
