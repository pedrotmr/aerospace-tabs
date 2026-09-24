import AppKit
import Carbon
import CoreGraphics
import Foundation

final class Hotkeys {
    var onStep: ((HotkeyCycle, Bool) -> Void)?
    var onCommit: ((HotkeyCycle) -> Void)?

    private var nextRef: EventHotKeyRef?
    private var prevRef: EventHotKeyRef?
    private var nextSpaceRef: EventHotKeyRef?
    private var prevSpaceRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var flagsMonitor: Any?
    private var holdTimer: Timer?
    private var holdActive = false
    private var reverse = false
    private var cycle: HotkeyCycle = .windows
    private var holdKey: CGKeyCode = CGKeyCode(kVK_Tab)
    private var holdStarted = Date()
    private var lastStep = Date()
    private var didRepeatStep = false
    private var installed = false
    private let scheduleFailurePresentation: (@escaping () -> Void) -> Void
    private let presentInstallationFailure: (HotkeyInstallationError) -> Void

    private let initialRepeatDelay: TimeInterval = 0.35
    private let repeatInterval: TimeInterval = 0.09

    init(
        scheduleFailurePresentation: @escaping (@escaping () -> Void) -> Void = { action in
            DispatchQueue.main.async(execute: action)
        },
        presentInstallationFailure: @escaping (HotkeyInstallationError) -> Void = { error in
            Hotkeys.showInstallationFailure(error)
        }
    ) {
        self.scheduleFailurePresentation = scheduleFailurePresentation
        self.presentInstallationFailure = presentInstallationFailure
    }

    func install() {
        guard !installed else { return }
        promptAccessibilityIfNeeded()

        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        var installedHandler: EventHandlerRef?
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return noErr }
            let hotkeys = Unmanaged<Hotkeys>.fromOpaque(userData).takeUnretainedValue()
            var id = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id
            )
            DispatchQueue.main.async {
                let cycle: HotkeyCycle = id.id >= 3 ? .spaces : .windows
                hotkeys.handleStep(cycle: cycle, reverse: id.id == 2 || id.id == 4)
            }
            return noErr
        }, 1, &pressed, userData, &installedHandler)
        guard handlerStatus == noErr, let installedHandler else {
            if let installedHandler {
                RemoveEventHandler(installedHandler)
            }
            reportInstallationFailure(.eventHandler(status: handlerStatus))
            return
        }
        handler = installedHandler

        let nextID = EventHotKeyID(signature: OSType(0x41544142), id: 1)
        let prevID = EventHotKeyID(signature: OSType(0x41544142), id: 2)
        var registeredNext: EventHotKeyRef?
        let nextStatus = RegisterEventHotKey(
            UInt32(kVK_Tab),
            UInt32(optionKey),
            nextID,
            GetApplicationEventTarget(),
            0,
            &registeredNext
        )
        guard nextStatus == noErr, let registeredNext else {
            if let registeredNext {
                UnregisterEventHotKey(registeredNext)
            }
            removeCarbonRegistrations()
            reportInstallationFailure(.forwardHotKey(status: nextStatus))
            return
        }
        nextRef = registeredNext

        var registeredPrevious: EventHotKeyRef?
        let previousStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_Grave),
            UInt32(optionKey),
            prevID,
            GetApplicationEventTarget(),
            0,
            &registeredPrevious
        )
        guard previousStatus == noErr, let registeredPrevious else {
            if let registeredPrevious {
                UnregisterEventHotKey(registeredPrevious)
            }
            removeCarbonRegistrations()
            reportInstallationFailure(.reverseHotKey(status: previousStatus))
            return
        }
        prevRef = registeredPrevious

        var registeredNextSpace: EventHotKeyRef?
        let nextSpaceStatus = RegisterEventHotKey(
            UInt32(kVK_Tab),
            UInt32(optionKey | controlKey),
            EventHotKeyID(signature: OSType(0x41544142), id: 3),
            GetApplicationEventTarget(),
            0,
            &registeredNextSpace
        )
        guard nextSpaceStatus == noErr, let registeredNextSpace else {
            if let registeredNextSpace { UnregisterEventHotKey(registeredNextSpace) }
            removeCarbonRegistrations()
            reportInstallationFailure(.spaceForwardHotKey(status: nextSpaceStatus))
            return
        }
        nextSpaceRef = registeredNextSpace

        var registeredPreviousSpace: EventHotKeyRef?
        let previousSpaceStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_Grave),
            UInt32(optionKey | controlKey),
            EventHotKeyID(signature: OSType(0x41544142), id: 4),
            GetApplicationEventTarget(),
            0,
            &registeredPreviousSpace
        )
        guard previousSpaceStatus == noErr, let registeredPreviousSpace else {
            if let registeredPreviousSpace { UnregisterEventHotKey(registeredPreviousSpace) }
            removeCarbonRegistrations()
            reportInstallationFailure(.spaceReverseHotKey(status: previousSpaceStatus))
            return
        }
        prevSpaceRef = registeredPreviousSpace

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if !event.modifierFlags.contains(.option) {
                self?.stopHold()
            }
        }
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if !event.modifierFlags.contains(.option) {
                self?.stopHold()
            }
            return event
        }
        installed = true
    }

    private func removeCarbonRegistrations() {
        if let prevRef {
            UnregisterEventHotKey(prevRef)
            self.prevRef = nil
        }
        if let nextSpaceRef {
            UnregisterEventHotKey(nextSpaceRef)
            self.nextSpaceRef = nil
        }
        if let prevSpaceRef {
            UnregisterEventHotKey(prevSpaceRef)
            self.prevSpaceRef = nil
        }
        if let nextRef {
            UnregisterEventHotKey(nextRef)
            self.nextRef = nil
        }
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
        installed = false
    }

    func reportInstallationFailure(_ error: HotkeyInstallationError) {
        NSLog("AerospaceTabs hotkey installation failed: %@", error.localizedDescription)
        scheduleFailurePresentation { [presentInstallationFailure] in
            presentInstallationFailure(error)
        }
    }

    private static func showInstallationFailure(_ error: HotkeyInstallationError) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "AerospaceTabs keyboard shortcuts are unavailable"
        alert.informativeText = "\(error.localizedDescription) The app will keep running without global shortcuts."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func handleStep(cycle: HotkeyCycle, reverse: Bool) {
        // Carbon may fire key-repeat hotkeys; the hold timer owns continuing steps.
        if holdActive { return }

        self.reverse = reverse
        self.cycle = cycle
        holdKey = reverse ? CGKeyCode(kVK_ANSI_Grave) : CGKeyCode(kVK_Tab)
        holdActive = true
        holdStarted = Date()
        lastStep = Date()
        didRepeatStep = false
        onStep?(cycle, reverse)
        startHoldTimer()
    }

    private func startHoldTimer() {
        holdTimer?.invalidate()
        // Poll key state often so releasing the step key stops immediately.
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.holdTick()
        }
    }

    private func holdTick() {
        // Stop as soon as Tab/` goes up (Option can stay down).
        guard stepKeyDown, optionDown, cycle != .spaces || controlDown else {
            stopHold()
            return
        }

        let now = Date()
        if !didRepeatStep {
            if now.timeIntervalSince(holdStarted) >= initialRepeatDelay {
                didRepeatStep = true
                lastStep = now
                onStep?(cycle, reverse)
            }
            return
        }

        if now.timeIntervalSince(lastStep) >= repeatInterval {
            lastStep = now
            onStep?(cycle, reverse)
        }
    }

    private func stopHold() {
        guard holdActive || holdTimer != nil else { return }
        holdActive = false
        didRepeatStep = false
        holdTimer?.invalidate()
        holdTimer = nil
        onCommit?(cycle)
    }

    private var optionDown: Bool {
        NSEvent.modifierFlags.contains(.option)
    }

    private var controlDown: Bool {
        NSEvent.modifierFlags.contains(.control)
    }

    private var stepKeyDown: Bool {
        CGEventSource.keyState(.hidSystemState, key: holdKey)
    }

    private func promptAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

enum HotkeyCycle: Equatable {
    case spaces
    case windows
}

enum HotkeyInstallationError: LocalizedError, Equatable {
    case eventHandler(status: OSStatus)
    case forwardHotKey(status: OSStatus)
    case reverseHotKey(status: OSStatus)
    case spaceForwardHotKey(status: OSStatus)
    case spaceReverseHotKey(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .eventHandler(let status):
            return "Could not install the keyboard event handler (OSStatus \(status))."
        case .forwardHotKey(let status):
            return "Could not register Option-Tab (OSStatus \(status))."
        case .reverseHotKey(let status):
            return "Could not register Option-Backtick (OSStatus \(status))."
        case .spaceForwardHotKey(let status):
            return "Could not register Control-Option-Tab (OSStatus \(status))."
        case .spaceReverseHotKey(let status):
            return "Could not register Control-Option-Backtick (OSStatus \(status))."
        }
    }
}
