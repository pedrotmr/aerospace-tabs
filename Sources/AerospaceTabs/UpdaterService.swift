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
            installedVersion: installedVersion,
            bundleURL: bundle.bundleURL
        )
        controller = SPUStandardUpdaterController(
            startingUpdater: !managedByHomebrew,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )
    }

    @objc func checkForUpdates(_ sender: Any?) {
        if managedByHomebrew {
            let updateCommand = "brew update && brew upgrade --cask --greedy-auto-updates pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs"
            let alert = NSAlert()
            alert.messageText = "Updates are managed by Homebrew"
            alert.informativeText = "To update AeroSpaceTabs, copy and run this command in Terminal:\n\n\(updateCommand)"
            alert.addButton(withTitle: "Copy Command")
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(updateCommand, forType: .string)
            }
            return
        }
        controller.checkForUpdates(sender)
    }
}

@MainActor
private final class UpdaterUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
