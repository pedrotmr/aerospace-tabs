import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "update-cask.py"


class UpdateCaskTests(unittest.TestCase):
    def test_minor_version_preflight_rejects_older_macos(self):
        for current_version, accepted in (("14.5", False), ("14.6", True), ("15.0", True)):
            with self.subTest(current_version=current_version):
                result = subprocess.run(
                    [
                        "/usr/bin/osascript",
                        "-e",
                        f'set osVersion to "{current_version}"',
                        "-e",
                        "considering numeric strings",
                        "-e",
                        'if osVersion < "14.6" then error "Requires macOS 14.6 or later." number 1',
                        "-e",
                        "end considering",
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode == 0, accepted, result.stderr)

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
                    "Manage demo workspaces...",
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

        self.assertIn('"managedByHomebrewVersion",\n          "-string",\n          "1.2.3"', cask)
        self.assertIn(
            '"delete",\n          "com.example.Demo.homebrew",\n          "managedByHomebrewVersion"',
            cask,
        )
        self.assertIn('desc "Manage demo workspaces"', cask)
        self.assertNotIn("verified:", cask)
        self.assertIn("preflight_steps do", cask)
        self.assertIn('if osVersion < \\"14.6\\" then error', cask)
        self.assertIn('"managedByHomebrewBundlePath",\n          "-string",\n          "{{appdir}}/Demo.app"', cask)
        self.assertNotIn("#{appdir}", cask)
        self.assertIn(
            '"delete",\n          "com.example.Demo.homebrew",\n          "managedByHomebrewBundlePath"',
            cask,
        )


if __name__ == "__main__":
    unittest.main()
