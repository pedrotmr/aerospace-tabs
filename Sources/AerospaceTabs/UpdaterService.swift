import AppKit
import Sparkle

@MainActor
final class UpdaterService {
    private let userDriverDelegate: UpdaterUserDriverDelegate
    private let controller: SPUStandardUpdaterController
    private let managedByHomebrew: Bool

    init() {
        let userDriverDelegate = UpdaterUserDriverDelegate()
        self.userDriverDelegate = userDriverDelegate
        let bundle = Bundle.main
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.pedrotmr.AerospaceTabs"
        let installedVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        managedByHomebrew = HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: installedVersion
        )
        controller = SPUStandardUpdaterController(
            startingUpdater: !managedByHomebrew,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )
    }

    @objc func checkForUpdates(_ sender: Any?) {
        if managedByHomebrew {
            let alert = NSAlert()
            alert.messageText = "Updates are managed by Homebrew"
            alert.informativeText = "Run `brew update && brew upgrade` to update Aerospace Tabs."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        controller.checkForUpdates(sender)
    }
}

@MainActor
private final class UpdaterUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
