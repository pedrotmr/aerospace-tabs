import Foundation

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

/// Debounces Mission Control detection before hiding the tab strip.
public struct MissionControlDebouncer {
    /// Active space checks run every 0.15s; three detections retain the ~0.45s entry delay.
    private static let detectionsNeededToActivate = 3
    private var consecutiveDetectionCount = 0
    public private(set) var isActive = false

    public init() {}

    /// Returns a state change when one occurs. Entry requires three consecutive hits;
    /// a miss resets the entry streak and clears an active state immediately.
    public mutating func update(detected: Bool) -> Bool? {
        if detected {
            consecutiveDetectionCount = min(consecutiveDetectionCount + 1, Self.detectionsNeededToActivate)
        } else {
            consecutiveDetectionCount = 0
        }

        let next = isActive ? detected : (consecutiveDetectionCount >= Self.detectionsNeededToActivate)
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
