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
    private let reloadExecutableURL: URL?
    private var reloadProcesses: [Process] = []

    init(
        locator: AerospaceConfigLocator = .shared,
        reloadHandler: (() -> Void)? = nil,
        reloadExecutableURL: URL? = nil
    ) {
        self.locator = locator
        self.reloadHandler = reloadHandler
        self.reloadExecutableURL = reloadExecutableURL
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
    func restoreIfNeeded(reload: Bool = true) -> Bool {
        queue.sync {
            restoreBackup(reload: reload)
        }
    }

    private func applyBoostIfNeeded() {
        let location = locator.location()
        if location.hasRecoveryState() { return }
        guard var text = try? String(contentsOf: location.configURL, encoding: .utf8),
              let range = Self.outerTopBlockRange(in: text)
        else { return }

        let original = String(text[range])
        let backup = AerospaceGapBackup(
            configURL: location.configURL,
            originalBlock: original
        )
        guard writeVerified(backup.serialized, to: location.backupURL) else { return }

        // Persist the resolved target before changing it. Recovery remains tied
        // to this file even if a higher-priority candidate appears or a symlink
        // is retargeted while the app is running.
        guard writeVerified(location.configURL.path, to: location.activeURL) else { return }

        let boosted = Self.shiftNumbers(in: original, by: Self.stripHeight)
        text.replaceSubrange(range, with: boosted)
        guard writeVerified(text, to: location.configURL) else { return }
        reloadAerospace()
    }

    @discardableResult
    private func restoreBackup(reload: Bool) -> Bool {
        let fm = FileManager.default
        let location = locator.location()
        let backupExists = fm.fileExists(atPath: location.backupURL.path)
        let activeExists = fm.fileExists(atPath: location.activeURL.path)
        guard backupExists || activeExists else { return false }

        guard var text = try? String(contentsOf: location.configURL, encoding: .utf8),
              let range = Self.outerTopBlockRange(in: text)
        else { return false }

        let current = String(text[range])
        let restored: String
        if backupExists {
            guard let contents = try? String(contentsOf: location.backupURL, encoding: .utf8),
                  let backup = AerospaceGapBackup.originalBlock(from: contents)
            else {
                return false
            }

            // The restore write may have completed before recovery state was
            // removed. In that case, only clean up; subtracting again would
            // corrupt the user's original gap.
            if current == backup {
                finishRecovery(at: location, reload: reload)
                return true
            }

            let expectedBoosted = Self.shiftNumbers(in: backup, by: Self.stripHeight)
            // Prefer exact undo when the user did not edit outer.top mid-session.
            // Otherwise subtract our delta from the live block so we do not clobber edits.
            if current == expectedBoosted {
                restored = backup
            } else if activeExists {
                restored = Self.shiftNumbers(in: current, by: -Self.stripHeight)
            } else {
                restored = backup
            }
        } else if activeExists {
            restored = Self.shiftNumbers(in: current, by: -Self.stripHeight)
        } else {
            return false
        }

        text.replaceSubrange(range, with: restored)
        guard writeVerified(text, to: location.configURL) else { return false }
        finishRecovery(at: location, reload: reload)
        return true
    }

    private func writeVerified(_ text: String, to url: URL) -> Bool {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return try String(contentsOf: url, encoding: .utf8) == text
        } catch {
            NSLog("AerospaceTabs could not write %@: %@", url.path, error.localizedDescription)
            return false
        }
    }

    private func finishRecovery(at location: AerospaceConfigLocation, reload: Bool) {
        let fm = FileManager.default
        do {
            // The backup carries the resolved target, so it remains safe if a
            // crash happens after marker removal but before backup removal.
            if fm.fileExists(atPath: location.activeURL.path) {
                try fm.removeItem(at: location.activeURL)
            }
            if fm.fileExists(atPath: location.backupURL.path) {
                try fm.removeItem(at: location.backupURL)
            }
        } catch {
            NSLog("AerospaceTabs could not clean gap recovery state: %@", error.localizedDescription)
        }
        if reload {
            reloadAerospace()
        }
    }

    private func reloadAerospace() {
        if let reloadHandler {
            reloadHandler()
            return
        }

        let process = Process()
        process.executableURL = reloadExecutableURL ?? AerospaceClient.binaryURL
        process.arguments = ["reload-config"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self, weak process] _ in
            guard let self, let process else { return }
            self.queue.async {
                self.reloadProcesses.removeAll { $0 === process }
            }
        }
        do {
            try process.run()
            reloadProcesses.append(process)
        } catch {
            NSLog("AerospaceTabs could not reload the AeroSpace config: %@", error.localizedDescription)
        }
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
        let head = String(lines[start])
        if AerospaceConfigSyntax.containsUnquoted("[", in: head) {
            var foundClosingBracket = false
            var bracketDepth = 0
            for i in start..<lines.count {
                end = i
                for character in AerospaceConfigSyntax.charactersOutsideQuotes(in: String(lines[i])) {
                    if character == "[" {
                        bracketDepth += 1
                    } else if character == "]" {
                        bracketDepth -= 1
                        if bracketDepth == 0 {
                            foundClosingBracket = true
                            break
                        }
                    }
                }
                if foundClosingBracket { break }
            }
            guard foundClosingBracket else { return nil }
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
        var quote: Character?
        var escaped = false
        var inComment = false
        while i < block.endIndex {
            let ch = block[i]

            if ch == "\n" {
                inComment = false
                result.append(ch)
                i = block.index(after: i)
                continue
            }

            if inComment {
                result.append(ch)
                i = block.index(after: i)
                continue
            }

            if let currentQuote = quote {
                result.append(ch)
                if currentQuote == "\"" && ch == "\\" && !escaped {
                    escaped = true
                } else {
                    if ch == currentQuote && !escaped {
                        quote = nil
                    }
                    escaped = false
                }
                i = block.index(after: i)
                continue
            }

            if ch == "\"" || ch == "'" {
                quote = ch
                result.append(ch)
                i = block.index(after: i)
                continue
            }
            if ch == "#" {
                inComment = true
                result.append(ch)
                i = block.index(after: i)
                continue
            }
            if AerospaceConfigSyntax.isGapNumberStart(ch) {
                var j = i
                while j < block.endIndex {
                    let c = block[j]
                    if AerospaceConfigSyntax.isGapNumberCharacter(c) {
                        j = block.index(after: j)
                    } else {
                        break
                    }
                }
                let token = String(block[i..<j])
                let before = i > block.startIndex ? block[block.index(before: i)] : nil
                let after = j < block.endIndex ? block[j] : nil
                let attachedToIdentifier = before.map(Self.isIdentifierCharacter) == true
                    || after.map(Self.isIdentifierCharacter) == true
                if !attachedToIdentifier,
                   let value = AerospaceConfigSyntax.parseGapNumber(token)
                {
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

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "-"
    }
}
