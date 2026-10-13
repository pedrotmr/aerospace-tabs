# Aerospace Tabs

A companion tab strip for people who already use AeroSpace. AeroSpace tiles; this only lists and focuses windows.

## Language

**Aerospace Tabs**:
The companion itself — the menuless macOS agent that draws the workspace tab strip.
_Avoid_: product, window manager, bar suite, AerospaceTabs (in prose)

**Companion**:
Software that depends on AeroSpace and stays out of tiling. It observes and focuses; it does not own the layout tree.
_Avoid_: plugin (implies in-process), extension, fork

**AeroSpace user**:
Someone who already runs AeroSpace as their window manager. The primary audience.
_Avoid_: general Mac user, Switcher user, yabai migrant (unless they already switched)

**Charter**:
The short written answer to what Aerospace Tabs is, isn’t, depends on, who it’s for, support stance, and the next milestone.
_Avoid_: roadmap, vision doc, PRD

**Ceiling**:
How far this project is willing to go for people who aren’t the maintainer — publish or not, support or not, installable or not.
_Avoid_: product-market fit, ambition

**Performance**:
Snappy focus and strip updates beat extra features. When a feature and speed conflict, speed wins.
_Avoid_: “fast enough”, optimize later

**Feature fence**:
The hard in/out boundary for what the companion may do. Core verbs are list + focus (+ local tab order) and the AeroSpace-grouped Window Overview. Layout ownership, status widgets, other WMs, and managing native macOS Spaces are out.
_Avoid_: roadmap features, backlog of maybes treated as promises

**Window Overview**:
Aerospace Tabs’ full-screen view of open windows across occupied AeroSpace workspaces. Every connected display is shown. Window previews are visually grouped by workspace without persistent text or controls; hovering reveals the window title, and selecting one focuses it without changing AeroSpace’s layout.
_Avoid_: native Spaces manager, layout editor

**Preview policy**:
Previews use AeroSpace window IDs, stay in memory, and start only while the overview is open. See [Window Overview](WINDOW-OVERVIEW.md#preview-lifecycle-and-privacy) for capture limits, fallbacks, and cleanup.
_Avoid_: background capture, saved screenshots, sending preview data off-device
