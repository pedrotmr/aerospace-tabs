# AeroSpace Goodies entry

Draft for submission to `nikitabobko/AeroSpace` after the v0.1.1 release is public.

## Proposed placement

Insert immediately before the existing `[#spacelist]` section in `docs/goodies.adoc`, beside the standalone window-finding tools and before `[#popular-apps-ids]`.

## Exact AsciiDoc snippet

```adoc
[#aerospace-tabs]
== Aerospace Tabs

https://github.com/pedrotmr/aerospace-tabs - macOS 14+ companion app with a window tab strip and a visual overview grouped by AeroSpace workspace. Requires Accessibility; Screen Recording is optional for window previews. Temporarily increases AeroSpace's `gaps.outer.top` while running and restores it on quit.
```

## Proposed upstream commit message

```text
goodies: Add Aerospace Tabs to the Goodies page

List the released companion with a factual summary of its window views,
permission requirements, and temporary gaps.outer.top adjustment.
```

## Preconditions before sending the upstream PR

- Publish the current v0.1.1 draft release and verify the public release page and `AerospaceTabs.zip` are available. As of 2026-10-20, GitHub reports the release as a draft; the ZIP is attached.
- Complete [issue #10's release gate](https://github.com/pedrotmr/aerospace-tabs/issues/10): verify a stranger can install and run the archive with AeroSpace on macOS 14+, and that the install or release notes disclose required Accessibility, optional Screen Recording for previews, and `gaps.outer.top` restoration. [Issue #8](https://github.com/pedrotmr/aerospace-tabs/issues/8) is closed, clearing #10's stated blocker.
- Keep remote history alignment separate from this submission; issue #10 permits a force-push only if the maintainer explicitly requests it.
