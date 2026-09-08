import Foundation

/// While Aerospace Tabs is running, temporarily adds the strip height to
/// AeroSpace `gaps.outer.top` so windows clear the bar — then restores on quit.
///
/// Backup lives on disk next to the AeroSpace config so a force-quit still
/// leaves a recoverable original, and the next launch always restores first.
final class GapBoost {
    static let shared = GapBoost()
    static let stripHeight: CGFloat = 34

    private var configPath: String {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.aerospace.toml",
            "\(home)/.config/aerospace/aerospace.toml",
        ]
        return candidates.first { FileManager.default.isReadableFile(atPath: $0) } ?? candidates[1]
    }

    private var backupURL: URL {
        URL(fileURLWithPath: configPath)
            .deletingLastPathComponent()
            .appendingPathComponent(".aerospace-tabs-outer-top.backup")
    }

    private var activeURL: URL {
        URL(fileURLWithPath: configPath)
            .deletingLastPathComponent()
            .appendingPathComponent(".aerospace-tabs-gap-boost.active")
    }

    private var isActive: Bool {
        FileManager.default.fileExists(atPath: activeURL.path)
    }

    /// Call once at launch. Always undoes a leftover boost before applying a new one.
    func activate() {
        restoreBackup(reload: false)
        guard var text = try? String(contentsOfFile: configPath, encoding: .utf8),
              let range = Self.outerTopBlockRange(in: text)
        else { return }

        let original = String(text[range])
        do {
            try original.write(to: backupURL, atomically: true, encoding: .utf8)
        } catch {
            return
        }

        let boosted = Self.shiftNumbers(in: original, by: Self.stripHeight)
        text.replaceSubrange(range, with: boosted)
        do {
            try text.write(toFile: configPath, atomically: true, encoding: .utf8)
            try? "1".write(to: activeURL, atomically: true, encoding: .utf8)
            reloadAerospace()
        } catch {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.removeItem(at: activeURL)
        }
    }

    /// Call on quit / SIGTERM. Restores the user's original `outer.top`.
    func deactivate() {
        restoreBackup(reload: true)
    }

    /// Manual recovery (menu item / CLI). Safe if nothing was boosted.
    @discardableResult
    func restoreIfNeeded() -> Bool {
        restoreBackup(reload: true)
    }

    @discardableResult
    private func restoreBackup(reload: Bool) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupURL.path),
              let backup = try? String(contentsOf: backupURL, encoding: .utf8),
              var text = try? String(contentsOfFile: configPath, encoding: .utf8),
              let range = Self.outerTopBlockRange(in: text)
        else {
            // No backup — still clear a stale active marker.
            try? fm.removeItem(at: activeURL)
            return false
        }

        text.replaceSubrange(range, with: backup)
        do {
            try text.write(toFile: configPath, atomically: true, encoding: .utf8)
            try? fm.removeItem(at: backupURL)
            try? fm.removeItem(at: activeURL)
            if reload {
                reloadAerospace()
            }
            return true
        } catch {
            // Keep backup + active marker so a later attempt can still recover.
            return false
        }
    }

    private func reloadAerospace() {
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
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { continue }
            if line.hasPrefix("outer.top"), line.contains("=") {
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
