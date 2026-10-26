# Homebrew distribution

The published cask is maintained in [pedrotmr/homebrew-aerospace-tabs](https://github.com/pedrotmr/homebrew-aerospace-tabs). It downloads a signed, notarized app from the latest stable release and records the artifact's real SHA-256. The tap's own scheduled workflow checks GitHub every six hours, validates the bundle version and icon, and commits a cask update. It uses the tap repository's built-in `GITHUB_TOKEN` and needs no cross-repository secret.

## Install and update

```sh
brew install --cask pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs
```

Update with `brew update && brew upgrade`. Use the ordinary `brew upgrade` command. In Homebrew 7.0.11, a normal upgrade skips a readable self-updating app when it is already newer than the cask. `brew upgrade --cask pedrotmr-aerospace-tabs`, `--greedy`, and `--greedy-auto-updates` can reinstall the older version from the cask.

The current v0.1.2 cask points to an app without Sparkle, so it does not declare `auto_updates true` or write the Homebrew installation marker. The tap sync script adds those settings only when the released app bundle contains the Sparkle feed and public key.

## Current cask file

The cask available today is v0.1.2. Its URL and SHA-256 match the published release.

## Cask file for the tap

```ruby
cask "pedrotmr-aerospace-tabs" do
  version "0.1.2"
  sha256 "92979f91944800133e770b92579fe49fd77e1ff6d883916d57847982672fc33a"

  url "https://github.com/pedrotmr/aerospace-tabs/releases/download/v#{version}/AerospaceTabs.zip"
  name "Aerospace Tabs"
  desc "Window tabs and overview for AeroSpace"
  homepage "https://github.com/pedrotmr/aerospace-tabs"

  depends_on macos: :sonoma

  app "AerospaceTabs.app"

  caveats <<~EOS
    Requires AeroSpace to be installed and running.
    Accessibility permission enables global shortcuts and Dock notification badges.
    Screen Recording permission is optional and enables window previews.
  EOS
end
```

When a published appcast confirms the release has Sparkle, the synchronized cask adds `auto_updates true`, a `livecheck` Sparkle strategy, and a marker in the separate `com.pedrotmr.AerospaceTabs.homebrew` defaults domain. Uninstall removes only that marker; it does not touch app preferences or repository data.

## Release and validation

The app's [release workflow](BUILD-AND-RELEASE.md) uploads a versioned ZIP, DMG, and appcast to a GitHub draft. Publishing the draft makes the stable appcast public. The tap then downloads the versioned ZIP, validates the app bundle and icon, calculates SHA-256, runs `brew audit --cask --strict`, and commits the updated cask. Production casks must never use a draft URL or a placeholder checksum.

For local cask validation:

```sh
brew audit --cask --strict Casks/pedrotmr-aerospace-tabs.rb
```

The audit checks the current Ruby definition. Gatekeeper and stapling checks are run by the tap sync workflow against the actual downloaded app. Homebrew's [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook), [FAQ for self-updating apps](https://docs.brew.sh/FAQ#how-does-brew-upgrade-handle-apps-that-update-themselves), and [Tap Trust guide](https://docs.brew.sh/Tap-Trust) describe the relevant behavior.
