# Homebrew

The tap currently has the older v0.1.2 cask. The stable-release workflow will replace it after the next signed release is published.

The Homebrew workflow runs after a stable release is published. It skips drafts and prereleases. It checks the release ZIP, calculates its SHA-256, creates the cask, runs Homebrew's strict audit, then pushes the cask to `pedrotmr/homebrew-aerospace-tabs`.

Before publishing a stable release:

1. Add `HOMEBREW_TAP_TOKEN` to this app repository. Follow [the credential guide](CREDENTIALS.md).
2. The stable-release workflow will create or update the cask in the existing tap.

The cask uses a versioned ZIP URL and its real SHA-256. Do not use a draft URL or a made-up checksum. The cask does not delete app settings, files, or user repositories when it uninstalls.

When Sparkle is enabled, the cask marks the app as Homebrew-managed. That app copy does not start Sparkle. Homebrew handles its updates. The cask clears only that marker when removed. Direct downloads use Sparkle.

Update Homebrew apps with `brew update && brew upgrade`. A named cask upgrade or a greedy upgrade can install the cask version over a newer Sparkle version. Use the ordinary `brew upgrade` command.

The install command is ready only after a cask exists in the tap and points to a public, signed, notarized release.
