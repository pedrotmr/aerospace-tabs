# All-Space Overview — Draft

**Status:** Implemented in Aerospace Tabs; native build verified. The overview extends the existing companion charter while leaving AeroSpace responsible for tiling and workspace layout.

## Summary

Add a full-screen, AeroSpace-aware window overview that can take the place of macOS Mission Control in the user’s workflow. Open it with a three-finger swipe up or a configurable hot corner. Show every open window across occupied AeroSpace workspaces, grouped by workspace, so the user can scan and focus a window without remembering where it lives.

AeroSpace remains responsible for tiling and layout. Aerospace Tabs reads workspace and window state, shows the overview, then switches to and focuses the selected window.

## User need

When windows are spread across many AeroSpace workspaces, the user wants one visual surface to see what is open and jump directly to a window. macOS Mission Control does not organize AeroSpace’s virtual workspaces, so this overview needs to read AeroSpace’s workspace model.

## Proposed experience

### Open the overview

- Three-finger upward trackpad swipe opens the overview; another upward swipe leaves it open. A downward swipe closes it.
- A configurable hot corner is an optional trigger; the user may leave it disabled.
- While a trigger is enabled, Aerospace Tabs temporarily disables the matching native Mission Control gesture or selected macOS hot corner. On disable or quit, it restores the saved preference only if the native setting still matches the value Aerospace Tabs applied; otherwise it leaves the changed value alone. While ownership remains enabled, a later settings reconciliation can reapply the override.
- Dock restarts briefly when these preferences change so macOS applies them. Saved values survive a force-quit and can be restored on the next clean exit if the native setting still matches the app’s override.

### Browse windows

- Show every open window in every occupied AeroSpace workspace, across connected displays.
- Group windows by AeroSpace workspace. Separate groups visually without names or labels.
- Keep workspace order stable per display. Only hovered windows receive an outline; the currently focused window has no persistent border.
- Represent each window with its image preview. If macOS permissions prevent previews, show the app icon as a placeholder.
- Show every connected display at once, with no display filter.
- Show occupied workspaces only; empty workspaces are omitted.
- Support pointer selection and keyboard navigation. Arrow keys move between windows, Return focuses the selection, and Escape closes the overview immediately, without requiring a click first. Clicking the empty background also dismisses it.

### Focus a window

Selecting a window closes the overview, switches to that window’s workspace and display as needed, then focuses the window. Canceling the overview attempts to reactivate the previously frontmost application. The overview does not move, resize, close, or retile windows.

## MVP boundary

**In scope:** full-screen overview, all occupied workspaces, image-only window previews grouped visually by space, pointer and keyboard selection, three-finger swipe-up activation, configurable hot corner, and direct focus of a selected window.

**Out of scope:** changing AeroSpace layouts, dragging windows between workspaces, creating or renaming workspaces, managing native macOS Spaces, status widgets.

For performance and privacy, the implementation uses a hybrid update policy:

- Refresh workspace, title, and focus metadata from AeroSpace events while the overview is open. Measure window proportions on opening and when the window list changes.
- Prepare panels before activation and use an 80 ms opening fade; start live capture after the fade.
- Warm newly discovered windows before activation; refresh the visible workspace every five seconds while closed.
- Capture by exact window ID off the main queue. Use ScreenCaptureKit video streams for visible thumbnails, targeting 30 fps, with three buffers per stream.
- Render live frames directly through AVSampleBufferDisplayLayer. Match stream resolution to the thumbnail, using the display backing scale, capped at 3200 pixels per edge and 20 megapixels total across displays. Stop streams on close or when a thumbnail leaves the viewport.
- Keep a bounded 96 MB cache in memory between openings, evicting old images and removing closed windows. Never save thumbnails to disk or send them off-device.
- Use window bounds for layout independently of screenshot arrival; center incomplete rows and keep workspace order stable.

## Permissions and setup

- **Accessibility:** existing global shortcuts and Dock badge reading may use Accessibility access.
- **Screen Recording:** capture window previews. The overview can request access and open the relevant System Settings pane. Without access, show app icons as placeholders.
- **Gesture input:** the app dynamically loads the private MultitouchSupport framework. Device discovery retries after launch, wake, or a disconnected device. If the framework is unavailable, the overview and hot corner remain usable.
- **Hot corner:** choose a corner from the strip’s right-click menu. Aerospace Tabs temporarily disables that corner’s native action while it is selected.

## Acceptance criteria

1. One activation shows windows from every occupied AeroSpace workspace on all displays, grouped visually without visible labels.
2. Selecting any card activates its existing window, even when it is on another workspace or display.
3. Keyboard and pointer users can navigate, select, and dismiss the overview without visible control text.
4. Dismissing without selection attempts to reactivate the previously frontmost application.
5. Disabling a trigger or quitting restores its saved macOS preference when it still matches the value applied by Aerospace Tabs; clean app quit restores all matching active overrides.
6. The feature does not change AeroSpace’s layout tree or rewrite the user’s AeroSpace configuration without an explicit setup action.
7. If preview permission is absent, workspace grouping and focus still work with app icons as visual placeholders.

## Reference points

[AeroKit](https://github.com/jomatsu/aerokit) is the interaction reference for spatial Exposé, three-finger gestures, and direct focus; its documented Exposé shows the focused workspace, while App Exposé finds the focused app across workspaces. [SwipeAeroSpace](https://github.com/MediosZ/SwipeAeroSpace) demonstrates a full-screen, monitor-grouped overview with live workspace previews and direct window focus. The proposed distinction is to keep all occupied workspaces and their windows visible together by default.

## Implementation notes

- The overview is part of Aerospace Tabs and uses one full-screen panel per display so all connected displays can appear at once.
- Each panel groups windows by occupied AeroSpace workspace. Group boundaries are visual only; no workspace names, toolbar, search, filter, or keyboard hints appear in the overview. Hovering outlines the window and reveals its title in a centered capsule, without scaling the preview.
- Preview size responds to the number of windows and the available display area; incomplete rows stay centered, with scrolling for very dense layouts.
- Window cards use a fast window-backing-store capture when macOS provides it and ScreenCaptureKit as a fallback. Without Screen Recording access, the overview keeps app icons as visual placeholders and still supports focus.
- All visible previews support live video while the overview is open. Cached images cover stream startup, and periodic snapshots remain the fallback when streaming is unavailable.
- Appearance follows the existing Glass/Solid selection. Arrow-key navigation stays on the selected window’s display; pointer selection works on every display.
- The optional hot corner is disabled until selected from the strip’s right-click menu; native gesture and corner settings are saved and restored around app ownership.

## Decisions captured from the user

- Show all connected displays at once, with no display filter.
- Make the hot corner optional.
- Keep performance and freshness equally important. Stream only visible thumbnails, bound capture resolution, and retain cached frames for immediate opening.
- Integrate the overview into Aerospace Tabs.
