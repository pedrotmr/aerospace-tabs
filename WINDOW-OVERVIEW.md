# Window Overview

**Status:** Implemented. This document describes current behavior and records the design decisions behind it. See the [README](README.md) for setup and the [charter](CHARTER.md) for the project boundary.

## Purpose

The Window Overview gives AeroSpace users one place to find and focus windows across occupied AeroSpace workspaces. macOS Mission Control does not organize windows around AeroSpace's workspace model, so Aerospace Tabs reads that model while leaving tiling and layout ownership with AeroSpace.

## Current behavior

- A full-screen panel appears on every connected display. Each panel shows windows from occupied AeroSpace workspaces on that display, grouped visually by workspace and ordered by workspace name. Numeric workspace names sort numerically.
- Workspace groups have no persistent labels or controls. Window cards show previews; hovering a card reveals its title and outline. The overview uses the selected window's display for arrow-key navigation, while pointer selection works on every display.
- Click a card or press Return to focus its window. Aerospace Tabs switches to the window's workspace and display as needed. It does not move, resize, close, or retile windows.
- Arrow keys move the selection. Escape or a click on the empty background dismisses the overview. Dismissing without selecting attempts to reactivate the previously frontmost application.
- Right-click a visible tab strip and choose **Open Window Overview** to open it directly. Incomplete rows are centered; dense layouts scroll before previews become too small to recognize. Appearance follows the selected Glass or Solid theme.
- If preview permission is unavailable, app icons remain as placeholders and window selection still works.

## Activation and macOS settings

- Three-finger swipe is enabled by default: swipe up to open and down to close. The optional hot corner is off until selected in the strip's right-click menu.
- Gesture detection loads the private MultitouchSupport framework dynamically and retries when a compatible trackpad is unavailable. If it cannot load, the menu can report that the gesture is waiting; manual opening and a selected hot corner remain available.
- While enabled, Aerospace Tabs temporarily disables the matching native Mission Control gesture and selected macOS hot-corner action. It saves original preferences before changing them and restores a value only while it still matches the value the app applied. Dock restarts to apply preference changes.
- Saved originals survive a force-quit for later cleanup. On normal shutdown, changed native values are left alone rather than overwritten.

## Permissions

- **Accessibility** supports global shortcuts and Dock notification badges.
- **Screen Recording** enables window previews. The overview can request access and open the relevant System Settings pane. Without access, cards use app icons.

## Scope and design decisions

The overview is part of Aerospace Tabs. It shows all connected displays and occupied AeroSpace workspaces together; it does not manage native macOS Spaces, edit AeroSpace layouts, move windows between workspaces, create or rename workspaces, or provide status widgets. The design keeps cached images for fast opening and limits live capture to visible thumbnails to balance responsiveness, freshness, and memory use.

## Preview lifecycle and privacy

- Preview requests target exact AeroSpace window IDs. Opening starts snapshots for the listed windows; cached images can appear immediately from the previous session. At most three snapshot captures run concurrently. Snapshots use a window backing-store capture when available, with a ScreenCaptureKit screenshot fallback, and are capped at 1,920 pixels per edge.
- Panels fade in over 80 ms. Live ScreenCaptureKit streams start about 90 ms after opening and run only for visible thumbnails, targeting 30 fps. Frames render through AVSampleBufferDisplayLayer. Each stream uses three buffers.
- Stream resolution follows thumbnail size and display backing scale, capped at 3,200 pixels per edge and 20 megapixels across visible thumbnails on all displays. Stream failures retry; visible thumbnails fall back to periodic snapshots when streaming is unavailable.
- A bounded 96 MB in-memory cache retains previews between openings and evicts older images. Closed-window images are removed.
- Closing stops the preview timer, queued snapshots, streams, and overview panels. Already-started snapshot work and final stream frames may finish into the cache. No new captures are scheduled while closed. Images and video are not saved to disk or sent off-device.

[AeroKit](https://github.com/jomatsu/aerokit) informed the spatial Exposé interaction and direct focus. [SwipeAeroSpace](https://github.com/MediosZ/SwipeAeroSpace) is a reference for a full-screen, monitor-grouped overview. Aerospace Tabs shows all occupied AeroSpace workspaces together by default.
