# Aerospace Tabs — Charter

Aerospace Tabs is a **companion** for people who already run [AeroSpace](https://github.com/nikitabobko/AeroSpace). AeroSpace tiles; this app lists and focuses windows, keeps a local tab order, and provides a visual overview grouped by space that can replace Mission Control in the user’s workflow.

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

## Support and ceiling

- Public repository: yes
- Issues and PRs: welcome, **best-effort**, no SLA
- **Performance** beats new features

New ideas must pass the feature fence:

1. Do not touch AeroSpace’s layout tree  
2. Do not regress strip/focus latency on the hot path  
3. Show occupied AeroSpace spaces in the strip and Window Overview
4. The maintainer would use it the following week  

Fail any → no (or file an issue and move on).

## Milestone order

1. **Reliability** (+ minimal feel polish for daily dogfood): strip does not vanish spuriously; gaps always restore; Mission Control / Dock detection stays honest  
2. **Feel**: strip when **2+** windows; overview stays responsive with many windows and shows window content; intentional visual language; then share
3. **Share**: public GitHub repo (MIT), stranger-ready README + Accessibility notes, screenshot/GIF, GitHub Release with `.app`/zip. Homebrew and notarization come later.

This file is the durable north star for the project. The wayfinder map under `.scratch/aerospace-tabs-horizon/` is the process for getting here and past remaining fog — not a substitute for this charter.
