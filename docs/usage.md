# Using AeroSpaceTabs

## First launch

1. Install and start [AeroSpace](https://github.com/nikitabobko/AeroSpace).
2. Install AeroSpaceTabs from the [Homebrew tap](https://github.com/pedrotmr/homebrew-aerospace-tabs), then open it from Applications.
3. Allow **Accessibility** in System Settings when prompted. It enables global shortcuts and Dock notification badges. If you dismissed the prompt, open Accessibility Settings from a strip's right-click menu.
4. **Screen Recording** is optional. It enables window previews; without it, the overview still focuses windows and uses app icons. After granting access in System Settings, quit and reopen AeroSpaceTabs to start capture.

The strip appears on a display when AeroSpace reports at least two windows there. Click a tab to focus its window; drag tabs to change their local order. Right-click a visible strip and choose **Open Window Overview**. In the overview, use the arrow keys and Return to select a window, or Escape to close.

Three-finger swipe is enabled by default: swipe up to open the overview and down to close it. The optional hot corner starts disabled and can be selected from the strip's right-click menu. The gestures use the private macOS `MultitouchSupport` framework, so swipe detection may stop working after a macOS change. The strip menu remains available whenever the strip is visible.

Global shortcuts are **Option-Tab** and **Option-Backtick** to cycle windows in the focused workspace, and **Control-Option-Tab** and **Control-Option-Backtick** to cycle occupied workspaces. Hold a shortcut to repeat; release Tab or backtick to stop.

## AeroSpace configuration and recovery

While running, AeroSpaceTabs temporarily increases AeroSpace's `gaps.outer.top` so tiled windows clear the strip. It saves the original configuration and restores it on a normal quit. If the app is force-quit, the next launch attempts recovery. To restore the saved gap manually from a source checkout:

```sh
make restore-gaps
```

When three-finger swipe is enabled, the app temporarily disables the matching native Mission Control gesture. A selected hot corner is also disabled while the app owns it. The Dock briefly restarts to apply these settings. On quit, saved values are restored only if they still match the values AeroSpaceTabs applied.

Select **Choose Config Editor…** from the AeroSpace submenu once; **Open Config** uses that editor later. Opening the config leaves AeroSpaceTabs and its gap adjustment running.

## Previews and privacy

Window previews are captured only while the overview is open and held in a bounded memory cache. AeroSpaceTabs does not save screenshots or video to disk or send them off-device. See [Window Overview behavior](WINDOW-OVERVIEW.md) for capture limits, fallback behavior, and display grouping.

If AeroSpace is unavailable, the app shows a reconnecting status and hides stale tabs. The strip is intentionally absent on a display with fewer than two windows.
