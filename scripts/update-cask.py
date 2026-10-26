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
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tap-dir", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--owner", required=True)
    parser.add_argument("--slug", required=True)
    parser.add_argument("--cask-token", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--app-name", required=True)
    parser.add_argument("--app-display-name", required=True)
    parser.add_argument("--description", required=True)
    parser.add_argument("--min-macos", required=True)
    parser.add_argument("--sparkle", choices=("yes", "no"), required=True)
    args = parser.parse_args()

    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        raise SystemExit("error: version must be MAJOR.MINOR.PATCH")
    if not re.fullmatch(r"[0-9a-f]{64}", args.sha256):
        raise SystemExit("error: SHA-256 must be 64 lowercase hex characters")
    major = int(args.min_macos.split(".", 1)[0])
    release = MACOS_RELEASE.get(major)
    if release is None:
        raise SystemExit(f"error: add a Homebrew macOS symbol for version {major} before using this module")

    url = f"https://github.com/{args.owner}/{args.slug}/releases/download/v#{{version}}/{args.app_name}-#{{version}}.zip"
    lines = [
        f'cask "{args.cask_token}" do',
        f'  version "{args.version}"',
        f'  sha256 "{args.sha256}"',
        "",
        f'  url {json.dumps(url)},',
        f'      verified: "github.com/{args.owner}/{args.slug}/"',
        f'  name {json.dumps(args.app_display_name)}',
        f'  desc {json.dumps(args.description)}',
        f'  homepage "https://github.com/{args.owner}/{args.slug}"',
        "",
    ]
    if args.sparkle == "yes":
        lines.extend([
            "  livecheck do",
            f'    url "https://github.com/{args.owner}/{args.slug}/releases/latest/download/appcast.xml"',
            "    strategy :sparkle, &:short_version",
            "  end",
            "",
            "  auto_updates true",
        ])
    lines.extend([
        f"  depends_on macos: :{release}",
        "",
        f'  app "{args.app_name}.app"',
    ])
    if args.sparkle == "yes":
        lines.extend([
            "",
            "  postflight_steps do",
            '    run "/usr/bin/defaults",',
            f'        args:           ["write", "{args.bundle_id}.homebrew", "managedByHomebrew", "-bool", "true"],',
            '        writable_paths: ["Library/Preferences"],',
            "        writable_base:  :home",
            "  end",
            "",
            "  uninstall_postflight_steps do",
            '    run "/usr/bin/defaults",',
            f'        args:           ["delete", "{args.bundle_id}.homebrew", "managedByHomebrew"],',
            "        must_succeed:   false,",
            '        writable_paths: ["Library/Preferences"],',
            "        writable_base:  :home",
            "  end",
        ])
    lines.extend(["end", ""])

    cask_dir = args.tap_dir / "Casks"
    cask_dir.mkdir(parents=True, exist_ok=True)
    path = cask_dir / f"{args.cask_token}.rb"
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
