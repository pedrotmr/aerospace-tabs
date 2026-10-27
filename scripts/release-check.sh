#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

# Read only the release allowlist from the ignored .env file. Other local app
# credentials must not leak into the Xcode build or notarization process.
load_local_release_config() {
  local line key value
  [[ -f .env ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || continue
    key=${line%%=*}
    case "$key" in
      APPLE_NOTARY_KEY_P8_BASE64|APPLE_NOTARY_KEY_ID|APPLE_NOTARY_ISSUER_ID|SPARKLE_PRIVATE_KEY|CODESIGN_IDENTITY) ;;
      *) continue ;;
    esac
    [[ -z "${!key:-}" ]] || continue
    value=${line#*=}
    [[ -n "$value" ]] || continue
    export "$key=$value"
  done < .env
}
load_local_release_config
export -n APPLE_NOTARY_KEY_P8_BASE64 SPARKLE_PRIVATE_KEY

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_value() {
  local name=$1
  [[ -n "${!name:-}" ]] || fail "Required release configuration is missing: $name"
}

for name in APP_PROJECT APP_SCHEME APP_NAME APP_BUNDLE_ID APP_MIN_SYSTEM_VERSION APP_VERSION APP_BUILD_NUMBER RELEASE_OWNER RELEASE_SLUG SPARKLE_KEYCHAIN_ACCOUNT; do
  require_value "$name"
done
for name in APPLE_NOTARY_KEY_P8_BASE64 APPLE_NOTARY_KEY_ID APPLE_NOTARY_ISSUER_ID; do
  require_value "$name"
done
if [[ "${CI:-}" == true ]]; then
  require_value SPARKLE_PRIVATE_KEY
fi

[[ "$APP_BUILD_NUMBER" =~ ^[0-9]+$ ]] || fail "APP_BUILD_NUMBER must be a positive integer."
(( APP_BUILD_NUMBER > 0 )) || fail "APP_BUILD_NUMBER must be a positive integer."
command -v jq >/dev/null || fail "Install jq to run release-check."

identity=${CODESIGN_IDENTITY:-}
if [[ -z "$identity" ]]; then
  identity=$(security find-identity -v -p codesigning 2>/dev/null | awk '/Developer ID Application:/ { print $2; exit }')
fi
[[ -n "$identity" ]] || fail "Install a Developer ID Application certificate or set CODESIGN_IDENTITY."
[[ "$identity" != "-" ]] || fail "Ad-hoc signing is not valid for a release check."

derived_data="$repo_root/.build/DerivedData"
release_dir="$repo_root/.build/release"
app_path="$derived_data/Build/Products/Release/$APP_NAME.app"
framework_bin="$derived_data/SourcePackages/artifacts/sparkle/Sparkle/bin"
generate_appcast="$framework_bin/generate_appcast"
sign_update="$framework_bin/sign_update"

rm -rf "$release_dir"
mkdir -p "$release_dir"
xcodebuild build \
  -project "$APP_PROJECT" \
  -scheme "$APP_SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_data" \
  APP_MARKETING_VERSION="$APP_VERSION" \
  APP_BUILD_NUMBER="$APP_BUILD_NUMBER" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO

APP_BUNDLE_ID="$APP_BUNDLE_ID" \
APP_VERSION="$APP_VERSION" \
APP_BUILD_NUMBER="$APP_BUILD_NUMBER" \
APP_MIN_SYSTEM_VERSION="$APP_MIN_SYSTEM_VERSION" \
  "$repo_root/scripts/check-app-bundle.sh" "$app_path"

# Xcode downloads binary package artifacts during the build, not package
# resolution. Check for Sparkle's release tools only after this build.
[[ -x "$generate_appcast" && -x "$sign_update" ]] || fail "Sparkle release tools are missing after the build. Check the resolved Sparkle package artifact."

framework="$app_path/Contents/Frameworks/Sparkle.framework"
sparkle_version="$framework/Versions/B"
# Sparkle XPC services are only for sandboxed apps. Both apps are intentionally
# unsandboxed, so remove them before signing the framework.
rm -rf "$sparkle_version/XPCServices"

sign_component() {
  codesign --force --options runtime --timestamp --sign "$identity" "$1"
}

sign_component "$sparkle_version/Autoupdate"
sign_component "$sparkle_version/Updater.app"
sign_component "$framework"
sign_component "$app_path"

codesign --verify --deep --strict --verbose=2 "$app_path"
app_signature_details=$(codesign --display --verbose=4 "$app_path" 2>&1)
team_identifier=$(printf '%s\n' "$app_signature_details" | sed -n 's/^TeamIdentifier=//p' | head -n 1)
[[ -n "$team_identifier" && "$team_identifier" != "not set" ]] || fail "The app signature has no Developer ID team identifier."
for component in "$sparkle_version/Autoupdate" "$sparkle_version/Updater.app" "$framework" "$app_path"; do
  codesign --verify --strict --verbose=2 "$component"
  if [[ "$component" == "$app_path" ]]; then
    signature_details=$app_signature_details
  else
    signature_details=$(codesign --display --verbose=4 "$component" 2>&1)
  fi
  [[ "$signature_details" == *'Authority=Developer ID Application:'* ]] || fail "${component##*/} is not signed with Developer ID Application."
  [[ "$signature_details" == *'Timestamp='* ]] || fail "${component##*/} has no secure timestamp."
  [[ "$signature_details" == *"TeamIdentifier=$team_identifier"* ]] || fail "${component##*/} has a different Developer ID team."
done
lipo "$app_path/Contents/MacOS/$APP_NAME" -verify_arch arm64
lipo "$app_path/Contents/MacOS/$APP_NAME" -verify_arch x86_64
for binary in "$sparkle_version/Sparkle" \
  "$sparkle_version/Autoupdate" \
  "$sparkle_version/Updater.app/Contents/MacOS/Updater"; do
  lipo "$binary" -verify_arch arm64 || fail "${binary##*/} is missing arm64."
  lipo "$binary" -verify_arch x86_64 || fail "${binary##*/} is missing x86_64."
done

dmg_path="$release_dir/$APP_NAME-$APP_VERSION.dmg"
zip_path="$release_dir/$APP_NAME-$APP_VERSION.zip"
appcast_dir="$release_dir/appcast"
mkdir -p "$appcast_dir"

hdiutil create -ov -format UDZO -volname "$APP_NAME" -srcfolder "$app_path" "$dmg_path"
codesign --force --timestamp --sign "$identity" "$dmg_path"
codesign --verify --verbose=2 "$dmg_path"
notary_key_path=""
notary_result="$release_dir/notary-result.json"
notary_log="$release_dir/notary-log.json"
cleanup() {
  if [[ -n "$notary_key_path" ]]; then
    rm -f "$notary_key_path"
  fi
}
trap cleanup EXIT
umask 077
notary_key_path=$(mktemp "${TMPDIR:-/tmp}/notary-key.XXXXXX")
printf '%s' "$APPLE_NOTARY_KEY_P8_BASE64" | base64 -D > "$notary_key_path"
chmod 600 "$notary_key_path"

xcrun notarytool submit "$dmg_path" \
  --key "$notary_key_path" \
  --key-id "$APPLE_NOTARY_KEY_ID" \
  --issuer "$APPLE_NOTARY_ISSUER_ID" \
  --wait --timeout 60m --output-format json > "$notary_result"
notary_status=$(jq -er '.status' "$notary_result")
[[ "$notary_status" == Accepted ]] || fail "Apple notarization did not return Accepted."
submission_id=$(jq -er '.id' "$notary_result")
xcrun notarytool log "$submission_id" \
  --key "$notary_key_path" \
  --key-id "$APPLE_NOTARY_KEY_ID" \
  --issuer "$APPLE_NOTARY_ISSUER_ID" > "$notary_log"
log_status=$(jq -er '.status' "$notary_log")
[[ "$log_status" == Accepted ]] || fail "The Apple notarization log did not confirm Accepted."
issue_count=$(jq -er '(.issues // []) | length' "$notary_log")
[[ "$issue_count" == 0 ]] || fail "Apple recorded issues in the notarization log."

xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
spctl --assess --type execute --verbose=2 "$app_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"

# Create the Sparkle archive only after the notarization ticket is stapled.
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
ditto "$zip_path" "$appcast_dir/$APP_NAME-$APP_VERSION.zip"
notes_path="$appcast_dir/$APP_NAME-$APP_VERSION.md"
awk -v version="$APP_VERSION" '
  /^## / {
    heading = $0
    sub(/^## /, "", heading)
    if (heading == version || index(heading, "[" version "]") == 1) {
      found = 1
      next
    }
    if (found) exit
  }
  found { print }
  END { if (!found) exit 1 }
' CHANGELOG.md > "$notes_path" || fail "CHANGELOG.md has no release notes for $APP_VERSION."
verify_zip_dir="$release_dir/verify-zip"
mkdir -p "$verify_zip_dir"
ditto -x -k "$zip_path" "$verify_zip_dir"
verified_app="$verify_zip_dir/$APP_NAME.app"
[[ -d "$verified_app" ]] || fail "The distributed ZIP does not contain $APP_NAME.app at its root."
xcrun stapler validate "$verified_app"
codesign --verify --deep --strict --verbose=2 "$verified_app"
spctl --assess --type execute --verbose=2 "$verified_app"
rm -rf "$verify_zip_dir"

download_prefix="https://github.com/$RELEASE_OWNER/$RELEASE_SLUG/releases/download/v$APP_VERSION/"
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$generate_appcast" \
    --ed-key-file - --download-url-prefix "$download_prefix" "$appcast_dir"
else
  "$generate_appcast" --account "$SPARKLE_KEYCHAIN_ACCOUNT" \
    --download-url-prefix "$download_prefix" "$appcast_dir"
fi

appcast="$appcast_dir/appcast.xml"
[[ -s "$appcast" ]] || fail "Sparkle did not generate appcast.xml."
read_xpath() {
  /usr/bin/xmllint --xpath "$1" "$appcast" 2>/dev/null || true
}
feed_version=$(read_xpath 'string((//*[local-name()="item"])[1]/*[local-name()="version"])')
feed_short_version=$(read_xpath 'string((//*[local-name()="item"])[1]/*[local-name()="shortVersionString"])')
feed_url=$(read_xpath 'string((//*[local-name()="item"])[1]/*[local-name()="enclosure"]/@url)')
feed_length=$(read_xpath 'string((//*[local-name()="item"])[1]/*[local-name()="enclosure"]/@length)')
signature=$(read_xpath 'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])')
[[ "$feed_version" == "$APP_BUILD_NUMBER" ]] || fail "Appcast sparkle:version does not match CFBundleVersion."
[[ "$feed_short_version" == "$APP_VERSION" ]] || fail "Appcast short version does not match the marketing version."
[[ "$feed_url" == "$download_prefix$APP_NAME-$APP_VERSION.zip" ]] || fail "Appcast enclosure does not point to this version's ZIP."
zip_length=$(stat -f%z "$zip_path")
[[ "$feed_length" == "$zip_length" ]] || fail "Appcast enclosure length does not match the ZIP size."
[[ -n "$signature" ]] || fail "The appcast has no EdDSA signature."
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$sign_update" --verify --ed-key-file - "$zip_path" "$signature"
else
  "$sign_update" --account "$SPARKLE_KEYCHAIN_ACCOUNT" --verify "$zip_path" "$signature"
fi

zip_sha=$(shasum -a 256 "$zip_path" | awk '{ print $1 }')
dmg_sha=$(shasum -a 256 "$dmg_path" | awk '{ print $1 }')
printf 'Release validation passed for %s %s (build %s).\n' "$APP_NAME" "$APP_VERSION" "$APP_BUILD_NUMBER"
printf 'Apple notarization: %s\n' "$submission_id"
printf 'ZIP: %s  SHA-256 %s\n' "$APP_NAME-$APP_VERSION.zip" "$zip_sha"
printf 'DMG: %s  SHA-256 %s\n' "$APP_NAME-$APP_VERSION.dmg" "$dmg_sha"
printf 'Appcast: %s\n' "$appcast"
