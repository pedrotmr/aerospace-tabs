import Foundation

enum OverviewHotCorner: String, CaseIterable, Equatable, Hashable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var title: String {
        switch self {
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        }
    }
}

final class OverviewSettings {
    static let shared = OverviewSettings()
    static let didChangeNotification = Notification.Name("AerospaceTabs.overviewSettingsDidChange")

    private enum Key {
        static let hotCorner = "overview.hotCorner"
        static let swipeEnabled = "overview.threeFingerSwipeEnabled"
    }

    private let defaults: UserDefaults

    var hotCorner: OverviewHotCorner? {
        guard let raw = defaults.string(forKey: Key.hotCorner) else { return nil }
        return OverviewHotCorner(rawValue: raw)
    }

    /// Enabled by default to match the overview's primary gesture.
    var swipeEnabled: Bool {
        guard defaults.object(forKey: Key.swipeEnabled) != nil else { return true }
        return defaults.bool(forKey: Key.swipeEnabled)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func select(hotCorner: OverviewHotCorner?) {
        guard hotCorner != self.hotCorner else { return }
        if let hotCorner {
            defaults.set(hotCorner.rawValue, forKey: Key.hotCorner)
        } else {
            defaults.removeObject(forKey: Key.hotCorner)
        }
        postChange()
    }

    func setSwipeEnabled(_ enabled: Bool) {
        guard enabled != swipeEnabled else { return }
        defaults.set(enabled, forKey: Key.swipeEnabled)
        postChange()
    }

    private func postChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
