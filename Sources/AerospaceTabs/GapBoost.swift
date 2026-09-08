import Foundation

/// While Aerospace Tabs is running, temporarily adds the strip height to
/// AeroSpace `gaps.outer.top` so windows clear the bar — then restores on quit.
///
/// Backup lives on disk next to the AeroSpace config so a force-quit still
/// leaves a recoverable original. All file access is serialized.
///
/// `sync(shouldBoost:)` ties the boost to strip visibility so hidden spaces
/// do not keep a phantom top gap.
final class GapBoost {
    static let shared = GapBoost()
    static let stripHeight: CGFloat = 34

    private let queue = DispatchQueue(label: "aerospace-tabs.gap-boost")
    private let locator: AerospaceConfigLocator
    private let reloadHandler: (() -> Void)?

    init(
        locator: AerospaceConfigLocator = .shared,
        reloadHandler: (() -> Void)? = nil
    ) {
        self.locator = locator
        self.reloadHandler = reloadHandler
    }

    /// Undo any leftover boost from a previous crash, then wait for `sync`.
    func prepareAtLaunch() {
        queue.sync {
            _ = restoreBackup(reload: true)
        }
    }

    /// Keep boost aligned with whether any strip should be visible.
    func sync(shouldBoost: Bool) {
        queue.sync {
            if shouldBoost {
                applyBoostIfNeeded()
            } else {
                _ = restoreBackup(reload: true)
            }
        }
    }

    /// Call on quit / SIGTERM. Restores the user's original `outer.top`.
    func deactivate() {
        queue.sync {
            _ = restoreBackup(reload: true)
        }
    }

    /// Manual recovery (menu item / CLI). Safe if nothing was boosted.
    @discardableResult
    func restoreIfNeeded() -> Bool {
        queue.sync {
            restoreBackup(reload: true)
        }
    }

    private func applyBoostIfNeeded() {
        let location = locator.location()
        if location.hasRecoveryState() { return }
        guard var text = try? String(contentsOf: location.configURL, encoding: .utf8),
              let range = Self.outerTopBlockRange(in: text)
        else { return }

        let original = String(text[range])
        do {
            try original.write(to: location.backupURL, atomically: true, encoding: .utf8)
        } catch {
            return
        }

        let boosted = Self.shiftNumbers(in: original, by: Self.stripHeight)
        text.replaceSubrange(range, with: boosted)
        do {
            try text.write(to: location.configURL, atomically: true, encoding: .utf8)
            try? location.configURL.path.write(to: location.activeURL, atomically: true, encoding: .utf8)
            reloadAerospace()
        } catch {
            try? FileManager.default.removeItem(at: location.backupURL)
            try? FileManager.default.removeItem(at: location.activeURL)
        }
    }

    @discardableResult
    private func restoreBackup(reload: Bool) -> Bool {
        let fm = FileManager.default
        let location = locator.location()
        let isActive = fm.fileExists(atPath: location.activeURL.path)
        guard fm.fileExists(atPath: location.backupURL.path) || isActive else {
            try? fm.removeItem(at: location.activeURL)
            return false
        }

        guard var text = try? String(contentsOf: location.configURL, encoding: .utf8),
              let range = Self.outerTopBlockRange(in: text)
        else {
            try? fm.removeItem(at: location.activeURL)
            try? fm.removeItem(at: location.backupURL)
            return false
        }

        let current = String(text[range])
        let restored: String
        if let backup = try? String(contentsOf: location.backupURL, encoding: .utf8) {
            let expectedBoosted = Self.shiftNumbers(in: backup, by: Self.stripHeight)
            // Prefer exact undo when the user did not edit outer.top mid-session.
            // Otherwise subtract our delta from the live block so we do not clobber edits.
            if current == expectedBoosted {
                restored = backup
            } else if isActive {
                restored = Self.shiftNumbers(in: current, by: -Self.stripHeight)
            } else {
                restored = backup
            }
        } else if isActive {
            restored = Self.shiftNumbers(in: current, by: -Self.stripHeight)
        } else {
            try? fm.removeItem(at: location.activeURL)
            return false
        }

        text.replaceSubrange(range, with: restored)
        do {
            try text.write(to: location.configURL, atomically: true, encoding: .utf8)
            try? fm.removeItem(at: location.backupURL)
            try? fm.removeItem(at: location.activeURL)
            if reload {
                reloadAerospace()
            }
            return true
        } catch {
            return false
        }
    }

    private func reloadAerospace() {
        if let reloadHandler {
            reloadHandler()
            return
        }

        let process = Process()
        process.executableURL = AerospaceClient.binaryURL
        process.arguments = ["reload-config"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    static func outerTopBlockRange(in text: String) -> Range<String.Index>? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var start: Int?
        for (i, raw) in lines.enumerated() {
            if AerospaceConfigSyntax.isAssignment(String(raw), key: "outer.top") {
                start = i
                break
            }
        }
        guard let start else { return nil }

        var end = start
        let head = lines[start].trimmingCharacters(in: .whitespaces)
        if head.contains("[") {
            for i in start..<lines.count {
                end = i
                if lines[i].trimmingCharacters(in: .whitespaces).contains("]") { break }
            }
        }

        var offset = 0
        var lowerOffset: Int?
        var upperOffset: Int?
        for (i, line) in lines.enumerated() {
            if i == start { lowerOffset = offset }
            if i == end {
                upperOffset = offset + line.count
                if i < lines.count - 1 { upperOffset! += 1 }
                break
            }
            offset += line.count + (i < lines.count - 1 ? 1 : 0)
        }
        guard let lowerOffset, let upperOffset else { return nil }
        let lower = text.index(text.startIndex, offsetBy: lowerOffset)
        let upper = text.index(text.startIndex, offsetBy: min(upperOffset, text.count))
        return lower..<upper
    }

    static func shiftNumbers(in block: String, by delta: CGFloat) -> String {
        var result = ""
        var i = block.startIndex
        var inQuote = false
        while i < block.endIndex {
            let ch = block[i]
            if ch == "\"" {
                inQuote.toggle()
                result.append(ch)
                i = block.index(after: i)
                continue
            }
            if !inQuote, ch.isNumber || ch == "." {
                var j = i
                while j < block.endIndex {
                    let c = block[j]
                    if c.isNumber || c == "." {
                        j = block.index(after: j)
                    } else {
                        break
                    }
                }
                let token = String(block[i..<j])
                if let value = Double(token), token.contains(where: \.isNumber) {
                    let shifted = max(0, value + Double(delta))
                    if shifted == floor(shifted) {
                        result += String(Int(shifted))
                    } else {
                        result += String(shifted)
                    }
                } else {
                    result += token
                }
                i = j
                continue
            }
            result.append(ch)
            i = block.index(after: i)
        }
        return result
    }
}
