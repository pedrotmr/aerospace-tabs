import AppKit
import Sparkle

@MainActor
final class UpdaterService {
    private let userDriverDelegate: UpdaterUserDriverDelegate
    private let controller: SPUStandardUpdaterController

    init() {
        let userDriverDelegate = UpdaterUserDriverDelegate()
        self.userDriverDelegate = userDriverDelegate
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.pedrotmr.AerospaceTabs"
        let managedByHomebrew = HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier)
        controller = SPUStandardUpdaterController(
            startingUpdater: !managedByHomebrew,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )
    }

    @objc func checkForUpdates(_ sender: Any?) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.pedrotmr.AerospaceTabs"
        if HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier) {
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
