import AppKit
import CoreGraphics

struct MissionControlWindowInfo {
    let owner: String
    let name: String
    let layer: Int
    let width: CGFloat
    let height: CGFloat
}

/// Hides overlays while Mission Control / App Exposé is up.
///
/// Dock layer 20 alone is never Mission Control — macOS uses that same
/// fullscreen Dock window for an always-visible Dock *and* for a hover
/// reveal when auto-hide is on. Keying off it (even only when autohide is
/// enabled) hides the strip whenever the Dock appears.
final class MissionControlWatcher {
    var onChange: ((Bool) -> Void)?
    private(set) var isActive = false
    private var timer: Timer?
    private var hitStreak = 0
    /// ~0.45s at 0.15s poll — ignores brief Dock reveal animations.
    private let hitsNeeded = 3

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(check),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.check()
        }
        timer?.tolerance = 0.05
        check()
    }

    @objc private func check() {
        let raw = Self.detect()
        if raw {
            hitStreak = min(hitStreak + 1, hitsNeeded)
        } else {
            hitStreak = 0
        }
        let next = isActive ? raw : (hitStreak >= hitsNeeded)
        guard next != isActive else { return }
        isActive = next
        onChange?(next)
    }

    private static func detect() -> Bool {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        let screenSizes = NSScreen.screens.map(\.frame.size)
        let windows = info.map { window in
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            return MissionControlWindowInfo(
                owner: window[kCGWindowOwnerName as String] as? String ?? "",
                name: window[kCGWindowName as String] as? String ?? "",
                layer: window[kCGWindowLayer as String] as? Int ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
        }
        return detect(windows: windows, screenSizes: screenSizes)
    }

    static func detect(windows: [MissionControlWindowInfo], screenSizes: [CGSize]) -> Bool {
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

            // Fullscreen layer 18 is the exposé surface — not used by a normal Dock.
            if window.layer == 18, coversScreen {
                return true
            }

            // Collect Dock expose-ish layers; MC often shows 18 + 20 together.
            // Layer 20 alone (always-visible Dock or hover reveal) must not win.
            if (18...20).contains(window.layer), coversScreen || window.height > 120 {
                dockExposeLayers.insert(window.layer)
            }
        }

        return dockExposeLayers.contains(18) && dockExposeLayers.count >= 2
    }
}
