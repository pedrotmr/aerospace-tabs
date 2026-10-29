# Homebrew

The tap has a cask for the latest stable release: `pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs`.

The Homebrew workflow runs after a stable release is published. It skips drafts and prereleases. It checks the release ZIP, calculates its SHA-256, creates the cask, runs Homebrew's strict audit, then pushes the cask to `pedrotmr/homebrew-aerospace-tabs`.

Before publishing a stable release:

1. Add `HOMEBREW_TAP_TOKEN` to this app repository. Follow [the credential guide](CREDENTIALS.md).
2. The stable-release workflow will create or update the cask in the existing tap.

The cask uses a versioned ZIP URL and its real SHA-256. Do not use a draft URL or a made-up checksum. The cask does not delete app settings, files, or user repositories when it uninstalls.

The cask marks the app as Homebrew-managed and clears only that marker when removed. Direct downloads use Sparkle.

The cask requires macOS 14 or later. The app bundle and Sparkle feed carry the same minimum.

On a Homebrew install, **Check for Updates…** checks the Sparkle feed. It stays quiet when there is no update. When an update is available, choose **Update in App** to install it with Sparkle or **Copy Homebrew Command** to use Homebrew in Terminal. In-app updates keep the Homebrew marker. Homebrew compares the app version before replacing a self-updated app.

To update only this cask, run:

```sh
brew update
brew upgrade --cask --greedy-auto-updates pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs
```

Direct downloads use Sparkle. Do not use the Homebrew command to update a direct download.
