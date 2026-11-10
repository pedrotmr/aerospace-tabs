import AppKit
import ApplicationServices

final class TabStripContextMenu: NSObject {
    private let onOpenOverview: () -> Void
    private let availableUpdateVersion: () -> String?
    private let onInstallAvailableUpdate: () -> Void
    private let onToggleSwipe: () -> Void
    private let isSwipeAvailable: () -> Bool
    private let onQuit: () -> Void

    init(
        onOpenOverview: @escaping () -> Void,
        availableUpdateVersion: @escaping () -> String?,
        onInstallAvailableUpdate: @escaping () -> Void,
        onToggleSwipe: @escaping () -> Void,
        isSwipeAvailable: @escaping () -> Bool,
        onQuit: @escaping () -> Void
    ) {
        self.onOpenOverview = onOpenOverview
        self.availableUpdateVersion = availableUpdateVersion
        self.onInstallAvailableUpdate = onInstallAvailableUpdate
        self.onToggleSwipe = onToggleSwipe
        self.isSwipeAvailable = isSwipeAvailable
        self.onQuit = onQuit
    }

    @MainActor
    func show(for view: NSView, event: NSEvent) {
        let menu = NSMenu()
        let overviewItem = menu.addItem(
            withTitle: "Open Window Overview",
            action: #selector(openOverview),
            keyEquivalent: ""
        )
        overviewItem.target = self

        let activation = NSMenu(title: "Activation")
        let swipeEnabled = OverviewSettings.shared.swipeEnabled
        let swipeAvailable = !swipeEnabled || isSwipeAvailable()
        let swipe = activation.addItem(
            withTitle: swipeAvailable ? "Three-Finger Swipe" : "Three-Finger Swipe (Waiting for Trackpad)",
            action: #selector(toggleThreeFingerSwipe),
            keyEquivalent: ""
        )
        swipe.target = self
        swipe.state = swipeEnabled ? .on : .off
        swipe.toolTip = "Swipe up to open the overview and down to close it. Temporarily replaces the macOS Mission Control swipe."

        let cornerMenu = NSMenu(title: "Hot Corner")
        let selectedCorner = OverviewSettings.shared.hotCorner
        let off = cornerMenu.addItem(
            withTitle: "Off",
            action: #selector(selectHotCorner(_:)),
            keyEquivalent: ""
        )
        off.target = self
        off.representedObject = "off"
        off.state = selectedCorner == nil ? .on : .off
        cornerMenu.addItem(.separator())
        for corner in OverviewHotCorner.allCases {
            let item = cornerMenu.addItem(
                withTitle: corner.title,
                action: #selector(selectHotCorner(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = corner.rawValue
            item.state = corner == selectedCorner ? .on : .off
        }
        let cornerItem = activation.addItem(withTitle: "Hot Corner", action: nil, keyEquivalent: "")
        cornerItem.toolTip = "AeroSpaceTabs restores the selected macOS corner when the app quits."
        activation.setSubmenu(cornerMenu, for: cornerItem)
        let activationItem = menu.addItem(withTitle: "Activation", action: nil, keyEquivalent: "")
        menu.setSubmenu(activation, for: activationItem)
        menu.addItem(.separator())

        let appearance = NSMenu(title: "Appearance")
        let selectedTheme = AppearanceSettings.shared.theme
        for theme in StripTheme.allCases {
            let item = appearance.addItem(
                withTitle: theme.title,
                action: #selector(selectTheme(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = theme.rawValue
            item.state = theme == selectedTheme ? .on : .off
        }
        let appearanceItem = menu.addItem(withTitle: "Appearance", action: nil, keyEquivalent: "")
        menu.setSubmenu(appearance, for: appearanceItem)

        if !AXIsProcessTrusted() {
            let accessibility = NSMenu(title: "Accessibility")
            let explanation = accessibility.addItem(
                withTitle: "Notification Badges Need Accessibility Access",
                action: nil,
                keyEquivalent: ""
            )
            explanation.isEnabled = false
            let settings = accessibility.addItem(
                withTitle: "Open Accessibility Settings…",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            settings.target = self
            let accessibilityItem = menu.addItem(withTitle: "Accessibility", action: nil, keyEquivalent: "")
            menu.setSubmenu(accessibility, for: accessibilityItem)
        }

        menu.addItem(.separator())
        let aerospace = NSMenu(title: "AeroSpace")
        aerospace.autoenablesItems = false
        let reload = aerospace.addItem(
            withTitle: "Reload Config",
            action: #selector(reloadAerospaceConfig),
            keyEquivalent: ""
        )
        reload.target = self
        reload.isEnabled = FileManager.default.isExecutableFile(atPath: AerospaceClient.binaryURL.path)

        let configURL = AerospaceConfigLocator.shared.location().configURL
        let openConfig = aerospace.addItem(
            withTitle: "Open Config",
            action: #selector(openAerospaceConfig),
            keyEquivalent: ""
        )
        openConfig.target = self
        openConfig.isEnabled = FileManager.default.isReadableFile(atPath: configURL.path)
        openConfig.toolTip = "Opens the config while keeping AeroSpaceTabs and its current gaps active."

        let chooseEditor = aerospace.addItem(
            withTitle: "Choose Config Editor…",
            action: #selector(chooseConfigEditor),
            keyEquivalent: ""
        )
        chooseEditor.target = self
        if let editorName = AerospaceMenuActions.shared.selectedEditorName {
            chooseEditor.toolTip = "Current editor: \(editorName)"
        }

        aerospace.addItem(.separator())
        let quitAerospace = aerospace.addItem(
            withTitle: "Quit AeroSpace",
            action: #selector(quitAerospace),
            keyEquivalent: ""
        )
        quitAerospace.target = self
        quitAerospace.isEnabled = !NSRunningApplication.runningApplications(
            withBundleIdentifier: AerospaceMenuActions.aerospaceBundleIdentifier
        ).isEmpty
        quitAerospace.toolTip = "Also quits AeroSpaceTabs, which requires AeroSpace to run."

        let aerospaceItem = menu.addItem(withTitle: "AeroSpace", action: nil, keyEquivalent: "")
        menu.setSubmenu(aerospace, for: aerospaceItem)

        if let version = availableUpdateVersion() {
            menu.addItem(.separator())
            let update = menu.addItem(
                withTitle: "Update AeroSpaceTabs to \(version)…",
                action: #selector(installAvailableUpdate),
                keyEquivalent: ""
            )
            update.target = self
        }
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit AeroSpaceTabs", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @MainActor @objc private func installAvailableUpdate() {
        onInstallAvailableUpdate()
    }

    @MainActor @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let theme = StripTheme(rawValue: raw)
        else { return }
        AppearanceSettings.shared.select(theme)
    }

    @MainActor @objc private func openOverview() {
        onOpenOverview()
    }

    @MainActor @objc private func toggleThreeFingerSwipe() {
        onToggleSwipe()
    }

    @MainActor @objc private func selectHotCorner(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        if raw == "off" {
            OverviewSettings.shared.select(hotCorner: nil)
        } else if let corner = OverviewHotCorner(rawValue: raw) {
            OverviewSettings.shared.select(hotCorner: corner)
        }
    }

    @MainActor @objc private func reloadAerospaceConfig() {
        AerospaceMenuActions.shared.reloadConfig()
    }

    @MainActor @objc private func openAerospaceConfig() {
        AerospaceMenuActions.shared.openConfig()
    }

    @MainActor @objc private func chooseConfigEditor() {
        AerospaceMenuActions.shared.chooseEditor()
    }

    @MainActor @objc private func quitAerospace() {
        AerospaceMenuActions.shared.quitAerospace()
    }

    @MainActor @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor @objc private func quit() {
        GapBoost.shared.deactivate()
        onQuit()
    }
}
