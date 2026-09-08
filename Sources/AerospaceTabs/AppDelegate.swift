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
    private var strips: [CGDirectDisplayID: TabStrip] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        GapBoost.shared.activate()
        GapsConfig.shared.start()
        session.onChange = { [weak self] in
            self?.render()
        }
        hotkeys.onStep = { [weak self] reverse in
            self?.session.stepCycle(reverse: reverse)
        }
        hotkeys.onCommit = { [weak self] in
            self?.session.commitCycle()
        }
        missionControl.onChange = { [weak self] active in
            self?.applyMissionControl(hidden: active)
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

    private func applyMissionControl(hidden: Bool) {
        for strip in strips.values {
            strip.setHidden(hidden)
        }
    }

    private func render() {
        let grouped = Dictionary(grouping: session.windows, by: \.screenIndex)
        var seen: Set<CGDirectDisplayID> = []
        let hidden = missionControl.isActive

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
                        GapBoost.shared.deactivate()
                        NSApp.terminate(nil)
                    }
                )
                strips[displayID] = created
                return created
            }()
            let gaps = GapsConfig.shared.gaps(for: screen)
            // Only show for accordion stacks with 2+ windows (one visible at a time).
            // Hide for empty spaces, single windows, and tiles (side-by-side / both visible).
            let showTabs = Self.shouldShowTabs(windows)
            strip.update(
                screen: screen,
                windows: windows,
                focused: session.displayFocusedID,
                hidden: hidden || !showTabs,
                gaps: gaps
            )
        }

        for (id, strip) in strips where !seen.contains(id) {
            strip.close()
            strips.removeValue(forKey: id)
        }
    }

    /// Accordion = stacked, one window visible. Tiles = side-by-side / both visible.
    private static func shouldShowTabs(_ windows: [Win]) -> Bool {
        guard windows.count >= 2 else { return false }
        if windows.contains(where: \.isTiles) { return false }
        return windows.contains(where: \.isAccordion)
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
