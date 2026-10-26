#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
manifest_version=$(awk -F '"' '$2 == "." { print $4; exit }' "$repo_root/.release-please-manifest.json")
app_version=$(sed -n 's/^APP_MARKETING_VERSION = //p' "$repo_root/Config/App.xcconfig")

if [[ -z "$manifest_version" || ! "$manifest_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'error: Release Please manifest does not contain a stable semantic version.\n' >&2
  exit 1
fi
if [[ "$manifest_version" != "$app_version" ]]; then
  printf 'error: Release Please version (%s) and Config/App.xcconfig version (%s) differ.\n' \
    "$manifest_version" "${app_version:-missing}" >&2
  exit 1
fi

printf 'Version configuration is synchronized: %s\n' "$app_version"
