import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AerospaceMenuActions {
    static let shared = AerospaceMenuActions()
    static let aerospaceBundleIdentifier = "bobko.aerospace"

    private enum Key {
        static let editorPath = "aerospace.configEditor.path"
        static let editorBundleIdentifier = "aerospace.configEditor.bundleIdentifier"
    }

    private let defaults: UserDefaults
    private let workspace: NSWorkspace
    private var runningProcesses: [Process] = []

    init(defaults: UserDefaults = .standard, workspace: NSWorkspace = .shared) {
        self.defaults = defaults
        self.workspace = workspace
    }

    var selectedEditorName: String? {
        guard let editor = selectedEditor() else { return nil }
        return editor.name
    }

    func reloadConfig() {
        let process = Process()
        process.executableURL = AerospaceClient.binaryURL
        process.arguments = ["reload-config"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                guard let self else { return }
                self.runningProcesses.removeAll { $0 === process }
                if status != 0 {
                    self.showError(
                        title: "Could Not Reload Config",
                        message: "AeroSpace could not reload its config. Check the config error shown by AeroSpace."
                    )
                }
            }
        }

        do {
            try process.run()
            runningProcesses.append(process)
        } catch {
            showError(title: "Could Not Reload Config", message: error.localizedDescription)
        }
    }

    func openConfig() {
        let configURL = AerospaceConfigLocator.shared.location().configURL
        guard FileManager.default.isReadableFile(atPath: configURL.path) else {
            showError(
                title: "Could Not Find Config",
                message: "The AeroSpace config file is not readable at \(configURL.path)."
            )
            return
        }

        guard let editor = selectedEditor() else {
            selectEditor(openConfigAfterSelection: true)
            return
        }
        open(configURL, in: editor.url)
    }

    func chooseEditor() {
        selectEditor(openConfigAfterSelection: false)
    }

    func quitAerospace() {
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.aerospaceBundleIdentifier
        ).first else {
            return
        }
        guard application.terminate() else {
            showError(title: "Could Not Quit AeroSpace", message: "AeroSpace did not accept the quit request.")
            return
        }

        // The companion should not remain active after the window manager quits.
        // Restore our temporary gap change without reloading a config that is exiting.
        GapBoost.shared.restoreIfNeeded(reload: false)
        NSApp.terminate(nil)
    }

    private func selectEditor(openConfigAfterSelection: Bool) {
        let panel = NSOpenPanel()
        panel.title = "Choose Config Editor"
        panel.message = "Choose the app to open your AeroSpace config. This choice is saved for next time."
        panel.prompt = "Choose Editor"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false

        guard panel.runModal() == .OK, let appURL = panel.url,
              let bundle = Bundle(url: appURL),
              let bundleIdentifier = bundle.bundleIdentifier
        else { return }

        defaults.set(appURL.path, forKey: Key.editorPath)
        defaults.set(bundleIdentifier, forKey: Key.editorBundleIdentifier)

        if openConfigAfterSelection {
            openConfig()
        }
    }

    private func selectedEditor() -> (url: URL, name: String)? {
        if let path = defaults.string(forKey: Key.editorPath) {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path), let bundle = Bundle(url: url) {
                return (url, Self.displayName(for: url, bundle: bundle))
            }
        }

        if let bundleIdentifier = defaults.string(forKey: Key.editorBundleIdentifier),
           let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let bundle = Bundle(url: url)
        {
            defaults.set(url.path, forKey: Key.editorPath)
            let name = Self.displayName(for: url, bundle: bundle)
            return (url, name)
        }

        return nil
    }

    private func open(_ fileURL: URL, in applicationURL: URL) {
        workspace.open(
            [fileURL],
            withApplicationAt: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { [weak self] _, error in
            guard let error else { return }
            let message = error.localizedDescription
            DispatchQueue.main.async {
                self?.showError(title: "Could Not Open Config", message: message)
            }
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private static func displayName(for url: URL, bundle: Bundle) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
    }
}
