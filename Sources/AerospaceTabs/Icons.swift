import AppKit

final class Icons {
    static let shared = Icons()
    private var cache: [String: NSImage] = [:]

    func icon(for win: Win) -> NSImage {
        let key = win.bundleID.isEmpty ? win.bundlePath : win.bundleID
        if let cached = cache[key] { return cached }
        var image: NSImage?
        if !win.bundleID.isEmpty {
            image = NSRunningApplication.runningApplications(withBundleIdentifier: win.bundleID).first?.icon
        }
        if image == nil, !win.bundlePath.isEmpty {
            image = NSWorkspace.shared.icon(forFile: win.bundlePath)
        }
        let resolved = image ?? NSImage(size: NSSize(width: 14, height: 14))
        resolved.size = NSSize(width: 14, height: 14)
        cache[key] = resolved
        return resolved
    }
}
