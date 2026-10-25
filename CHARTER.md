# Aerospace Tabs — Charter

Aerospace Tabs is a **companion** for people who already run [AeroSpace](https://github.com/nikitabobko/AeroSpace). AeroSpace tiles; this app lists and focuses windows, keeps a local tab order, and provides a visual overview grouped by AeroSpace workspace that can replace Mission Control in the user’s workflow.

## What it is not

- Not a window manager
- Not a SketchyBar-style status bar (no CPU/battery/widgets)
- Not a WinMux-style shell (we do not own tiling or replace AeroSpace)
- Not a manager for native macOS Spaces

Peer tools in the AeroSpace ecosystem are documented separately when useful. This charter does **not** keep a rivalry-style comparison table.

## Dependency

Requires a running AeroSpace. If AeroSpace’s socket/subscribe API changes, we **adapt** — we do **not** fork AeroSpace.

## Audience

AeroSpace users (the maintainer included).

## Support and maintenance

- The repository remains public, and the latest published release is `v0.1.1`.
- Development is paused as of 2026-10-25. Occasional maintenance may happen, but no replies or new releases are promised.
- Issues and pull requests are welcome on a best-effort basis, with no SLA.
- **Performance** beats new features.

New ideas must pass the feature fence:

1. Do not touch AeroSpace’s layout tree  
2. Do not regress strip/focus latency on the hot path  
3. Show occupied AeroSpace workspaces in the strip and Window Overview
4. The maintainer would use it the following week  

Fail any → no (or file an issue and move on).

This file records the project's scope and support expectations.
