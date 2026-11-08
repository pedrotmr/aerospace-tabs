#!/usr/bin/env python3
"""Create a Homebrew cask from a stable, published release artifact."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


MACOS_RELEASE = {
    11: "big_sur",
    12: "monterey",
    13: "ventura",
    14: "sonoma",
    15: "sequoia",
    26: "tahoe",
    27: "golden_gate",
}


def formatted_arguments(arguments: list[str]) -> list[str]:
    return [f"          {json.dumps(value)}," for value in arguments]


def format_preflight_arguments(arguments: list[str]) -> list[str]:
    return ["        args: [", *formatted_arguments(arguments), "        ]"]


def format_cask_step_arguments(arguments: list[str]) -> list[str]:
    return ["        args:           [", *formatted_arguments(arguments), "        ],"]


def minimum_macos_step(minimum_version: str) -> list[str]:
    parts = tuple(int(part) for part in minimum_version.split("."))
    if not any(parts[1:]):
        return []

    script = minimum_macos_script(minimum_version, "system version of (system info)")
    arguments = [item for line in script for item in ("-e", line)]
    lines = ["", "  preflight_steps do", '    run "/usr/bin/osascript",']
    lines.extend(format_preflight_arguments(arguments))
    lines.append("  end")
    return lines


def minimum_macos_script(minimum_version: str, current_version_expression: str) -> list[str]:
    version = json.dumps(minimum_version)
    message = json.dumps(f"Requires macOS {minimum_version} or later.")
    return [
        f"set osVersion to {current_version_expression}",
        "considering numeric strings",
        f"if osVersion < {version} then error {message} number 1",
        "end considering",
    ]


def read_xcconfig(path: Path) -> dict[str, str]:
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = re.sub(r"//.*$", "", line)
        match = re.match(r"^([A-Z0-9_]+)\s*=\s*(.*?)\s*$", line)
        if match:
            values[match.group(1)] = match.group(2)
    return values


def release_settings(root: Path) -> dict[str, str]:
    app = read_xcconfig(root / "Config" / "App.xcconfig")
    project = read_xcconfig(root / "Config" / "Project.xcconfig")
    settings = {
        "owner": app.get("RELEASE_OWNER", ""),
        "slug": app.get("RELEASE_SLUG", ""),
        "cask_token": app.get("HOMEBREW_CASK_TOKEN", ""),
        "bundle_id": app.get("PRODUCT_BUNDLE_IDENTIFIER", ""),
        "app_name": app.get("APP_EXECUTABLE_NAME", "") or app.get("PRODUCT_NAME", ""),
        "app_display_name": app.get("APP_DISPLAY_NAME", ""),
        "description": app.get("APP_DESCRIPTION", ""),
        "min_macos": project.get("MACOSX_DEPLOYMENT_TARGET", ""),
        "sparkle": app.get("SPARKLE_ENABLED", "NO").upper() == "YES",
    }
    if not all(settings[key] for key in settings if key != "sparkle"):
        raise SystemExit("error: Homebrew release metadata is incomplete in Config/*.xcconfig")
    if any("$(" in value for value in settings.values() if isinstance(value, str)):
        raise SystemExit("error: Homebrew release metadata must not contain xcconfig variable references")
    return settings


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config-root", type=Path)
    parser.add_argument("--print-homebrew-settings", action="store_true")
    parser.add_argument("--tap-dir", type=Path)
    parser.add_argument("--version")
    parser.add_argument("--sha256")
    args = parser.parse_args()
    settings = release_settings(args.config_root or Path(__file__).resolve().parents[1])
    if args.print_homebrew_settings:
        print(json.dumps(settings))
        return
    if not args.tap_dir or not args.version or not args.sha256:
        parser.error("--tap-dir, --version, and --sha256 are required unless --print-homebrew-settings is used")

    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        raise SystemExit("error: version must be MAJOR.MINOR.PATCH")
    if not re.fullmatch(r"[0-9a-f]{64}", args.sha256):
        raise SystemExit("error: SHA-256 must be 64 lowercase hex characters")
    if not re.fullmatch(r"\d+(?:\.\d+){0,2}", settings["min_macos"]):
        raise SystemExit("error: minimum macOS version must be numeric")
    major = int(settings["min_macos"].split(".", 1)[0])
    release = MACOS_RELEASE.get(major)
    if release is None:
        raise SystemExit(f"error: add a Homebrew macOS symbol for version {major} before using this module")

    description = settings["description"].strip()
    if description.endswith(".") and not description.endswith("etc."):
        description = description.rstrip(".")
    if not description:
        raise SystemExit("error: description must not be empty")

    url = f"https://github.com/{settings['owner']}/{settings['slug']}/releases/download/v#{{version}}/{settings['app_name']}-#{{version}}.zip"
    lines = [
        f'cask "{settings["cask_token"]}" do',
        f'  version "{args.version}"',
        f'  sha256 "{args.sha256}"',
        "",
        f'  url {json.dumps(url)}',
        f'  name {json.dumps(settings["app_display_name"])}',
        f'  desc {json.dumps(description)}',
        f'  homepage "https://github.com/{settings["owner"]}/{settings["slug"]}"',
        "",
    ]
    if settings["sparkle"]:
        lines.extend([
            "  livecheck do",
            f'    url "https://github.com/{settings["owner"]}/{settings["slug"]}/releases/latest/download/appcast.xml"',
            "    strategy :sparkle, &:short_version",
            "  end",
            "",
            "  auto_updates true",
        ])
    lines.extend([
        f"  depends_on macos: :{release}",
        "",
        f'  app "{settings["app_name"]}.app"',
    ])
    lines.extend(minimum_macos_step(settings["min_macos"]))
    if settings["sparkle"]:
        lines.extend(["", "  postflight_steps do"])
        for arguments in (
            ["write", f"{settings['bundle_id']}.homebrew", "managedByHomebrew", "-bool", "true"],
            ["write", f"{settings['bundle_id']}.homebrew", "managedByHomebrewVersion", "-string", args.version],
            [
                "write",
                f"{settings['bundle_id']}.homebrew",
                "managedByHomebrewBundlePath",
                "-string",
                f"{{{{appdir}}}}/{settings['app_name']}.app",
            ],
        ):
            lines.append('    run "/usr/bin/defaults",')
            lines.extend(format_cask_step_arguments(arguments))
            lines.extend(['        writable_paths: ["Library/Preferences"],', "        writable_base:  :home"])
        lines.extend(["  end", "", "  uninstall_postflight_steps do"])
        for key in ("managedByHomebrew", "managedByHomebrewBundlePath", "managedByHomebrewVersion"):
            lines.append('    run "/usr/bin/defaults",')
            lines.extend(format_cask_step_arguments(["delete", f"{settings['bundle_id']}.homebrew", key]))
            lines.extend([
                "        must_succeed:   false,",
                '        writable_paths: ["Library/Preferences"],',
                "        writable_base:  :home",
            ])
        lines.append("  end")
    lines.extend(["end", ""])

    cask_dir = args.tap_dir / "Casks"
    cask_dir.mkdir(parents=True, exist_ok=True)
    path = cask_dir / f"{settings['cask_token']}.rb"
    if path.exists():
        current = path.read_text(encoding="utf-8")
        current_version = re.search(r'^  version "([^\"]+)"$', current, re.MULTILINE)
        current_sha = re.search(r'^  sha256 "([0-9a-f]{64})"$', current, re.MULTILINE)
        if current_version and current_sha:
            old_parts = tuple(int(part) for part in current_version.group(1).split("."))
            new_parts = tuple(int(part) for part in args.version.split("."))
            if old_parts > new_parts:
                print(f"Skipped old release {args.version}; the tap already has {current_version.group(1)}")
                return
            if old_parts == new_parts and current_sha.group(1) != args.sha256:
                raise SystemExit("error: this version already has a different SHA-256 in the tap")
    path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {path}")


if __name__ == "__main__":
    main()
