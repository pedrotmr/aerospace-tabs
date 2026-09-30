# Aerospace Tabs

A companion for people who already run [AeroSpace](https://github.com/nikitabobko/AeroSpace). AeroSpace tiles; this app lists and focuses windows, keeps a local tab order, and shows a visual overview grouped by AeroSpace workspace.

See [CHARTER.md](CHARTER.md) for what this is, what it isn’t, and how support works (**best-effort**, no SLA).

## Features

- Top tab strip groups windows from every occupied AeroSpace workspace on each screen, with numbered spaces in ascending order (shown when that screen has **2+** windows total)
- Click a tab to focus; drag to reorder within its workspace
- Window Overview shows image-only previews from all occupied AeroSpace workspaces, grouped by workspace across every connected display
- Hover to reveal a window’s title without zooming; click a preview or use the keyboard to focus its window
- Three-finger swipe up opens the overview, and swipe down closes it; choose an optional hot corner from the strip’s right-click menu
- Cached previews appear immediately, then visible windows stream live at up to 30 fps while the overview is open
- Option-Tab / Option-`` ` `` to cycle windows in the focused space (hold to repeat; release Tab/`` ` `` to stop)
- Control-Option-Tab / Control-Option-`` ` `` to cycle occupied spaces
- Mirrors app notification badges from the Dock on matching tabs
- The tab strip hides during native Mission Control / App Exposé
- Temporarily boosts AeroSpace `gaps.outer.top` so windows clear the strip; restores on quit
- The right-click menu groups strip settings, AeroSpace config controls, and quit actions; quitting AeroSpace also closes its companion

Select **Choose Config Editor…** once from the AeroSpace submenu; **Open Config** uses that editor on later openings. Opening the config keeps Aerospace Tabs running with its current tab strips and gap boost active.

## Requirements

- macOS 14 or later
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) running
- Accessibility permission (for global shortcuts and Dock notification badges)
- Screen Recording permission (optional, for window thumbnails; app icons remain as placeholders without it)

Trackpad swipe detection uses the macOS MultitouchSupport private framework at runtime and retries when a compatible trackpad is temporarily unavailable at launch or after wake. While the three-finger trigger is enabled, Aerospace Tabs temporarily disables the matching macOS Mission Control gesture. A selected hot corner is temporarily disabled in Dock settings while Aerospace Tabs owns it. Dock restarts briefly to apply these changes. On disable or quit, saved settings are restored only if the native value still matches the value Aerospace Tabs applied; otherwise the changed setting is left alone. A force-quit keeps saved values for restoration on the next clean exit. The optional hot corner is configured from the strip’s right-click menu and starts disabled.

Right-click a visible strip and choose **Open Window Overview** to open it directly. Use the arrow keys to move, Return to focus a window, and Escape to close immediately. Clicking the empty background also closes the overview. Previews are warmed in advance and kept in a bounded memory cache between openings. While the overview is open, visible windows stream live at up to 30 fps at a resolution matched to the display’s backing scale; streams stop when it closes. No screenshots or videos are saved to disk.

## Run

```bash
cd aerospace-tabs
make run
```

Grant Accessibility when macOS asks.

## Gaps

On launch the app adds strip height to your `gaps.outer.top`, keeps a backup next to your AeroSpace config, and restores on quit.

If Aerospace Tabs is force-quit before cleanup, the next launch restores any leftover gap boost automatically. To restore it manually without opening the app, run:

```bash
make restore-gaps
# or
./.build/release/AerospaceTabs --restore-gaps
```

## License

MIT

See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for the AeroKit multitouch-layout attribution.
