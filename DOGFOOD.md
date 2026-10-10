# Reliability dogfood checklist

Use this checklist during the Reliability dogfood week. Record failures with the macOS and AeroSpace versions, steps to reproduce, and whether restarting either app changes the result. Keep the Reliability gate open until the week and maintainer signoff are complete.

**Run:** ____________________  
**macOS:** ____________________  
**AeroSpace:** ____________________  
**Maintainer:** ____________________

## Daily reliability

- [ ] For one week, the strip stays visible when expected and does not vanish spuriously.
- [ ] With two or more tiled windows on a display, the strip appears; with zero or one, it hides.
- [ ] Tabs remain legible, do not clip, and stay aligned with the configured outer gaps during ordinary workspace changes.
- [ ] No recurring flicker or focus loss during normal use.

## Recovery and system behavior

- [ ] A clean app quit restores the previous `gaps.outer.top` value.
- [ ] After force-quitting the app, the next launch restores the saved gap; the documented manual restore command also works.
- [ ] Native Mission Control and Dock Exposé do not get mistaken for ordinary windows, and the strip returns afterward.
- [ ] Option-Tab cycles windows in the focused workspace and stops when the key is released.
- [ ] On two connected displays, each strip follows its display and workspace changes without stale tabs.

## Signoff

- [ ] Maintainer reviewed the observations and accepts the Reliability gate.

**Notes / issues filed:**

____________________________________________________________________

____________________________________________________________________
