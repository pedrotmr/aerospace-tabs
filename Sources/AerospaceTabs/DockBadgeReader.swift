import AppKit
import ApplicationServices

enum DockBadgeKey {
    static func bundleID(_ value: String) -> String {
        "bundle-id:\(value)"
    }

    static func bundlePath(_ value: String) -> String {
        let path = URL(fileURLWithPath: value).standardizedFileURL.path
        return "bundle-path:\(path)"
    }
}

final class DockBadgeReader {
    var onChange: (() -> Void)?

    private let queue = DispatchQueue(label: "AerospaceTabs.dock-badges", qos: .utility)
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var started = false
    private var currentBadges: [String: String] = [:]

    var badgesByApp: [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return currentBadges
    }

    func start() {
        guard !started else { return }
        started = true

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.5)
        timer.setEventHandler { [weak self] in
            self?.refresh()
        }
        self.timer = timer
        timer.resume()
    }

    deinit {
        timer?.cancel()
    }

    private func refresh() {
        let updated = Self.readDockBadges()
        lock.lock()
        let changed = updated != currentBadges
        if changed { currentBadges = updated }
        lock.unlock()

        guard changed else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onChange?()
        }
    }

    private static func readDockBadges() -> [String: String] {
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.dock"
              ).first
        else { return [:] }

        let root = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.2)

        var badges: [String: String] = [:]
        collectDockItems(in: root, depth: 0, into: &badges)
        return badges
    }

    private static func collectDockItems(
        in element: AXUIElement,
        depth: Int,
        into badges: inout [String: String]
    ) {
        guard depth < 5 else { return }

        let role = stringAttribute(kAXRoleAttribute, of: element)
        let subrole = stringAttribute(kAXSubroleAttribute, of: element)
        if isApplicationDockItem(role: role, subrole: subrole) {
            addBadge(from: element, to: &badges)
        }

        guard let children = attribute(kAXChildrenAttribute as CFString, of: element) as? [AXUIElement] else {
            return
        }
        for child in children {
            collectDockItems(in: child, depth: depth + 1, into: &badges)
        }
    }

    private static func addBadge(from element: AXUIElement, to badges: inout [String: String]) {
        guard let label = stringAttribute("AXStatusLabel", of: element),
              !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let appURL = appURL(from: attribute("AXURL" as CFString, of: element))
        else { return }

        let pathKey = DockBadgeKey.bundlePath(appURL.path)
        badges[pathKey] = label
        if let bundleID = Bundle(url: appURL)?.bundleIdentifier {
            badges[DockBadgeKey.bundleID(bundleID)] = label
        }
    }

    private static func isApplicationDockItem(role: String?, subrole: String?) -> Bool {
        role == kAXApplicationDockItemSubrole
            || (role == kAXDockItemRole && subrole == kAXApplicationDockItemSubrole)
    }

    private static func appURL(from value: CFTypeRef?) -> URL? {
        guard let value else { return nil }
        if let url = value as? URL, url.isFileURL { return url }

        let text: String
        if let string = value as? String {
            text = string
        } else if let url = value as? NSURL, let absoluteString = url.absoluteString {
            text = absoluteString
        } else {
            return nil
        }

        if let url = URL(string: text), url.isFileURL { return url }
        return URL(fileURLWithPath: text)
    }

    private static func stringAttribute(_ name: String, of element: AXUIElement) -> String? {
        let value = attribute(name as CFString, of: element)
        if let string = value as? String { return string }
        return (value as? NSNumber)?.stringValue
    }

    private static func attribute(_ name: CFString, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value
    }
}
