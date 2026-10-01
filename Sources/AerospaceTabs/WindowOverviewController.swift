import AppKit
import SwiftUI

@MainActor
final class WindowOverviewController {
    var onFocusWindow: ((Int) -> Void)?
    var onPresentationChange: ((Bool) -> Void)?

    private let model = WindowOverviewModel()
    private let previews = WindowPreviewStore()
    private var panels: [CGDirectDisplayID: OverviewPanel] = [:]
    private var keyMonitor: Any?
    private var liveStart: DispatchWorkItem?
    private var previousApplication: NSRunningApplication?
    private var appearanceObserver: NSObjectProtocol?
    private var windows: [Win] = []
    private var focusedID: Int?

    private(set) var isPresented = false

    init() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: AppearanceSettings.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.model.updateSettings()
                self?.applyPanelAppearances()
            }
        }
    }

    deinit {
        if let appearanceObserver { NotificationCenter.default.removeObserver(appearanceObserver) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    func update(windows: [Win], focusedID: Int?) {
        self.windows = windows
        self.focusedID = focusedID
        previews.update(windows: windows)
        guard isPresented else { return }
        model.update(windows: windows, focusedID: focusedID)
        guard !windows.isEmpty else {
            dismiss()
            return
        }
        syncScreens()
        syncPanelVisibility()
    }

    func toggle() {
        isPresented ? dismiss() : present()
    }

    func present() {
        guard !isPresented, !windows.isEmpty else { return }
        previousApplication = NSWorkspace.shared.frontmostApplication
        isPresented = true
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            model.update(windows: windows, focusedID: focusedID)
            model.beginPresentation()
        }
        previews.beginSession()
        previews.setPriorityWindow(model.windows.first(where: { $0.id == model.selectedID }))
        syncScreens()
        onPresentationChange?(true)
        installKeyMonitor()
        for panel in panels.values { panel.show(animated: true) }
        if let focusedScreen = model.focusedScreenIndex,
           let screen = NSScreen.screens.first(where: { $0.aerospaceScreenIndex == focusedScreen }),
           let panel = panels[screen.displayID]
        {
            panel.activateKeyWindow()
        } else {
            panels.values.first?.activateKeyWindow()
        }
        let start = DispatchWorkItem { [weak self] in
            guard let self, self.isPresented else { return }
            self.previews.startLivePreviews()
            self.liveStart = nil
        }
        liveStart = start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: start)
    }

    func dismiss(restorePrevious: Bool = true) {
        guard isPresented else { return }
        isPresented = false
        liveStart?.cancel()
        liveStart = nil
        removeKeyMonitor()
        previews.endSession()
        for panel in panels.values { panel.close() }
        panels.removeAll()
        onPresentationChange?(false)

        let application = previousApplication
        previousApplication = nil
        if restorePrevious, let application, !application.isTerminated {
            application.activate(options: [])
        }
    }

    private func focus(_ id: Int) {
        guard model.navigationWindows.contains(where: { $0.id == id }) else { return }
        dismiss(restorePrevious: false)
        onFocusWindow?(id)
    }

    private func syncScreens() {
        let screens = NSScreen.screens
        let connected = Set(screens.map(\.displayID))
        let removedIDs = panels.keys.filter { !connected.contains($0) }
        for id in removedIDs {
            panels[id]?.close()
            panels.removeValue(forKey: id)
        }
        for screen in screens {
            let descriptor = OverviewDisplayDescriptor(screen: screen)
            if let panel = panels[screen.displayID] {
                panel.update(display: descriptor)
            } else {
                let panel = OverviewPanel(
                    display: descriptor,
                    model: model,
                    previews: previews,
                    onDismiss: { [weak self] in self?.dismiss() },
                    onFocus: { [weak self] id in self?.focus(id) }
                )
                panels[screen.displayID] = panel
            }
        }
    }

    private func syncPanelVisibility() {
        guard isPresented else { return }
        for panel in panels.values { panel.show(animated: false) }
    }

    private func applyPanelAppearances() {
        for panel in panels.values { panel.applyTheme(AppearanceSettings.shared.theme) }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isPresented else { return event }
            switch event.keyCode {
            case 53: // Escape
                self.dismiss()
                return nil
            case 36, 76: // Return, keypad Enter
                if let selectedID = self.model.selectedID {
                    self.focus(selectedID)
                    return nil
                }
            case 123:
                self.model.moveSelection(.left)
                return nil
            case 124:
                self.model.moveSelection(.right)
                return nil
            case 125:
                self.model.moveSelection(.down)
                return nil
            case 126:
                self.model.moveSelection(.up)
                return nil
            default:
                break
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }
}

private final class OverviewPanel: NSPanel {
    private let host: NSHostingView<WindowOverviewScreen>
    private let model: WindowOverviewModel
    private let previews: WindowPreviewStore
    private let onDismiss: () -> Void
    private let onFocus: (Int) -> Void
    private var display: OverviewDisplayDescriptor

    init(
        display: OverviewDisplayDescriptor,
        model: WindowOverviewModel,
        previews: WindowPreviewStore,
        onDismiss: @escaping () -> Void,
        onFocus: @escaping (Int) -> Void
    ) {
        self.model = model
        self.previews = previews
        self.onDismiss = onDismiss
        self.onFocus = onFocus
        self.display = display

        let content = WindowOverviewScreen(
            model: model,
            previews: previews,
            display: display,
            onDismiss: onDismiss,
            onFocus: onFocus
        )
        host = NSHostingView(rootView: content)
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]

        super.init(
            contentRect: display.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        contentView = host
        host.frame = CGRect(origin: .zero, size: display.frame.size)
        applyTheme(AppearanceSettings.shared.theme)
        host.layoutSubtreeIfNeeded()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func update(display: OverviewDisplayDescriptor) {
        guard display != self.display else { return }
        self.display = display
        setFrame(display.frame, display: false)
        host.rootView = WindowOverviewScreen(
            model: model,
            previews: previews,
            display: display,
            onDismiss: onDismiss,
            onFocus: onFocus
        )
    }

    func activateKeyWindow() {
        makeKeyAndOrderFront(nil)
        makeFirstResponder(host)
    }

    override func cancelOperation(_ sender: Any?) {
        onDismiss()
    }

    func show(animated: Bool) {
        guard !isVisible else { return }
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.08
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().alphaValue = 1
            }
        } else {
            alphaValue = 1
            orderFrontRegardless()
        }
    }

    func applyTheme(_ theme: StripTheme) {
        appearance = theme == .solid ? NSAppearance(named: .darkAqua) : nil
    }

    override func close() {
        orderOut(nil)
        super.close()
    }
}
