import Foundation

/// Window state shared by the strip and overview, without AppKit dependencies.
public struct Win: Equatable {
    public let id: Int
    public let title: String
    public let appName: String
    public let bundleID: String
    public let bundlePath: String
    public let workspace: String
    public let workspaceIsFocused: Bool
    public let workspaceIsVisible: Bool
    public let screenIndex: Int
    /// AeroSpace parent layout: h_tiles, v_tiles, h_accordion, v_accordion, floating.
    public let parentLayout: String

    public init(
        id: Int,
        title: String,
        appName: String,
        bundleID: String,
        bundlePath: String,
        workspace: String,
        screenIndex: Int,
        parentLayout: String,
        workspaceIsFocused: Bool = false,
        workspaceIsVisible: Bool = false
    ) {
        self.id = id
        self.title = title
        self.appName = appName
        self.bundleID = bundleID
        self.bundlePath = bundlePath
        self.workspace = workspace
        self.screenIndex = screenIndex
        self.parentLayout = parentLayout
        self.workspaceIsFocused = workspaceIsFocused
        self.workspaceIsVisible = workspaceIsVisible
    }

    public var label: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appName : trimmed
    }

    public var isAccordion: Bool {
        parentLayout.contains("accordion")
    }

    public var isTiles: Bool {
        parentLayout.contains("tiles")
    }
}

/// Value-only input to Mission Control detection so tests need no live window list.
public struct MissionControlWindowInfo {
    public let owner: String
    public let name: String
    public let layer: Int
    public let width: CGFloat
    public let height: CGFloat

    public init(owner: String, name: String, layer: Int, width: CGFloat, height: CGFloat) {
        self.owner = owner
        self.name = name
        self.layer = layer
        self.width = width
        self.height = height
    }
}

/// Pure workspace and window decisions used by the AppKit companion.
public enum SessionPolicy {
    public static func shouldShowTabs(_ windows: [Win]) -> Bool {
        windows.count >= 2
    }

    /// Keep outer.top clear for eligible strips and the disconnected-state banner.
    public static func shouldBoostGaps(
        windowsByScreen: [[Win]],
        connectionStatusVisible: Bool = false
    ) -> Bool {
        connectionStatusVisible || windowsByScreen.contains(where: shouldShowTabs)
    }

    public static func focusedWorkspaceName(
        windows: [Win],
        focusedID: Int?,
        fallbackWorkspace: String?
    ) -> String? {
        windows.first(where: { $0.id == focusedID })?.workspace
            ?? fallbackWorkspace
            ?? windows.first(where: \.workspaceIsFocused)?.workspace
    }

    public static func cyclePool(windows: [Win], focusedID: Int?) -> [Win] {
        guard let focusedWindow = windows.first(where: { $0.id == focusedID }) else {
            return windows.filter(\.workspaceIsFocused)
        }
        return windows.filter {
            $0.screenIndex == focusedWindow.screenIndex
                && $0.workspace == focusedWindow.workspace
        }
    }

    public static func spaceCyclePool(
        windows: [Win],
        focusedID: Int?,
        focusedScreenIndex: Int?
    ) -> [String] {
        let screenIndex = windows.first(where: { $0.id == focusedID })?.screenIndex
            ?? focusedScreenIndex
            ?? windows.first(where: \.workspaceIsFocused)?.screenIndex
        guard let screenIndex else { return [] }

        var workspaces: [String] = []
        var seen: Set<String> = []
        for window in windows where window.screenIndex == screenIndex {
            if seen.insert(window.workspace).inserted {
                workspaces.append(window.workspace)
            }
        }
        return workspaces
    }

    /// Sort numeric spaces first, then named spaces in first-seen order.
    /// Each workspace retains its saved tab order and appends new windows.
    public static func applyTabOrder(_ windows: [Win], preferredIDsByWorkspace: [String: [Int]]) -> [Win] {
        guard !windows.isEmpty else { return windows }

        let grouped = Dictionary(grouping: windows, by: \.workspace)
        var seenWorkspaces: [String] = []
        var seenWorkspaceSet: Set<String> = []
        for window in windows {
            if seenWorkspaceSet.insert(window.workspace).inserted {
                seenWorkspaces.append(window.workspace)
            }
        }

        let firstSeenIndex = Dictionary(
            uniqueKeysWithValues: seenWorkspaces.enumerated().map { ($0.element, $0.offset) }
        )
        seenWorkspaces.sort { lhs, rhs in
            let lhsNumber = Int(lhs)
            let rhsNumber = Int(rhs)
            switch (lhsNumber, rhsNumber) {
            case let (.some(left), .some(right)) where left != right:
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return firstSeenIndex[lhs, default: 0] < firstSeenIndex[rhs, default: 0]
            }
        }

        return seenWorkspaces.flatMap { workspace in
            order(grouped[workspace] ?? [], preferredIDs: preferredIDsByWorkspace[workspace] ?? [])
        }
    }

    private static func order(_ windows: [Win], preferredIDs: [Int]) -> [Win] {
        guard !preferredIDs.isEmpty else { return windows }

        var remaining = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        var ordered: [Win] = []
        ordered.reserveCapacity(windows.count)
        for id in preferredIDs {
            if let window = remaining.removeValue(forKey: id) {
                ordered.append(window)
            }
        }
        for window in windows {
            if remaining.removeValue(forKey: window.id) != nil {
                ordered.append(window)
            }
        }
        return ordered
    }
}

/// Debounces Mission Control detection before hiding the tab strip.
public struct MissionControlDebouncer {
    /// Active space checks run every 0.15s; three detections retain the ~0.45s entry delay.
    private let detectionsNeededToActivate = 3
    private var consecutiveDetectionCount = 0
    public private(set) var isActive = false

    public init() {}

    /// Returns a state change when one occurs. Entry requires three consecutive hits;
    /// a miss resets the entry streak and clears an active state immediately.
    public mutating func update(detected: Bool) -> Bool? {
        if detected {
            consecutiveDetectionCount = min(consecutiveDetectionCount + 1, detectionsNeededToActivate)
        } else {
            consecutiveDetectionCount = 0
        }

        let next = isActive ? detected : (consecutiveDetectionCount >= detectionsNeededToActivate)
        guard next != isActive else { return nil }
        isActive = next
        return next
    }
}

/// Pure Mission Control / App Exposé classification over captured window values.
public enum MissionControlPolicy {
    public static func detect(windows: [MissionControlWindowInfo], screenSizes: [CGSize]) -> Bool {
        var dockExposeLayers: Set<Int> = []
        let activityNames: Set<String> = ["Mission Control", "Window Switcher", "App Exposé"]
        let systemUIOwners: Set<String> = ["Dock", "WindowManager", "Mission Control"]

        for window in windows {
            if window.owner == "Mission Control"
                || systemUIOwners.contains(window.owner) && activityNames.contains(window.name)
            {
                return true
            }

            let coversScreen = screenSizes.contains { size in
                window.width >= size.width * 0.95 && window.height >= size.height * 0.95
            }

            // Newer macOS: exposé surface owned by WindowManager.
            if window.owner == "WindowManager", (16...19).contains(window.layer), coversScreen {
                return true
            }

            guard window.owner == "Dock", window.name.isEmpty else { continue }
            if window.layer == 18, coversScreen {
                return true
            }
            if (18...20).contains(window.layer), coversScreen || window.height > 120 {
                dockExposeLayers.insert(window.layer)
            }
        }

        return dockExposeLayers.contains(18) && dockExposeLayers.count >= 2
    }
}
