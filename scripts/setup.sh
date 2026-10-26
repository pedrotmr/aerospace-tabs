#!/usr/bin/env bash
set -euo pipefail

project=${1:?Usage: setup.sh <project> <scheme>}
scheme=${2:?Usage: setup.sh <project> <scheme>}
xcodebuild_cmd=${XCODEBUILD:-xcodebuild}
repo_root=$(cd "$(dirname "$0")/.." && pwd)

"$repo_root/scripts/check-version-config.sh"

if ! command -v "$xcodebuild_cmd" >/dev/null 2>&1; then
  printf 'error: Xcode 27.1 or newer is required. Install Xcode and select it with xcode-select.\n' >&2
  exit 1
fi

xcode_version=$("$xcodebuild_cmd" -version | awk '/^Xcode / { print $2 }')
major=${xcode_version%%.*}
minor=${xcode_version#*.}
minor=${minor%%.*}
if [[ ! "$major" =~ ^[0-9]+$ || ! "$minor" =~ ^[0-9]+$ ]] || (( major < 27 || (major == 27 && minor < 1) )); then
  printf 'error: Xcode 27.1 or newer is required; selected version is %s.\n' "${xcode_version:-unknown}" >&2
  exit 1
fi

"$xcodebuild_cmd" -resolvePackageDependencies -project "$project" -scheme "$scheme"
