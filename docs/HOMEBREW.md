# Homebrew

The tap has a cask for the latest stable release: `pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs`.

The Homebrew workflow runs after a stable release is published. It skips drafts and prereleases. It checks the release ZIP, calculates its SHA-256, creates the cask, runs Homebrew's strict audit, then pushes the cask to `pedrotmr/homebrew-aerospace-tabs`.

Before publishing a stable release:

1. Add `HOMEBREW_TAP_TOKEN` to this app repository. Follow [the credential guide](CREDENTIALS.md).
2. The stable-release workflow will create or update the cask in the existing tap.

The cask uses a versioned ZIP URL and its real SHA-256. Do not use a draft URL or a made-up checksum. The cask does not delete app settings, files, or user repositories when it uninstalls.

The cask marks the app as Homebrew-managed and clears only that marker when removed. The app does not start Sparkle for this copy. Direct downloads use Sparkle.

The cask requires macOS 14 or later. The app bundle and Sparkle feed carry the same minimum.

Homebrew manages updates for this copy. To update only this cask, run:

```sh
brew update
brew upgrade --cask pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs
```

Direct downloads use Sparkle. Do not use the Homebrew command to update a direct download.
