#!/usr/bin/env bash
set -euo pipefail

project=${1:?Usage: setup.sh <project> <scheme>}
scheme=${2:?Usage: setup.sh <project> <scheme>}
xcodebuild_cmd=${XCODEBUILD:-xcodebuild}
repo_root=$(cd "$(dirname "$0")/.." && pwd)

if [[ ! -f "$repo_root/.env" ]]; then
  cp "$repo_root/.env.example" "$repo_root/.env"
fi
chmod 600 "$repo_root/.env"

"$repo_root/scripts/check-version-config.sh"

if ! command -v "$xcodebuild_cmd" >/dev/null 2>&1; then
  minimum_xcode=$(sed -n 's/^MINIMUM_XCODE_VERSION = //p' "$repo_root/Config/Project.xcconfig")
  printf 'error: Xcode %s or newer is required. Install Xcode and select it with xcode-select.\n' "${minimum_xcode:-the configured minimum}" >&2
  exit 1
fi

version_output=$("$xcodebuild_cmd" -version 2>/dev/null || true)
xcode_version=$(awk '/^Xcode / { print $2 }' <<< "$version_output")
minimum_xcode=$(sed -n 's/^MINIMUM_XCODE_VERSION = //p' "$repo_root/Config/Project.xcconfig")
major=${xcode_version%%.*}
minor=${xcode_version#*.}
minor=${minor%%.*}
minimum_major=${minimum_xcode%%.*}
minimum_minor=${minimum_xcode#*.}
minimum_minor=${minimum_minor%%.*}
if [[ ! "$minimum_xcode" =~ ^[0-9]+\.[0-9]+$ || ! "$major" =~ ^[0-9]+$ || ! "$minor" =~ ^[0-9]+$ ]] || (( major < minimum_major || (major == minimum_major && minor < minimum_minor) )); then
  printf 'error: Xcode %s or newer is required; selected version is %s.\n' "${minimum_xcode:-unknown}" "${xcode_version:-unknown}" >&2
  exit 1
fi

"$xcodebuild_cmd" -resolvePackageDependencies -project "$project" -scheme "$scheme" \
  -derivedDataPath "$repo_root/.build/DerivedData"
