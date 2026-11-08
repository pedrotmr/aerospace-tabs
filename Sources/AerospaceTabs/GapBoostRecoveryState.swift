import Foundation

struct GapBoostRecoveryState {
    private static let backupHeader = "AEROSPACE_TABS_GAP_BACKUP_V2\n"

    let configURL: URL
    let originalBlock: String?
    let appliedDelta: CGFloat

    init(
        configURL: URL,
        originalBlock: String? = nil,
        appliedDelta: CGFloat
    ) {
        self.configURL = configURL
        self.originalBlock = originalBlock
        self.appliedDelta = appliedDelta
    }

    var serializedBackup: String? {
        guard let originalBlock else { return nil }
        let encodedPath = Data(configURL.path.utf8).base64EncodedString()
        return Self.backupHeader + encodedPath + "\n" + originalBlock
    }

    var serializedActiveMarker: String {
        "\(configURL.path)\n\(appliedDelta)\n"
    }

    static func targetURL(
        backupContents: String?,
        activeMarkerContents: String?,
        fallbackURL: URL
    ) -> URL {
        if let backupURL = decodeBackup(backupContents)?.configURL {
            return backupURL
        }
        if let markerURL = decodeActiveMarker(activeMarkerContents)?.configURL {
            return markerURL
        }
        return fallbackURL
    }

    static func originalBlock(fromBackup contents: String) -> String? {
        guard contents.hasPrefix(backupHeader) else { return contents }
        return decodeBackup(contents)?.originalBlock
    }

    static func appliedDelta(
        fromActiveMarker contents: String?,
        allowedValues: [CGFloat],
        legacyDefault: CGFloat
    ) -> CGFloat {
        guard let marker = decodeActiveMarker(contents),
              let value = marker.appliedDelta,
              allowedValues.contains(value)
        else {
            return legacyDefault
        }
        return value
    }

    private static func decodeBackup(_ contents: String?) -> (configURL: URL, originalBlock: String)? {
        guard let contents, contents.hasPrefix(backupHeader) else { return nil }
        let remainder = contents.dropFirst(backupHeader.count)
        guard let newline = remainder.firstIndex(of: "\n"),
              let pathData = Data(base64Encoded: String(remainder[..<newline])),
              let path = String(data: pathData, encoding: .utf8),
              path.hasPrefix("/")
        else {
            return nil
        }
        return (
            URL(fileURLWithPath: path).standardizedFileURL,
            String(remainder[remainder.index(after: newline)...])
        )
    }

    private static func decodeActiveMarker(_ contents: String?) -> (configURL: URL, appliedDelta: CGFloat?)? {
        guard let contents else { return nil }
        let lines = contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = lines.first, first.hasPrefix("/") else { return nil }
        let delta = lines.dropFirst().first.flatMap { line -> CGFloat? in
            guard let value = Double(String(line)) else { return nil }
            return CGFloat(value)
        }
        return (URL(fileURLWithPath: first).standardizedFileURL, delta)
    }
}
