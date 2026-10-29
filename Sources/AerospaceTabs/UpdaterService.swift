import AppKit
import Sparkle

@MainActor
final class UpdaterService {
    private let userDriverDelegate: UpdaterUserDriverDelegate
    private let updaterDelegate: UpdaterDelegate
    private let controller: SPUStandardUpdaterController?
    private let homebrewUpdater: SPUUpdater?
    private let homebrewUserDriver: HomebrewUserDriver?
    private let managedByHomebrew: Bool
    private var hasStartedHomebrewUpdater = false

    init() {
        let bundle = Bundle.main
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.pedrotmr.AerospaceTabs"
        managedByHomebrew = HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundle.bundleURL
        )

        let userDriverDelegate = UpdaterUserDriverDelegate()
        self.userDriverDelegate = userDriverDelegate
        let updaterDelegate = UpdaterDelegate(managedByHomebrew: managedByHomebrew)
        self.updaterDelegate = updaterDelegate

        if managedByHomebrew {
            let userDriver = HomebrewUserDriver(
                appName: "AeroSpaceTabs",
                updateCommand: "brew update && brew upgrade --cask --greedy-auto-updates pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs",
                hostBundle: bundle,
                delegate: userDriverDelegate
            )
            homebrewUserDriver = userDriver
            homebrewUpdater = SPUUpdater(
                hostBundle: bundle,
                applicationBundle: bundle,
                userDriver: userDriver,
                delegate: updaterDelegate
            )
            controller = nil
        } else {
            homebrewUserDriver = nil
            homebrewUpdater = nil
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: updaterDelegate,
                userDriverDelegate: userDriverDelegate
            )
        }
    }

    @objc func checkForUpdates(_ sender: Any?) {
        guard managedByHomebrew else {
            controller?.checkForUpdates(sender)
            return
        }

        guard let updater = homebrewUpdater else { return }
        if !hasStartedHomebrewUpdater {
            do {
                try updater.start()
                hasStartedHomebrewUpdater = true
            } catch {
                homebrewUserDriver?.showUpdaterStartError(error)
                return
            }
        }

        updater.checkForUpdates()
    }
}

enum HomebrewUpdateCheckPolicy {
    static func allows(_ updateCheck: SPUUpdateCheck, managedByHomebrew: Bool) -> Bool {
        !managedByHomebrew || updateCheck != .updatesInBackground
    }
}

@MainActor
private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    private let managedByHomebrew: Bool

    init(managedByHomebrew: Bool) {
        self.managedByHomebrew = managedByHomebrew
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard HomebrewUpdateCheckPolicy.allows(updateCheck, managedByHomebrew: managedByHomebrew) else {
            throw NSError(
                domain: "AeroSpaceTabs.UpdateService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Scheduled update checks are disabled for Homebrew installations."]
            )
        }
    }
}

@MainActor
private final class HomebrewUserDriver: SPUStandardUserDriver {
    private let appName: String
    private let updateCommand: String

    init(
        appName: String,
        updateCommand: String,
        hostBundle: Bundle,
        delegate: SPUStandardUserDriverDelegate
    ) {
        self.appName = appName
        self.updateCommand = updateCommand
        super.init(hostBundle: hostBundle, delegate: delegate)
    }

    override func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        // Show UI only when an update is available or the check fails.
    }

    override func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState
    ) async -> SPUUserUpdateChoice {
        let alert = NSAlert()
        if appcastItem.isInformationOnlyUpdate {
            alert.messageText = "More information is available for \(appName)"
            alert.informativeText = "Version \(appcastItem.displayVersionString) has release information but cannot be installed in the app."
            alert.addButton(withTitle: "Open Release Notes")
            alert.addButton(withTitle: "Copy Homebrew Command")
            alert.addButton(withTitle: "Cancel")

            switch present(alert) {
            case .alertFirstButtonReturn:
                if let infoURL = appcastItem.infoURL {
                    NSWorkspace.shared.open(infoURL)
                }
                return .dismiss
            case .alertSecondButtonReturn:
                copyHomebrewCommand()
                return .skip
            default:
                return cancellationChoice(for: state)
            }
        }

        alert.messageText = "An update is available for \(appName)"
        alert.informativeText = "Version \(appcastItem.displayVersionString) is available. Choose how to update this Homebrew installation."
        alert.addButton(withTitle: "Update in App")
        alert.addButton(withTitle: "Copy Homebrew Command")
        alert.addButton(withTitle: "Cancel")

        switch present(alert) {
        case .alertFirstButtonReturn:
            return .install
        case .alertSecondButtonReturn:
            copyHomebrewCommand()
            return .skip
        default:
            return cancellationChoice(for: state)
        }
    }

    override func showUpdateNotFoundWithError(_ error: Error) async {
        // Homebrew checks stay quiet when there is no compatible update.
    }

    override func showUpdaterError(_ error: Error) async {
        showHomebrewFallbackAlert(
            title: "The update could not be completed for \(appName)",
            error: error
        )
    }

    func showUpdaterStartError(_ error: Error) {
        showHomebrewFallbackAlert(title: "Could not check for updates for \(appName)", error: error)
    }

    private func showHomebrewFallbackAlert(title: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "\(error.localizedDescription)\n\nYou can update with Homebrew instead."
        alert.addButton(withTitle: "Copy Homebrew Command")
        alert.addButton(withTitle: "Cancel")

        if present(alert) == .alertFirstButtonReturn {
            copyHomebrewCommand()
        }
    }

    private func cancellationChoice(for state: SPUUserUpdateState) -> SPUUserUpdateChoice {
        state.stage == .installing ? .skip : .dismiss
    }

    private func copyHomebrewCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(updateCommand, forType: .string)
    }

    private func present(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
}

@MainActor
private final class UpdaterUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
