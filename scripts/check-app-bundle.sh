#!/usr/bin/env bash
set -euo pipefail

app_path=${1:?Usage: check-app-bundle.sh /path/to/App.app}
info_plist="$app_path/Contents/Info.plist"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

[[ -d "$app_path" ]] || fail "App bundle not found: $app_path"
[[ -f "$info_plist" ]] || fail "Info.plist is missing from the app bundle."

read_plist() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$info_plist" 2>/dev/null || true
}

[[ "$(read_plist CFBundleIdentifier)" == "$APP_BUNDLE_ID" ]] || fail "Bundle identifier does not match $APP_BUNDLE_ID."
[[ "$(read_plist CFBundleShortVersionString)" == "$APP_VERSION" ]] || fail "Marketing version does not match $APP_VERSION."
[[ "$(read_plist CFBundleVersion)" == "$APP_BUILD_NUMBER" ]] || fail "Build version does not match $APP_BUILD_NUMBER."
[[ "$(read_plist LSMinimumSystemVersion)" == "$APP_MIN_SYSTEM_VERSION" ]] || fail "Minimum macOS version does not match $APP_MIN_SYSTEM_VERSION."
[[ -n "$(read_plist NSHumanReadableCopyright)" ]] || fail "Copyright metadata is empty."
[[ -n "$(read_plist NSScreenCaptureUsageDescription)" ]] || fail "Screen Recording usage description is missing."

feed_url=$(read_plist SUFeedURL)
[[ "${SPARKLE_ENABLED:-}" == YES ]] || fail "Sparkle must be enabled in Config/App.xcconfig."
[[ "$feed_url" == "$SPARKLE_FEED_URL" ]] || fail "Sparkle feed URL does not match Config/App.xcconfig."
public_key=$(read_plist SUPublicEDKey)
[[ -n "$public_key" && "$public_key" == "$SPARKLE_PUBLIC_ED_KEY" ]] || fail "Sparkle public key does not match Config/App.xcconfig."

resources="$app_path/Contents/Resources"
icon_name=$(read_plist CFBundleIconFile)
[[ -n "$icon_name" ]] || fail "CFBundleIconFile is missing."
[[ -f "$resources/$icon_name" || -f "$resources/$icon_name.icns" ]] || fail "The app bundle icon named in Info.plist is missing."
[[ -f "$resources/Sparkle-LICENSE.txt" ]] || fail "Sparkle license notices are missing from the app bundle."

sparkle="$app_path/Contents/Frameworks/Sparkle.framework"
[[ -x "$sparkle/Versions/B/Sparkle" ]] || fail "Sparkle.framework is missing its main binary."
[[ -x "$sparkle/Versions/B/Autoupdate" ]] || fail "Sparkle.framework is missing Autoupdate."
[[ -x "$sparkle/Versions/B/Updater.app/Contents/MacOS/Updater" ]] || fail "Sparkle.framework is missing Updater.app."

executable="$app_path/Contents/MacOS/$(read_plist CFBundleExecutable)"
[[ -x "$executable" ]] || fail "The app executable is missing."
lipo "$executable" -verify_arch arm64 || fail "The app executable is missing arm64."
lipo "$executable" -verify_arch x86_64 || fail "The app executable is missing x86_64."
for binary in "$sparkle/Versions/B/Sparkle" \
	"$sparkle/Versions/B/Autoupdate" \
	"$sparkle/Versions/B/Updater.app/Contents/MacOS/Updater"; do
	lipo "$binary" -verify_arch arm64 || fail "Sparkle component is missing arm64: ${binary##*/}"
	lipo "$binary" -verify_arch x86_64 || fail "Sparkle component is missing x86_64: ${binary##*/}"
done
otool -l "$executable" | grep -F '@executable_path/../Frameworks' >/dev/null || fail "The app is missing its Frameworks runtime search path."
otool -L "$executable" | grep -F 'Sparkle.framework/Versions/B/Sparkle' >/dev/null || fail "The app does not link Sparkle.framework."

printf 'App bundle verified: %s (%s, build %s)\n' "$APP_BUNDLE_ID" "$APP_VERSION" "$APP_BUILD_NUMBER"
