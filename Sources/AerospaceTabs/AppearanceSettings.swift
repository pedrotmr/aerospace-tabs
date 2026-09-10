import Foundation

/// Persisted strip appearance. All strips observe `didChangeNotification`.
final class AppearanceSettings {
    static let shared = AppearanceSettings()
    static let didChangeNotification = Notification.Name("AerospaceTabs.appearanceDidChange")
    static let themeDefaultsKey = "appearance.theme"

    private let defaults: UserDefaults

    private(set) var theme: StripTheme

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.themeDefaultsKey),
           let saved = StripTheme(rawValue: raw)
        {
            theme = saved
        } else {
            theme = .glass
        }
    }

    func select(_ theme: StripTheme) {
        guard theme != self.theme else { return }
        self.theme = theme
        defaults.set(theme.rawValue, forKey: Self.themeDefaultsKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
