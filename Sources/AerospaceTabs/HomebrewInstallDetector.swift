import Foundation

enum HomebrewInstallDetector {
    static let markerKey = "managedByHomebrew"
    static let versionKey = "managedByHomebrewVersion"
    static let bundlePathKey = "managedByHomebrewBundlePath"

    static func preferencesDomain(for bundleIdentifier: String) -> String {
        "\(bundleIdentifier).homebrew"
    }

    static func isManagedByHomebrew(
        bundleIdentifier: String,
        installedVersion: String,
        bundleURL: URL,
        defaults: UserDefaults? = nil
    ) -> Bool {
        let preferences = defaults ?? UserDefaults(suiteName: preferencesDomain(for: bundleIdentifier))
        let installedBundlePath = bundleURL.standardizedFileURL.resolvingSymlinksInPath().path
        let managedBundlePath = preferences?.string(forKey: bundlePathKey).map {
            URL(fileURLWithPath: $0).standardizedFileURL.resolvingSymlinksInPath().path
        }
        return preferences?.bool(forKey: markerKey) == true
            && preferences?.string(forKey: versionKey) == installedVersion
            && managedBundlePath == installedBundlePath
    }
}
