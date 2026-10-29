import AppKit
import Sparkle

@MainActor
final class UpdaterService {
    private let userDriverDelegate: UpdaterUserDriverDelegate
    private let updaterDelegate: UpdaterDelegate
    private let controller: SPUStandardUpdaterController
    private let managedByHomebrew: Bool

    init() {
        let userDriverDelegate = UpdaterUserDriverDelegate()
        self.userDriverDelegate = userDriverDelegate
        let bundle = Bundle.main
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.pedrotmr.AerospaceTabs"
        managedByHomebrew = HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundle.bundleURL
        )
        let updaterDelegate = UpdaterDelegate(
            appName: "AeroSpaceTabs",
            updateCommand: "brew update && brew upgrade --cask --greedy-auto-updates pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs",
            managedByHomebrew: managedByHomebrew
        )
        self.updaterDelegate = updaterDelegate
        controller = SPUStandardUpdaterController(
            startingUpdater: !managedByHomebrew,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: userDriverDelegate
        )
        updaterDelegate.onChooseInAppUpdate = { [weak self] in
            DispatchQueue.main.async {
                self?.controller.checkForUpdates(nil)
            }
        }
    }

    @objc func checkForUpdates(_ sender: Any?) {
        if managedByHomebrew {
            controller.updater.automaticallyChecksForUpdates = false
            updaterDelegate.beginHomebrewProbe()
            controller.startUpdater()
            controller.updater.checkForUpdateInformation()
            return
        }
        controller.checkForUpdates(sender)
    }
}

@MainActor
private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var onChooseInAppUpdate: (() -> Void)?
    private let appName: String
    private let updateCommand: String
    private let managedByHomebrew: Bool
    private var isProbingHomebrewFeed = false
    private var shouldStartInAppUpdate = false

    init(appName: String, updateCommand: String, managedByHomebrew: Bool) {
        self.appName = appName
        self.updateCommand = updateCommand
        self.managedByHomebrew = managedByHomebrew
    }

    func beginHomebrewProbe() {
        isProbingHomebrewFeed = true
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        guard managedByHomebrew, isProbingHomebrewFeed else { return }

        let alert = NSAlert()
        alert.messageText = "An update is available for \(appName)"
        alert.informativeText = "Version \(item.displayVersionString) is available. Choose how to update this Homebrew installation."
        alert.addButton(withTitle: "Update in App")
        alert.addButton(withTitle: "Copy Homebrew Command")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            shouldStartInAppUpdate = true
        case .alertSecondButtonReturn:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(updateCommand, forType: .string)
        default:
            break
        }
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        guard managedByHomebrew else { return }
        isProbingHomebrewFeed = false
        guard shouldStartInAppUpdate else { return }
        shouldStartInAppUpdate = false
        onChooseInAppUpdate?()
    }
}

@MainActor
private final class UpdaterUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
