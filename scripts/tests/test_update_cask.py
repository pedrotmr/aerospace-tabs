import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "update-cask.py"


class UpdateCaskTests(unittest.TestCase):
    def test_sparkle_cask_writes_and_removes_homebrew_version_marker(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            tap_dir = Path(temporary_directory)
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--tap-dir",
                    str(tap_dir),
                    "--version",
                    "1.2.3",
                    "--sha256",
                    "a" * 64,
                    "--owner",
                    "example",
                    "--slug",
                    "demo-app",
                    "--cask-token",
                    "demo-app",
                    "--bundle-id",
                    "com.example.Demo",
                    "--app-name",
                    "Demo",
                    "--app-display-name",
                    "Demo",
                    "--description",
                    "A demo app.",
                    "--min-macos",
                    "14.6",
                    "--sparkle",
                    "yes",
                ],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            cask = (tap_dir / "Casks" / "demo-app.rb").read_text()

        self.assertIn('"managedByHomebrewVersion", "-string", "1.2.3"', cask)
        self.assertIn('"delete", "com.example.Demo.homebrew", "managedByHomebrewVersion"', cask)
        self.assertIn('"managedByHomebrewBundlePath", "-string", "#{appdir}/Demo.app"', cask)
        self.assertIn('"delete", "com.example.Demo.homebrew", "managedByHomebrewBundlePath"', cask)


if __name__ == "__main__":
    unittest.main()
