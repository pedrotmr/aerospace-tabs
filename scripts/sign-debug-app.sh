#!/usr/bin/env bash
set -euo pipefail

app_path=${1:?usage: sign-debug-app.sh APP_PATH IDENTITY}
identity=${2:?usage: sign-debug-app.sh APP_PATH IDENTITY}
framework="$app_path/Contents/Frameworks/Sparkle.framework"
sparkle_version="$framework/Versions/B"

if [[ ! -d "$framework" ]]; then
  echo "error: required Sparkle.framework is missing from $app_path" >&2
  exit 1
fi

# The app is not sandboxed, so Sparkle's XPC services are not used. Remove
# them before signing, matching the release signing flow.
rm -rf "$framework/XPCServices" "$sparkle_version/XPCServices"

for component in \
  "$sparkle_version/Autoupdate" \
  "$sparkle_version/Updater.app" \
  "$framework" \
  "$app_path"; do
  if [[ ! -e "$component" ]]; then
    echo "error: required signing component is missing: $component" >&2
    exit 1
  fi
  codesign --force --options runtime --timestamp=none --sign "$identity" "$component"
done

codesign --verify --deep --strict "$app_path"
