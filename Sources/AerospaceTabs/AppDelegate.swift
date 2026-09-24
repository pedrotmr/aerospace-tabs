import AppKit

@main
enum AerospaceTabsMain {
    static func main() {
        if CommandLine.arguments.contains("--restore-gaps") {
            let ok = GapBoost.shared.restoreIfNeeded()
            fputs(ok ? "Restored AeroSpace outer.top\n" : "Nothing to restore\n", stdout)
            return
        }
        // Block SIGTERM/SIGINT before AppKit spins up other threads.
        TerminationGuard.install()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let session = Session()
    private let hotkeys = Hotkeys()
    private let missionControl = MissionControlWatcher()
    private let dockBadgeReader = DockBadgeReader()
    private var strips: [CGDirectDisplayID: TabStrip] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Clear a leftover boost from a previous crash; live boost follows strip visibility in render().
        GapBoost.shared.prepareAtLaunch()
        GapsConfig.shared.start()
        session.onChange = { [weak self] in
            self?.render()
        }
        dockBadgeReader.onChange = { [weak self] in
            self?.render()
        }
        dockBadgeReader.start()
        hotkeys.onStep = { [weak self] cycle, reverse in
            self?.session.stepCycle(cycle, reverse: reverse)
        }
        hotkeys.onCommit = { [weak self] cycle in
            self?.session.commitCycle(cycle)
        }
        missionControl.onChange = { [weak self] _ in
            self?.render()
        }
        hotkeys.install()
        session.start()
        missionControl.start()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: .aerospaceGapsDidChange,
            object: nil
        )
        render()
    }

    func applicationWillTerminate(_ notification: Notification) {
        GapBoost.shared.deactivate()
    }

    @objc private func screensChanged() {
        render()
    }

    private func render() {
        let grouped = Dictionary(grouping: session.windows, by: \.screenIndex)
        let badges = dockBadgeReader.badgesByApp
        var seen: Set<CGDirectDisplayID> = []
        let hidden = missionControl.isActive
        var anyStripVisible = false

        for screen in NSScreen.screens {
            let displayID = screen.displayID
            seen.insert(displayID)
            let screenIndex = screen.aerospaceScreenIndex
            let windows = grouped[screenIndex] ?? []
            let strip = strips[displayID] ?? {
                let created = TabStrip(
                    onPick: { [weak self] id in
                        self?.session.focus(id)
                    },
                    onReorder: { [weak self] ids, workspace in
                        self?.session.reorder(ids: ids, workspace: workspace)
                    },
                    onQuit: {
                        // applicationWillTerminate restores gaps once.
                        NSApp.terminate(nil)
                    }
                )
                strips[displayID] = created
                return created
            }()
            let gaps = GapsConfig.shared.gaps(for: screen)
            // Show an overview when this monitor has at least two occupied windows.
            let showTabs = Self.shouldShowTabs(windows)
            if showTabs { anyStripVisible = true }
            strip.update(
                screen: screen,
                windows: windows,
                focused: session.displayFocusedID,
                hidden: hidden || !showTabs,
                gaps: gaps,
                notificationBadges: badges
            )
        }

        for (id, strip) in strips where !seen.contains(id) {
            strip.close()
            strips.removeValue(forKey: id)
        }

        // Boost follows strip *eligibility*, not chrome visibility. Dropping the
        // boost while Mission Control hides the strip reloads AeroSpace and nudges
        // every tiled window — keep outer.top stable across MC enter/exit.
        GapBoost.shared.sync(
            shouldBoost: Self.shouldBoostGaps(
                anyStripVisible: anyStripVisible,
                missionControlActive: hidden
            )
        )
    }

    /// Strip visibility: two or more windows across this monitor's occupied workspaces.
    private static func shouldShowTabs(_ windows: [Win]) -> Bool {
        windows.count >= 2
    }

    /// Whether AeroSpace `outer.top` should stay boosted for the strip.
    ///
    /// Mission Control only hides chrome; the boost must not toggle with it.
    static func shouldBoostGaps(anyStripVisible: Bool, missionControlActive _: Bool) -> Bool {
        anyStripVisible
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }

    /// 1-based index in `NSScreen.screens`, matching AeroSpace `%{monitor-appkit-nsscreen-screens-id}`.
    var aerospaceScreenIndex: Int {
        (NSScreen.screens.firstIndex(where: { $0.displayID == displayID }) ?? 0) + 1
    }
}
