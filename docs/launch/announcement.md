# Aerospace Tabs launch announcement

> Draft for the first public release. Checked on 18 October 2026. GitHub issue [#10](https://github.com/pedrotmr/aerospace-tabs/issues/10) is still open, and no GitHub Release exists yet. Publish only after the release asset is available. Replace `FIRST_RELEASE_URL` and confirm the package and price first. Positioning follows the [project charter](../../CHARTER.md).

## Announcement copy

### Window tabs and a visual overview for AeroSpace

I built Aerospace Tabs as an independent companion app for people who use [AeroSpace](https://github.com/nikitabobko/AeroSpace) on macOS.

AeroSpace tiles your windows. Aerospace Tabs adds a top strip that groups windows from occupied AeroSpace workspaces on each display. Click a tab to focus its window, or drag tabs to set a local order. Open Window Overview to browse previews grouped by workspace across connected displays.

This app works alongside AeroSpace. It does not change AeroSpace's layout tree or manage native macOS Spaces. It requires macOS 14 or later and AeroSpace running.

Accessibility access enables global shortcuts and Dock notification badges. Screen Recording access is optional and enables window previews. The app captures previews only while Window Overview is open and does not save screenshots or videos to disk. Without Screen Recording access, the overview shows app icons.

While it runs, Aerospace Tabs temporarily adds to `gaps.outer.top` so windows clear the strip. It restores that change on a clean quit.

**Download:** `FIRST_RELEASE_URL`

**Source and setup:** [GitHub repository](https://github.com/pedrotmr/aerospace-tabs) · [README](../../README.md)

**License:** MIT

I built this for my own AeroSpace workflow. Feedback and issues are welcome in the [public repository](https://github.com/pedrotmr/aerospace-tabs).

## GIF shot list

Target 12 to 15 seconds. Record the release build with AeroSpace running and use sanitized demo windows. Keep the pointer visible for focus and reorder actions.

| Time | Shot | Capture notes |
| --- | --- | --- |
| 0–2 s | Show the top strip with windows from two occupied workspaces. | Keep workspace numbers and app icons readable. |
| 2–4 s | Click a tab and show its window come to the front. | Hold briefly after the focus change. |
| 4–6 s | Drag a tab to a new position in its workspace. | Keep the drag within one workspace. |
| 6–9 s | Open Window Overview and show previews grouped by workspace. | Show connected displays if available. Use the menu command for a repeatable capture; a three-finger swipe is optional. |
| 9–11 s | Hover to reveal a window title, then use an arrow key and Return to focus it. | Press Escape to close the overview. |
| 11–14 s | End card with the app name, release link, and repository. | Add the release URL after publishing the asset. |

The existing [strip screenshot](../../Screenshots/aerospace-tabs-strip.png) and [disconnected-state screenshot](../../Screenshots/aerospace-tabs-disconnected.png) use synthetic data. They are illustrations, not recordings of a live desktop. Use the release build for the GIF.

## Posting channels

Research checked on 18 October 2026. Recheck each community's current rules before posting.

### 1. AeroSpace GitHub Discussions, General

**Channel:** [General discussions](https://github.com/nikitabobko/AeroSpace/discussions/categories/general)

**Posting guidance:** [AeroSpace's discussion welcome post](https://github.com/nikitabobko/AeroSpace/discussions/618) · [AeroSpace README community section](https://github.com/nikitabobko/AeroSpace/blob/main/README.md#community-discussions-issues)

This is the closest audience. Use **General**, not `announcements` or `announcements-releases`; AeroSpace reserves those categories for maintainers. The project invites people to show their setups and chat, but its published guidance does not set a self-promotion frequency, title format, or link and image restrictions. Introduce yourself as the developer, explain the AeroSpace integration, include one useful screenshot, and invite feedback. An [existing companion-app post](https://github.com/nikitabobko/AeroSpace/discussions/2031) is a useful format example, not maintainer approval.

**Suggested title:** `Aerospace Tabs: window tabs and overview for AeroSpace`

### 2. r/macOS, Developer Saturday

**Channel:** [r/macOS](https://www.reddit.com/r/MacOS/)

**Posting rules:** [Moderator policy for Developer Saturday](https://www.reddit.com/r/MacOS/comments/1rsxzup/new_policy_introducing_developer_saturday/)

Post only on Saturday from 00:00 to 23:59 UTC. Each user may make one promotional post per week. State that you are the developer, explain what the app does, and include a useful screenshot or GIF. The moderators welcome GitHub links and ask developers to stay active in the comments.

**Suggested title:** `I built Aerospace Tabs, an open-source companion for AeroSpace on macOS`

### 3. r/macapps, monthly App Pile

**Channel:** [r/macapps](https://www.reddit.com/r/macapps/) · [October 2026 App Pile example](https://www.reddit.com/r/macapps/comments/1wuoav5/megathread_the_app_pile_october_2026/)

**Posting rules:** [Community rules](https://www.reddit.com/r/macapps/about/rules/) · [Trust and Transparency guidance](https://www.reddit.com/r/macapps/comments/1ryaeex/rmacapps_mods_went_too_far_whats_changing_phase_3/) · [App Pile format](https://www.reddit.com/r/macapps/comments/1wuoav5/megathread_the_app_pile_october_2026/)

Use the current month's App Pile unless the app and account qualify for a main-feed post under the current Trust or Transparency rules. At this check, the repository was about six weeks old with no stars, so it did not meet the repository-age or star-count route by itself. The App Pile asks for **Problem**, **Comparison** with a named alternative, and **Pricing** with amounts for every tier plus an app website link. Do not link directly to a `.zip` or `.dmg`. A screenshot or video is required for top-three consideration. Disclose that you are the developer, verify the Reddit email, earn 10 r/macapps comment karma before posting, and observe the once-per-30-days promotion limit. Promotion in the App Pile counts toward that limit.

For the Comparison field, keep it factual and specific: [AeroTabs](https://github.com/nikitabobko/AeroSpace/discussions/2031) shows tabs for the current workspace; Aerospace Tabs groups occupied workspaces and includes a visual overview. Confirm the exact price before posting. Link the GitHub Release page rather than a binary file.

**Suggested title:** `[OS] Aerospace Tabs`
