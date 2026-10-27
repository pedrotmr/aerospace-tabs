<img src="Resources/aerospace-tabs-icon.png" alt="Aerospace Tabs app icon" width="160">

# Aerospace Tabs

A macOS companion for [AeroSpace](https://github.com/nikitabobko/AeroSpace). It adds window tabs and a workspace overview so you can find and focus windows.

> **Maintenance:** Maintenance is limited. Issues and pull requests are welcome on a best-effort basis. Replies and release dates are not promised.

![Screenshot placeholder: capture Aerospace Tabs with a local demo setup](Screenshots/aerospace-tabs-workspaces-placeholder.svg)

*Not a product screenshot. See [capture notes](docs/SCREENSHOT.md).*

## Install

### Homebrew

```sh
brew install --cask pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs
```

Homebrew installs and updates this copy. Update it with `brew update && brew upgrade`.

### Direct download

Download the latest stable `AerospaceTabs-<version>.dmg` from [GitHub Releases](https://github.com/pedrotmr/aerospace-tabs/releases/latest). Open the disk image and drag `AerospaceTabs.app` to Applications.

Direct installs can use **Check for Updates…** in the app. Releases before v0.2.0 do not include Sparkle. If you use one of those versions, install the latest release manually once.

## First launch

1. Install and start [AeroSpace](https://github.com/nikitabobko/AeroSpace).
2. Open **Aerospace Tabs** from Applications and allow **Accessibility** access when macOS asks.
3. With two or more windows open on a display, right-click the strip and choose **Open Window Overview**. Use the arrow keys and Return to focus a window. Press Escape to close the overview.

## What it does

- Shows windows from occupied AeroSpace workspaces on each display. A strip appears when a display has two or more windows.
- Click a tab to focus its window. Drag tabs to change their order on that display.
- Shows a full-screen overview grouped by workspace. A three-finger swipe opens it by default. You can also set a hot corner in the strip menu.

## Requirements and limits

- macOS 14 or later, with AeroSpace installed and running.
- Accessibility access is required. Screen Recording is optional and enables window previews.
- The app temporarily increases AeroSpace's `gaps.outer.top` while it runs, then restores it when you quit. See [usage notes](docs/usage.md) if recovery is needed.
- Trackpad swipe detection uses Apple's private `MultitouchSupport` framework and may break after a macOS update. Window previews stay in memory. The app does not save or send them.
- Aerospace Tabs is not a window manager and does not manage native macOS Spaces.

## Help and development

- **Questions and problems:** [GitHub Issues](https://github.com/pedrotmr/aerospace-tabs/issues)
- **Setup and development:** [Documentation index](docs/README.md), [contribution guide](CONTRIBUTING.md), and [build and release guide](docs/BUILD-AND-RELEASE.md)
- **License:** [MIT](LICENSE) · [Third-party notices](docs/THIRD-PARTY-NOTICES.md)
