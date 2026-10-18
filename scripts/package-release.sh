#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <existing-version-tag>\n' "${0##*/}" >&2
  exit 2
fi

release_tag=$1
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

if [[ ! "$release_tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  printf 'Release tag must use vMAJOR.MINOR.PATCH format (for example, v0.1.0).\n' >&2
  exit 2
fi
release_version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"

build_number=${GITHUB_RUN_NUMBER:-1}
if [[ ! "$build_number" =~ ^[0-9]+$ ]]; then
  printf 'Invalid build number: %s\n' "$build_number" >&2
  exit 2
fi

if ! git tag --points-at HEAD | grep -Fqx "$release_tag"; then
  printf 'HEAD must be checked out at the existing %s tag.\n' "$release_tag" >&2
  exit 1
fi

make build SIGNING_IDENTITY=- APP_VERSION="$release_version" BUILD_NUMBER="$build_number"

archive_path="$repo_root/.build/AerospaceTabs.zip"
rm -f "$archive_path"
ditto -c -k --sequesterRsrc --keepParent "$repo_root/AerospaceTabs.app" "$archive_path"
printf 'Created %s\n' "$archive_path"
