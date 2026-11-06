import base64
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent
SECRET_NAMES = (
    "ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD",
)


class SigningTests(unittest.TestCase):
    def run_signing(self, root, **values):
        env = {k: v for k, v in os.environ.items() if k not in SECRET_NAMES}
        env["GITHUB_REF_TYPE"] = "branch"
        env.update(values)
        return subprocess.run(
            [sys.executable, str(SCRIPTS / "configure_android_signing.py")],
            cwd=root, env=env, capture_output=True, text=True,
        )

    def test_preview_without_secrets(self):
        with tempfile.TemporaryDirectory() as root:
            result = self.run_signing(root)
            self.assertEqual(result.returncode, 0)
            self.assertIn("test APK", result.stdout)
            self.assertFalse(Path(root, "android/app/key.properties").exists())

    def test_tag_requires_secrets(self):
        with tempfile.TemporaryDirectory() as root:
            result = self.run_signing(root, GITHUB_REF_TYPE="tag")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Missing secrets", result.stderr)

    def test_nightly_requires_secrets(self):
        with tempfile.TemporaryDirectory() as root:
            result = self.run_signing(root, REQUIRE_RELEASE_SIGNING="true")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Missing secrets", result.stderr)
            self.assertFalse(Path(root, "android/app/key.properties").exists())

    def test_partial_configuration_fails(self):
        with tempfile.TemporaryDirectory() as root:
            result = self.run_signing(root, ANDROID_KEY_ALIAS="maia")
            self.assertNotEqual(result.returncode, 0)

    def test_writes_private_files_without_logging_password(self):
        with tempfile.TemporaryDirectory() as root:
            app = Path(root, "android/app")
            app.mkdir(parents=True)
            password = " test\\key\nç"
            result = self.run_signing(root, **dict(zip(SECRET_NAMES, (
                base64.b64encode(b"test-keystore").decode(), password, "maia", password,
            ))))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((app / "ci-release.jks").read_bytes(), b"test-keystore")
            self.assertIn(r"storePassword=\ test\\key\n\u00e7", (app / "key.properties").read_text())
            self.assertEqual((app / "ci-release.jks").stat().st_mode & 0o777, 0o600)
            self.assertNotIn(password, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
