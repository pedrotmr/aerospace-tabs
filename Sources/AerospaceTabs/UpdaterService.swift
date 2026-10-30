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
    private var backgroundCheckTask: Task<Void, Never>?
    private var backgroundCheckInterval: TimeInterval?
    private var probeSchedule = UpdateProbeSchedule()
    private var automaticChecksObservation: NSKeyValueObservation?
    var availableUpdateVersion: String? {
        didSet { onUpdateAvailabilityChange?(availableUpdateVersion) }
    }
    var onUpdateAvailabilityChange: ((String?) -> Void)?

    init() {
        let bundle = Bundle.main
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.pedrotmr.AerospaceTabs"
        managedByHomebrew = HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundle.bundleURL
        )

        let userDriverDelegate = UpdaterUserDriverDelegate()
        self.userDriverDelegate = userDriverDelegate
        let updaterDelegate = UpdaterDelegate()
        self.updaterDelegate = updaterDelegate

        if managedByHomebrew {
            let userDriver = HomebrewUserDriver(
                appName: "AeroSpaceTabs",
                updateCommand: "brew upgrade --cask pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs",
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
                startingUpdater: false,
                updaterDelegate: updaterDelegate,
                userDriverDelegate: userDriverDelegate
            )
        }

        updaterDelegate.onUpdateAvailable = { [weak self] item in
            self?.availableUpdateVersion = UpdateAvailabilityPolicy.installableVersion(
                isInformationOnlyUpdate: item.isInformationOnlyUpdate,
                displayVersion: item.displayVersionString
            )
        }
        updaterDelegate.onUpdateUnavailable = { [weak self] in
            self?.availableUpdateVersion = nil
        }
        updaterDelegate.onUpdateCheckFinished = { [weak self] updateCheck, error in
            guard updateCheck == .updateInformation else { return }
            self?.scheduleNextBackgroundCheck(after: error)
        }

        startBackgroundUpdateChecks()
    }

    @objc func installAvailableUpdate(_ sender: Any?) {
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

    private func startBackgroundUpdateChecks() {
        guard let updater = managedByHomebrew ? homebrewUpdater : controller?.updater else { return }

        if managedByHomebrew {
            do {
                try updater.start()
                hasStartedHomebrewUpdater = true
            } catch {
                homebrewUserDriver?.showUpdaterStartError(error)
                return
            }
        } else {
            controller?.startUpdater()
        }

        backgroundCheckInterval = max(updater.updateCheckInterval, 3_600)
        automaticChecksObservation = updater.observe(\.automaticallyChecksForUpdates, options: [.new]) { [weak self] _, change in
            guard let isEnabled = change.newValue else { return }
            Task { @MainActor [weak self] in
                self?.automaticChecksPreferenceDidChange(isEnabled)
            }
        }

        if updater.automaticallyChecksForUpdates {
            checkForUpdateInformation()
        }
    }

    private func automaticChecksPreferenceDidChange(_ isEnabled: Bool) {
        guard backgroundCheckInterval != nil else { return }
        if isEnabled {
            checkForUpdateInformation()
        } else {
            stopBackgroundCheckSchedule()
        }
    }

    private func scheduleNextBackgroundCheck(after error: Error?) {
        guard let backgroundCheckInterval else { return }
        guard let updater = managedByHomebrew ? homebrewUpdater : controller?.updater,
              let delay = probeSchedule.nextInterval(
                after: error,
                normalInterval: backgroundCheckInterval,
                automaticChecksEnabled: updater.automaticallyChecksForUpdates
              ) else {
            stopBackgroundCheckSchedule()
            return
        }
        scheduleBackgroundCheck(after: delay)
    }

    private func scheduleBackgroundCheck(after delay: TimeInterval) {
        guard let updater = managedByHomebrew ? homebrewUpdater : controller?.updater,
              updater.automaticallyChecksForUpdates else {
            stopBackgroundCheckSchedule()
            return
        }
        backgroundCheckTask?.cancel()
        backgroundCheckTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard let self else { return }
            self.checkForUpdateInformation()
        }
    }

    private func checkForUpdateInformation() {
        let updater = managedByHomebrew ? homebrewUpdater : controller?.updater
        guard let updater else { return }
        guard updater.automaticallyChecksForUpdates else {
            stopBackgroundCheckSchedule()
            return
        }
        guard !updater.sessionInProgress else {
            scheduleBackgroundCheck(after: UpdateProbeSchedule.retryInterval)
            return
        }
        updater.checkForUpdateInformation()
    }

    private func stopBackgroundCheckSchedule() {
        backgroundCheckTask?.cancel()
        backgroundCheckTask = nil
        probeSchedule = UpdateProbeSchedule()
    }
}

enum UpdateAvailabilityPolicy {
    static func installableVersion(isInformationOnlyUpdate: Bool, displayVersion: String) -> String? {
        isInformationOnlyUpdate ? nil : displayVersion
    }
}

enum UpdateCheckPolicy {
    static func allows(_ updateCheck: SPUUpdateCheck) -> Bool {
        updateCheck != .updatesInBackground
    }
}

struct UpdateProbeSchedule {
    static let maximumRetries = 3
    static let retryInterval: TimeInterval = 900

    private(set) var consecutiveRetries = 0

    mutating func nextInterval(
        after error: Error?,
        normalInterval: TimeInterval,
        automaticChecksEnabled: Bool
    ) -> TimeInterval? {
        guard automaticChecksEnabled else {
            consecutiveRetries = 0
            return nil
        }

        guard let error, !Self.isNoUpdateError(error) else {
            consecutiveRetries = 0
            return normalInterval
        }

        guard consecutiveRetries < Self.maximumRetries else {
            consecutiveRetries = 0
            return normalInterval
        }

        consecutiveRetries += 1
        return Self.retryInterval
    }

    private static func isNoUpdateError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == SUSparkleErrorDomain && nsError.code == Int(SUError.noUpdateError.rawValue)
    }
}

@MainActor
private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var onUpdateAvailable: ((SUAppcastItem) -> Void)?
    var onUpdateUnavailable: (() -> Void)?
    var onUpdateCheckFinished: ((SPUUpdateCheck, Error?) -> Void)?

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard UpdateCheckPolicy.allows(updateCheck) else {
            throw NSError(
                domain: "AeroSpaceTabs.UpdateService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Scheduled update checks are disabled."]
            )
        }
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        onUpdateAvailable?(item)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        onUpdateUnavailable?()
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        onUpdateCheckFinished?(updateCheck, error)
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
                return .dismiss
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
            return .dismiss
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
