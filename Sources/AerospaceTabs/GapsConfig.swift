import AppKit
import Foundation

struct OuterGaps: Equatable {
    var top: CGFloat
    var left: CGFloat
    var right: CGFloat

    static let fallback = OuterGaps(top: 28, left: 20, right: 20)
}

/// Reads AeroSpace `gaps.outer.*` from the config file. Cached by mtime — no hot-path work.
final class GapsConfig {
    static let shared = GapsConfig()

    private let locator: AerospaceConfigLocator
    private let readText: (URL) throws -> String
    private var loadedConfigURL: URL?
    private var mtime: Date?
    private var top = GapValue.constant(28)
    private var left = GapValue.constant(20)
    private var right = GapValue.constant(20)
    private var timer: Timer?

    init(
        locator: AerospaceConfigLocator = .shared,
        readText: @escaping (URL) throws -> String = {
            try String(contentsOf: $0, encoding: .utf8)
        }
    ) {
        self.locator = locator
        self.readText = readText
    }

    enum GapValue {
        case constant(CGFloat)
        case perMonitor(pairs: [(pattern: String, value: CGFloat)], fallback: CGFloat)

        func resolve(monitorName: String) -> CGFloat {
            switch self {
            case .constant(let value):
                return value
            case .perMonitor(let pairs, let fallback):
                for pair in pairs where Self.matches(monitorName, pattern: pair.pattern) {
                    return pair.value
                }
                return fallback
            }
        }

        private static func matches(_ name: String, pattern: String) -> Bool {
            let a = name.lowercased()
            let b = pattern.lowercased()
            if a == b || a.contains(b) || b.contains(a) { return true }
            let an = a.filter { $0.isLetter || $0.isNumber }
            let bn = b.filter { $0.isLetter || $0.isNumber }
            return !bn.isEmpty && (an.contains(bn) || bn.contains(an))
        }
    }

    func start() {
        reload(force: true)
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.reload(force: false)
        }
        timer?.tolerance = 0.5
    }

    func gaps(for screen: NSScreen) -> OuterGaps {
        let name = screen.localizedName
        return OuterGaps(
            top: max(top.resolve(monitorName: name), 0),
            left: max(left.resolve(monitorName: name), 0),
            right: max(right.resolve(monitorName: name), 0)
        )
    }

    func reload(force: Bool) {
        let url = locator.location().configURL
        let values = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))
        let newMtime = values?.contentModificationDate
        if !force, url == loadedConfigURL, newMtime == mtime { return }

        guard let text = try? readText(url) else { return }
        if let parsed = Self.parse(text) {
            top = parsed.top
            left = parsed.left
            right = parsed.right
            loadedConfigURL = url
            mtime = newMtime
            NotificationCenter.default.post(name: .aerospaceGapsDidChange, object: nil)
        }
    }

    static func parse(_ text: String) -> (top: GapValue, left: GapValue, right: GapValue)? {
        // Prefer the [gaps] table body; fall back to whole file.
        let body: String
        if let range = text.range(of: #"\[gaps\]"#, options: .regularExpression) {
            let after = text[range.upperBound...]
            if let next = after.range(of: #"^\s*\["#, options: [.regularExpression, .anchored]) {
                // shouldn't happen at start
                _ = next
            }
            if let nextTable = after.range(of: #"\n\s*\[[^\]]+\]"#, options: .regularExpression) {
                body = String(after[..<nextTable.lowerBound])
            } else {
                body = String(after)
            }
        } else {
            body = text
        }

        return (
            top: parseGap(body, key: "outer.top") ?? .constant(28),
            left: parseGap(body, key: "outer.left") ?? .constant(20),
            right: parseGap(body, key: "outer.right") ?? .constant(20)
        )
    }

    private static func parseGap(_ text: String, key: String) -> GapValue? {
        // Find last uncommented assignment for this key.
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var startLine: Int?
        for (i, raw) in lines.enumerated() {
            if AerospaceConfigSyntax.isAssignment(String(raw), key: key) {
                startLine = i
            }
        }
        guard let startLine else { return nil }
        var block = ""
        for i in startLine..<lines.count {
            let line = AerospaceConfigSyntax.strippingInlineComment(from: String(lines[i]))
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if i > startLine, trimmed.hasPrefix("outer.") || trimmed.hasPrefix("inner.") || trimmed.hasPrefix("[") {
                break
            }
            block += trimmed + "\n"
            if trimmed.hasSuffix("]") || (i == startLine && trimmed.contains("=") && !trimmed.contains("[")) {
                // Constant form on one line, or finished array.
                if !trimmed.contains("[") || trimmed.hasSuffix("]") { break }
            }
        }

        guard let eq = block.firstIndex(of: "=") else { return nil }
        let rhs = block[block.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
        if rhs.hasPrefix("[") {
            return parseArray(rhs)
        }
        if let value = Double(rhs.trimmingCharacters(in: CharacterSet(charactersIn: ","))) {
            return .constant(CGFloat(value))
        }
        return nil
    }

    private static func parseArray(_ rhs: String) -> GapValue? {
        var pairs: [(String, CGFloat)] = []
        let pairPattern = #/\{\s*monitor\.(?:"([^"]+)"|([A-Za-z0-9_-]+))\s*=\s*([0-9.]+)\s*\}/#
        var consumed = rhs
        for match in rhs.matches(of: pairPattern) {
            let name = String(match.1 ?? match.2 ?? "")
            if let value = Double(match.3) {
                pairs.append((name, CGFloat(value)))
            }
            consumed = consumed.replacingOccurrences(of: String(match.0), with: " ")
        }
        // Bare fallback number(s) left after removing monitor pairs.
        let barePattern = #/[0-9]+(?:\.[0-9]+)?/#
        var fallback: CGFloat?
        for match in consumed.matches(of: barePattern) {
            if let value = Double(match.0) {
                fallback = CGFloat(value)
            }
        }
        if pairs.isEmpty, let fallback {
            return .constant(fallback)
        }
        return .perMonitor(pairs: pairs, fallback: fallback ?? 20)
    }
}

extension Notification.Name {
    static let aerospaceGapsDidChange = Notification.Name("aerospaceGapsDidChange")
}
