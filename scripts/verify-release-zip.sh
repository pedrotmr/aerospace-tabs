#!/usr/bin/env bash
set -euo pipefail

archive=${1:?Usage: verify-release-zip.sh <release-zip> <release-tag>}
tag=${2:?Usage: verify-release-zip.sh <release-zip> <release-tag>}
[[ -s "$archive" ]] || { echo "error: release ZIP is missing or empty." >&2; exit 1; }
[[ "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  echo "error: release tag must use vMAJOR.MINOR.PATCH." >&2
  exit 1
}

setting() {
  local file=$1 key=$2
  sed -n "s/^${key} = //p" "$file" | head -n 1
}

app_name=$(setting Config/App.xcconfig APP_EXECUTABLE_NAME)
if [[ -z "$app_name" ]]; then app_name=$(setting Config/App.xcconfig PRODUCT_NAME); fi
bundle_id=$(setting Config/App.xcconfig PRODUCT_BUNDLE_IDENTIFIER)
owner=$(setting Config/App.xcconfig RELEASE_OWNER)
slug=$(setting Config/App.xcconfig RELEASE_SLUG)
min_macos=$(setting Config/Project.xcconfig MACOSX_DEPLOYMENT_TARGET)
expected_team=$(setting Config/Project.xcconfig DEVELOPMENT_TEAM)
sparkle_enabled=$(setting Config/App.xcconfig SPARKLE_ENABLED)
expected_feed_template=$(setting Config/App.xcconfig SPARKLE_FEED_URL)
expected_public_key=$(setting Config/App.xcconfig SPARKLE_PUBLIC_ED_KEY)
sparkle_keychain_account=$(setting Config/App.xcconfig RELEASE_SLUG)
expected_version=${tag#v}
expected_feed=$(printf '%s\n' "$expected_feed_template" \
  | sed -e 's|/[$][(][)]/|//|g' \
        -e "s|[$][(]RELEASE_OWNER[)]|$owner|g" \
        -e "s|[$][(]RELEASE_SLUG[)]|$slug|g")
[[ -n "$app_name" && -n "$bundle_id" && -n "$owner" && -n "$slug" && -n "$min_macos" && -n "$expected_team" ]] || {
  echo "error: app release settings are incomplete." >&2
  exit 1
}
[[ "$sparkle_enabled" == YES && -n "$expected_feed" && -n "$expected_public_key" ]] || {
  echo "error: Sparkle must be enabled with a feed and public key in Config/App.xcconfig." >&2
  exit 1
}
unresolved_xcode_setting="\$("
[[ "$expected_feed" != *"$unresolved_xcode_setting"* ]] || { echo "error: Sparkle feed URL has an unresolved Xcode setting." >&2; exit 1; }

temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/release-zip-check.XXXXXX")
trap 'rm -rf "$temporary_dir"' EXIT
ditto -x -k "$archive" "$temporary_dir"
app="$temporary_dir/$app_name.app"
plist="$app/Contents/Info.plist"
[[ -d "$app" && -f "$plist" ]] || { echo "error: ZIP does not contain $app_name.app at its root." >&2; exit 1; }

actual_bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")
actual_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
actual_min_macos=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")
[[ "$actual_bundle_id" == "$bundle_id" ]] || { echo "error: app bundle ID does not match Config/App.xcconfig." >&2; exit 1; }
[[ "$actual_version" == "$expected_version" ]] || { echo "error: app version does not match release tag $tag." >&2; exit 1; }
[[ "$actual_min_macos" == "$min_macos" ]] || { echo "error: app minimum macOS version does not match Config/Project.xcconfig." >&2; exit 1; }
[[ "$build_version" =~ ^[0-9]+$ ]] || { echo "error: app build version is not numeric." >&2; exit 1; }

resources="$app/Contents/Resources"
if [[ ! -s "$resources/Assets.car" ]] && ! find "$resources" -maxdepth 1 -type f -name '*.icns' -print -quit | grep -q .; then
  echo "error: app bundle has no compiled icon or ICNS file." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$app"
signature=$(codesign --display --verbose=4 "$app" 2>&1)
[[ "$signature" == *'Authority=Developer ID Application:'* ]] || { echo "error: app is not signed with Developer ID Application." >&2; exit 1; }
[[ "$signature" == *'Timestamp='* ]] || { echo "error: app signature has no secure timestamp." >&2; exit 1; }
[[ "$signature" == *'(runtime)'* ]] || { echo "error: app signature does not enable hardened runtime." >&2; exit 1; }
[[ "$signature" == *'TeamIdentifier='* ]] || { echo "error: app signature has no team identifier." >&2; exit 1; }
team_id=$(sed -n 's/^TeamIdentifier=//p' <<< "$signature" | head -n 1)
[[ "$team_id" == "$expected_team" ]] || { echo "error: app signature team does not match Config/Project.xcconfig." >&2; exit 1; }
for architecture in arm64 x86_64; do lipo "$app/Contents/MacOS/$executable" -verify_arch "$architecture"; done

if [[ "$sparkle_enabled" == "YES" ]]; then
  framework="$app/Contents/Frameworks/Sparkle.framework"
  binary="$framework/Versions/B"
  feed_url=$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$plist")
  public_key=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$plist")
  [[ -x "$binary/Sparkle" && "$feed_url" == "$expected_feed" && "$public_key" == "$expected_public_key" ]] || {
    echo "error: Sparkle framework, feed, or public key is missing from the app bundle." >&2
    exit 1
  }
  for component in "$binary/Autoupdate" "$binary/Updater.app" "$framework"; do
    [[ -e "$component" ]] || { echo "error: Sparkle component is missing: ${component##*/}." >&2; exit 1; }
    codesign --verify --strict --verbose=2 "$component"
    component_signature=$(codesign --display --verbose=4 "$component" 2>&1)
    [[ "$component_signature" == *'Authority=Developer ID Application:'* && \
      "$component_signature" == *"TeamIdentifier=$team_id"* && \
      "$component_signature" == *'Timestamp='* && "$component_signature" == *'(runtime)'* ]] || {
      echo "error: Sparkle component has an incomplete Developer ID signature: ${component##*/}." >&2
      exit 1
    }
  done
  for executable_path in "$binary/Sparkle" "$binary/Autoupdate" "$binary/Updater.app/Contents/MacOS/Updater"; do
    for architecture in arm64 x86_64; do lipo "$executable_path" -verify_arch "$architecture"; done
  done
  appcast="$temporary_dir/appcast.xml"
  feed_to_check=${SPARKLE_FEED_URL_OVERRIDE:-$feed_url}
  curl --fail --silent --show-error --location "$feed_to_check" --output "$appcast"
  asset_url="https://github.com/$owner/$slug/releases/download/$tag/$app_name-$expected_version.zip"
  python3 - "$appcast" "$build_version" "$expected_version" "$asset_url" "$archive" <<'PY'
import os
import sys
import xml.etree.ElementTree as ET

feed_path, expected_build, expected_version, expected_url, archive_path = sys.argv[1:]
root = ET.parse(feed_path).getroot()
item = root.find(".//item")
if item is None:
    raise SystemExit("error: Sparkle feed has no update item")
values = {child.tag.split("}")[-1]: child.text or "" for child in item}
enclosure = item.find("enclosure")
if enclosure is None:
    raise SystemExit("error: Sparkle feed has no enclosure")
if values.get("version") != expected_build:
    raise SystemExit("error: Sparkle feed build version does not match the app")
if values.get("shortVersionString") != expected_version:
    raise SystemExit("error: Sparkle feed version does not match the release tag")
if enclosure.attrib.get("url") != expected_url:
    raise SystemExit("error: Sparkle feed URL does not match the versioned release ZIP")
if enclosure.attrib.get("length") != str(os.path.getsize(archive_path)):
    raise SystemExit("error: Sparkle feed ZIP size does not match the release ZIP")
signature = next((value for key, value in enclosure.attrib.items() if key.split("}")[-1] == "edSignature"), "")
if not signature:
    raise SystemExit("error: Sparkle feed enclosure has no EdDSA signature")
PY
  feed_signature=$(/usr/bin/xmllint --xpath 'string((//*[local-name()="item"])[1]/*[local-name()="enclosure"]/@*[local-name()="edSignature"])' "$appcast")
  [[ -n "$feed_signature" ]] || { echo "error: Sparkle feed has no EdDSA signature." >&2; exit 1; }
  sign_update=".build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
  [[ -x "$sign_update" ]] || { echo "error: Sparkle's sign_update tool is missing; run make bundle." >&2; exit 1; }
  if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    printf '%s' "$SPARKLE_PRIVATE_KEY" | "$sign_update" --verify --ed-key-file - "$archive" "$feed_signature"
  else
    "$sign_update" --account "$sparkle_keychain_account" --verify "$archive" "$feed_signature"
  fi
fi

xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
echo "Verified signed, notarized $app_name $expected_version for Homebrew."
