#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <existing-tag>\n' "${0##*/}" >&2
  exit 2
fi

release_tag=$1
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

if ! git check-ref-format "refs/tags/$release_tag" >/dev/null; then
  printf 'Invalid release tag: %s\n' "$release_tag" >&2
  exit 2
fi

if ! git tag --points-at HEAD | grep -Fqx "$release_tag"; then
  printf 'HEAD must be checked out at the existing %s tag.\n' "$release_tag" >&2
  exit 1
fi

make build SIGNING_IDENTITY=-

archive_path="$repo_root/.build/AerospaceTabs.zip"
rm -f "$archive_path"
ditto -c -k --sequesterRsrc --keepParent "$repo_root/AerospaceTabs.app" "$archive_path"
printf 'Created %s\n' "$archive_path"
