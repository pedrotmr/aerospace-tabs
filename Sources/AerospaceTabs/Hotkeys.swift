import AppKit
import Carbon
import CoreGraphics
import Foundation

final class Hotkeys {
    /// Called on each cycle step. `reverse` is Option-backtick.
    var onStep: ((Bool) -> Void)?
    var onCommit: (() -> Void)?

    private var nextRef: EventHotKeyRef?
    private var prevRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var flagsMonitor: Any?
    private var holdTimer: Timer?
    private var holdActive = false
    private var reverse = false
    private var holdKey: CGKeyCode = CGKeyCode(kVK_Tab)
    private var holdStarted = Date()
    private var lastStep = Date()
    private var didRepeatStep = false

    private let initialRepeatDelay: TimeInterval = 0.35
    private let repeatInterval: TimeInterval = 0.09

    func install() {
        promptAccessibilityIfNeeded()

        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
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
                // id 1 = Option-Tab (forward), id 2 = Option-` (reverse)
                hotkeys.handleStep(reverse: id.id == 2)
            }
            return noErr
        }, 1, &pressed, userData, &handler)

        let nextID = EventHotKeyID(signature: OSType(0x41544142), id: 1)
        let prevID = EventHotKeyID(signature: OSType(0x41544142), id: 2)
        RegisterEventHotKey(UInt32(kVK_Tab), UInt32(optionKey), nextID, GetApplicationEventTarget(), 0, &nextRef)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_Grave),
            UInt32(optionKey),
            prevID,
            GetApplicationEventTarget(),
            0,
            &prevRef
        )

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
    }

    private func handleStep(reverse: Bool) {
        // Carbon may fire key-repeat hotkeys; the hold timer owns continuing steps.
        if holdActive { return }

        self.reverse = reverse
        holdKey = reverse ? CGKeyCode(kVK_ANSI_Grave) : CGKeyCode(kVK_Tab)
        holdActive = true
        holdStarted = Date()
        lastStep = Date()
        didRepeatStep = false
        onStep?(reverse)
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
        guard stepKeyDown, optionDown else {
            stopHold()
            return
        }

        let now = Date()
        if !didRepeatStep {
            if now.timeIntervalSince(holdStarted) >= initialRepeatDelay {
                didRepeatStep = true
                lastStep = now
                onStep?(reverse)
            }
            return
        }

        if now.timeIntervalSince(lastStep) >= repeatInterval {
            lastStep = now
            onStep?(reverse)
        }
    }

    private func stopHold() {
        guard holdActive || holdTimer != nil else { return }
        holdActive = false
        didRepeatStep = false
        holdTimer?.invalidate()
        holdTimer = nil
        onCommit?()
    }

    private var optionDown: Bool {
        NSEvent.modifierFlags.contains(.option)
    }

    private var stepKeyDown: Bool {
        CGEventSource.keyState(.hidSystemState, key: holdKey)
    }

    private func promptAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
