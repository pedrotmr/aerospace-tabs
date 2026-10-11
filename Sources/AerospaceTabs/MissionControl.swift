import AppKit
import CoreGraphics
import SessionPolicy

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
        return MissionControlPolicy.detect(windows: windows, screenSizes: screenSizes)
    }
}
