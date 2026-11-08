import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "update-cask.py"
SPEC = importlib.util.spec_from_file_location("update_cask", SCRIPT)
UPDATE_CASK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(UPDATE_CASK)


class UpdateCaskTests(unittest.TestCase):
    def test_xcconfig_reader_ignores_inline_comments(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "App.xcconfig"
            path.write_text(
                "APP_DESCRIPTION = Window tabs // cask description\n"
                "HOMEBREW_CASK_TOKEN = example-tabs // cask file name\n"
                "SPARKLE_ENABLED = YES// optional update module\n",
                encoding="utf-8",
            )

            values = UPDATE_CASK.read_xcconfig(path)

        self.assertEqual(values["APP_DESCRIPTION"], "Window tabs")
        self.assertEqual(values["HOMEBREW_CASK_TOKEN"], "example-tabs")
        self.assertEqual(values["SPARKLE_ENABLED"], "YES")

    def test_generated_macos_version_check_rejects_older_os(self):
        for current_version, accepted in (("14.5", False), ("14.6", True), ("15.0", True)):
            with self.subTest(current_version=current_version):
                script = UPDATE_CASK.minimum_macos_script("14.6", f'"{current_version}"')
                command = ["/usr/bin/osascript"]
                for line in script:
                    command.extend(["-e", line])
                result = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode == 0, accepted, result.stderr)

    def test_generated_cask_tracks_and_clears_homebrew_install_state(self):
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
                ],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            cask = (tap_dir / "Casks" / "pedrotmr-aerospace-tabs.rb").read_text()

        self.assertIn('cask "pedrotmr-aerospace-tabs" do', cask)
        self.assertIn('desc "Window tabs and overview for AeroSpace"', cask)
        self.assertIn('app "AerospaceTabs.app"', cask)
        self.assertIn("livecheck do", cask)
        self.assertIn("auto_updates true", cask)
        postflight = cask.split("  postflight_steps do", 1)[1].split("  uninstall_postflight_steps do", 1)[0]
        self.assertIn('"write",\n          "com.pedrotmr.AerospaceTabs.homebrew",\n          "managedByHomebrewVersion",\n          "-string",\n          "1.2.3",', postflight)
        self.assertIn("managedByHomebrewBundlePath", cask)
        self.assertIn("com.pedrotmr.AerospaceTabs.homebrew", cask)
        self.assertIn("1.2.3", cask)
        self.assertIn('"delete"', cask)

    def test_release_settings_reject_xcconfig_variable_references(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            (root / "Config").mkdir()
            (root / "Config" / "App.xcconfig").write_text(
                "RELEASE_OWNER = pedrotmr\nRELEASE_SLUG = aerospace-tabs\n"
                "HOMEBREW_CASK_TOKEN = demo-tabs\nPRODUCT_BUNDLE_IDENTIFIER = com.example.demo\n"
                "PRODUCT_NAME = $(APP_PREFIX).App\nAPP_DISPLAY_NAME = Demo\n"
                "APP_DESCRIPTION = Demo app\nSPARKLE_ENABLED = NO\n",
                encoding="utf-8",
            )
            (root / "Config" / "Project.xcconfig").write_text("MACOSX_DEPLOYMENT_TARGET = 14.0\n", encoding="utf-8")

            with self.assertRaisesRegex(SystemExit, "variable references"):
                UPDATE_CASK.release_settings(root)


if __name__ == "__main__":
    unittest.main()
