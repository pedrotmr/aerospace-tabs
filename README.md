# Aerospace Tabs

A companion tab strip for people who already run [AeroSpace](https://github.com/nikitabobko/AeroSpace). AeroSpace tiles; this app only lists windows, focuses them, and keeps a local tab order.

See [CHARTER.md](CHARTER.md) for what this is, what it isn’t, and how support works (**best-effort**, no SLA).

## Features

- Top tab strip for windows on the current workspace (shows when there are **2+** windows)
- Click a tab to focus; drag to reorder (order is local to the strip, per workspace)
- Option-Tab / Option-`` ` `` to cycle (hold to repeat; release Tab/`` ` `` to stop)
- Hides during Mission Control / App Exposé
- Temporarily boosts AeroSpace `gaps.outer.top` so windows clear the strip; restores on quit

## Requirements

- macOS
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) running
- Accessibility permission (for Option-Tab to be swallowed instead of going to the focused app)

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
