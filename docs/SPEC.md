# Specification

AeroSpaceTabs is a macOS companion for people who use AeroSpace.

## Behavior

- Lists AeroSpace windows on occupied workspaces for each display and shows a tab strip when a display has at least two windows.
- Focuses windows from tabs and lets users reorder tabs locally.
- Provides a full-screen overview grouped by workspace, with keyboard navigation and optional window previews.
- Uses Accessibility to read and focus windows and run global shortcuts. Screen Recording is optional for previews.
- Offers Sparkle updates to direct downloads. Homebrew installations check the Sparkle feed on request and can choose an in-app update or copy the Homebrew command when an update is available.

## Scope and limits

The app requires AeroSpace to be installed and running. It does not tile windows, replace AeroSpace, or manage native macOS Spaces. It temporarily changes AeroSpace's top outer gap while running and normally restores the previous value on quit. Recovery instructions are in the [usage guide](usage.md).

Trackpad gesture support relies on macOS's private `MultitouchSupport` framework and can break after system updates. Window previews stay on the Mac and are not saved. The v0.1.2 direct build has no Sparkle updater, so users on that version must install a newer release manually once. Later direct releases can update with Sparkle.
