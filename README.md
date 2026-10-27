<img src="Resources/aerospace-tabs-icon.png" alt="Aerospace Tabs app icon" width="160">

# Aerospace Tabs

A macOS companion for [AeroSpace](https://github.com/nikitabobko/AeroSpace) with a window tab strip and workspace-grouped overview for finding and focusing windows.

> **Maintenance:** Development is paused. Issues and pull requests are welcome on a best-effort basis, but replies and new releases are not promised.

![Screenshot placeholder: capture Aerospace Tabs with a local demo setup](Screenshots/aerospace-tabs-workspaces-placeholder.svg)

*Not a product screenshot. See [capture notes](docs/SCREENSHOT.md).*

## Install

The latest published version is v0.1.2. Install it with Homebrew:

```sh
brew install --cask pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs
```

For a direct install, download the versioned `AerospaceTabs-<version>.zip` asset from [GitHub Releases](https://github.com/pedrotmr/aerospace-tabs/releases/latest), unzip it, and move `AerospaceTabs.app` to Applications. The published app is signed and notarized.

## First launch

1. Install and start [AeroSpace](https://github.com/nikitabobko/AeroSpace).
2. Open **Aerospace Tabs** from Applications. Allow **Accessibility** when macOS asks.
3. With two or more windows open on that display, right-click the strip and choose **Open Window Overview**. Use the arrow keys and Return to focus a window; Escape closes the overview.

## What it does

- Lists AeroSpace windows from occupied workspaces on each display. The strip appears when that display has two or more windows.
- Click a tab to focus its window; drag to change its local order.
- Shows a full-screen overview grouped by workspace. Three-finger swipe opens it by default; an optional hot corner is available from the strip menu.

## Requirements and limitations

- macOS 14 or later, with AeroSpace installed and running.
- Accessibility enables global shortcuts and Dock notification badges. Screen Recording is optional and enables window previews.
- The app temporarily increases AeroSpace's `gaps.outer.top` while running, then restores it on quit. Recovery instructions are in [usage notes](docs/usage.md).
- Trackpad swipe detection uses macOS's private `MultitouchSupport` framework and may break after system updates. Window previews stay in memory and are not saved or sent off-device.
- This is not a window manager and does not manage native macOS Spaces.
- The published v0.1.2 build has no in-app updater. Direct users of that version must download updates manually. A Sparkle-enabled release will update direct downloads; Homebrew installs should use `brew update && brew upgrade`.

## Help and development

- **Questions and problems:** [GitHub Issues](https://github.com/pedrotmr/aerospace-tabs/issues)
- **Setup and development:** [Documentation index](docs/README.md), including [contribution](CONTRIBUTING.md) and [build and release](docs/BUILD-AND-RELEASE.md) guides
- **License:** [MIT](LICENSE) · [Third-party notices](docs/THIRD-PARTY-NOTICES.md)
