# Aerospace Tabs

A companion tab strip for people who already run [AeroSpace](https://github.com/nikitabobko/AeroSpace). AeroSpace tiles; this app only lists windows, focuses them, and keeps a local tab order.

See [CHARTER.md](CHARTER.md) for what this is, what it isn’t, and how support works (**best-effort**, no SLA).

## Features

- Top tab strip groups windows from every occupied AeroSpace workspace on each screen, with numbered spaces in ascending order (shown when that screen has **2+** windows total)
- Click a tab to focus; drag to reorder within its workspace
- Option-Tab / Option-`` ` `` to cycle windows in the focused space (hold to repeat; release Tab/`` ` `` to stop)
- Control-Option-Tab / Control-Option-`` ` `` to cycle occupied spaces
- Mirrors app notification badges from the Dock on matching tabs
- Hides during Mission Control / App Exposé
- Temporarily boosts AeroSpace `gaps.outer.top` so windows clear the strip; restores on quit

## Requirements

- macOS
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) running
- Accessibility permission (for global shortcuts and Dock notification badges)

## Run

```bash
cd aerospace-tabs
make run
```

Grant Accessibility when macOS asks.

## Gaps

On launch the app adds strip height to your `gaps.outer.top`, keeps a backup next to your AeroSpace config, and restores on quit.

If a force-quit left gaps boosted: right-click the strip → **Restore AeroSpace gaps**, or:

```bash
make restore-gaps
# or
./.build/release/AerospaceTabs --restore-gaps
```

## License

MIT
