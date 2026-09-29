import AppKit
import CoreFoundation
import Foundation

/// Temporarily gives the configured Aerospace Tabs triggers ownership of the
/// matching macOS Mission Control gesture and hot corner.
///
/// Original preferences are persisted before they are changed, so a force
/// quit can restore them on the next launch.
final class NativeGestureOverrides {
    static let shared = NativeGestureOverrides()

    private struct PreferenceKey: Codable, Hashable {
        let domain: String
        let name: String
    }

    private struct Override: Codable {
        let key: PreferenceKey
        let originalValue: Data?
        let appliedValue: Data
    }

    private struct Write {
        let key: PreferenceKey
        let value: Data?
    }

    private static let storageKey = "nativeGestureOverrides.savedValues"
    private static let dockDomain = "com.apple.dock"
    private static let missionControlGesture = PreferenceKey(
        domain: dockDomain,
        name: "showMissionControlGestureEnabled"
    )

    private let lock = NSRecursiveLock()
    private let defaults: UserDefaults
    private var overrides: [Override]
    private var isTerminating = false
    private var dockRestartPending = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? PropertyListDecoder().decode([Override].self, from: data)
        {
            overrides = saved
        } else {
            overrides = []
        }
    }

    /// Returns true when a Dock preference changed and Dock was restarted.
    @discardableResult
    func reconcile(swipeEnabled: Bool, hotCorner: OverviewHotCorner?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isTerminating else { return false }
        return reconcileLocked(swipeEnabled: swipeEnabled, hotCorner: hotCorner)
    }

    private func reconcileLocked(swipeEnabled: Bool, hotCorner: OverviewHotCorner?) -> Bool {
        var desired: [PreferenceKey: Data] = [:]
        if swipeEnabled, let value = Self.encode(false) {
            desired[Self.missionControlGesture] = value
        }
        if let hotCorner, let value = Self.encode(0) {
            desired[PreferenceKey(domain: Self.dockDomain, name: hotCorner.dockPreferenceKey)] = value
        }

        var nextOverrides: [Override] = []
        var writes: [Write] = []
        var restoringKeys: Set<PreferenceKey> = []

        for saved in overrides {
            if let wantedValue = desired.removeValue(forKey: saved.key) {
                nextOverrides.append(saved)
                if !Self.matches(
                    currentValue(for: saved.key),
                    encodedValue: wantedValue,
                    key: saved.key
                ) {
                    writes.append(Write(key: saved.key, value: wantedValue))
                }
            } else if Self.matches(
                currentValue(for: saved.key),
                encodedValue: saved.appliedValue,
                key: saved.key
            ) {
                nextOverrides.append(saved)
                restoringKeys.insert(saved.key)
                writes.append(Write(key: saved.key, value: saved.originalValue))
            }
        }

        for (key, wantedValue) in desired.sorted(by: { $0.key.name < $1.key.name }) {
            let current = currentValue(for: key)
            guard !Self.matches(current, encodedValue: wantedValue, key: key) else { continue }
            nextOverrides.append(Override(
                key: key,
                originalValue: Self.encode(current),
                appliedValue: wantedValue
            ))
            writes.append(Write(key: key, value: wantedValue))
        }

        overrides = nextOverrides
        guard persistOverrides() else { return false }
        if writes.contains(where: { $0.key.domain == Self.dockDomain }) {
            dockRestartPending = true
        }
        guard !writes.isEmpty || dockRestartPending else { return false }

        for write in writes {
            // Unwrap before bridging: casting Any? directly boxes Optional as
            // __SwiftValue, which CFPreferences rejects with an Objective-C exception.
            let value: CFPropertyList?
            if let decoded = Self.decode(write.value) {
                value = decoded as CFPropertyList
            } else {
                value = nil
            }
            CFPreferencesSetAppValue(
                write.key.name as CFString,
                value,
                write.key.domain as CFString
            )
        }

        var synchronizedDomains: Set<String> = []
        var domainsToSynchronize = Set(writes.map(\.key.domain))
        if dockRestartPending { domainsToSynchronize.insert(Self.dockDomain) }
        for domain in domainsToSynchronize {
            if CFPreferencesAppSynchronize(domain as CFString) {
                synchronizedDomains.insert(domain)
            } else {
                NSLog("Aerospace Tabs: Could not synchronize %@ preferences.", domain)
            }
        }

        if !restoringKeys.isEmpty {
            overrides.removeAll { saved in
                restoringKeys.contains(saved.key) && synchronizedDomains.contains(saved.key.domain)
            }
            _ = persistOverrides()
        }

        if dockRestartPending,
           synchronizedDomains.contains(Self.dockDomain),
           restartDock() {
            dockRestartPending = false
            return true
        }
        return false
    }

    func restore() {
        restoreForTermination()
    }

    func restoreForTermination() {
        lock.lock()
        defer { lock.unlock() }
        isTerminating = true
        _ = reconcileLocked(swipeEnabled: false, hotCorner: nil)
    }

    private func currentValue(for key: PreferenceKey) -> Any? {
        guard let value = CFPreferencesCopyAppValue(key.name as CFString, key.domain as CFString) else {
            return nil
        }
        return value as Any
    }

    private func persistOverrides() -> Bool {
        guard let data = try? PropertyListEncoder().encode(overrides) else { return false }
        defaults.set(data, forKey: Self.storageKey)
        return defaults.synchronize()
    }

    private func restartDock() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                NSLog("Aerospace Tabs: Dock restart exited with status %d.", process.terminationStatus)
                return false
            }
            return true
        } catch {
            NSLog("Aerospace Tabs: Could not restart Dock to apply gesture settings: %@", error.localizedDescription)
            return false
        }
    }

    private static func encode(_ value: Any?) -> Data? {
        guard let value else { return nil }
        return try? PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }

    private static func decode(_ data: Data?) -> Any? {
        guard let data else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    }

    private static func matches(_ current: Any?, encodedValue: Data, key: PreferenceKey) -> Bool {
        guard let wanted = decode(encodedValue) else { return false }
        if current == nil, key.name.hasSuffix("-corner"), (wanted as? NSNumber)?.intValue == 0 {
            // Missing hot-corner values mean the native action is disabled.
            return true
        }
        guard let current else { return false }
        return (current as? NSObject)?.isEqual(wanted) == true
    }
}

extension OverviewHotCorner {
    var dockPreferenceKey: String {
        switch self {
        case .topLeft: "wvous-tl-corner"
        case .topRight: "wvous-tr-corner"
        case .bottomLeft: "wvous-bl-corner"
        case .bottomRight: "wvous-br-corner"
        }
    }
}
