import Foundation

enum HomebrewInstallDetector {
    static let markerKey = "managedByHomebrew"
    static let versionKey = "managedByHomebrewVersion"

    static func preferencesDomain(for bundleIdentifier: String) -> String {
        "\(bundleIdentifier).homebrew"
    }

    static func isManagedByHomebrew(
        bundleIdentifier: String,
        installedVersion: String,
        defaults: UserDefaults? = nil
    ) -> Bool {
        let preferences = defaults ?? UserDefaults(suiteName: preferencesDomain(for: bundleIdentifier))
        return preferences?.bool(forKey: markerKey) == true
            && preferences?.string(forKey: versionKey) == installedVersion
    }
}
