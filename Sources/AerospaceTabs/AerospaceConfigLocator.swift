import Foundation

struct AerospaceGapBackup: Equatable {
    private static let header = "AEROSPACE_TABS_GAP_BACKUP_V2\n"

    let configURL: URL
    let originalBlock: String

    var serialized: String {
        let encodedPath = Data(configURL.path.utf8).base64EncodedString()
        return Self.header + encodedPath + "\n" + originalBlock
    }

    static func decode(_ contents: String) -> AerospaceGapBackup? {
        guard contents.hasPrefix(header) else { return nil }
        let remainder = contents.dropFirst(header.count)
        guard let newline = remainder.firstIndex(of: "\n"),
              let pathData = Data(base64Encoded: String(remainder[..<newline])),
              let path = String(data: pathData, encoding: .utf8),
              path.hasPrefix("/")
        else { return nil }

        return AerospaceGapBackup(
            configURL: URL(fileURLWithPath: path).standardizedFileURL,
            originalBlock: String(remainder[remainder.index(after: newline)...])
        )
    }

    static func originalBlock(from contents: String) -> String? {
        guard contents.hasPrefix(header) else { return contents }
        return decode(contents)?.originalBlock
    }
}

struct AerospaceConfigLocation: Equatable {
    let candidateURL: URL
    let configURL: URL

    var backupURL: URL {
        candidateURL.deletingLastPathComponent()
            .appendingPathComponent(".aerospace-tabs-outer-top.backup")
    }

    var activeURL: URL {
        candidateURL.deletingLastPathComponent()
            .appendingPathComponent(".aerospace-tabs-gap-boost.active")
    }

    func hasRecoveryState(fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: backupURL.path)
            || fileManager.fileExists(atPath: activeURL.path)
    }

    func pinnedForRecovery() -> AerospaceConfigLocation {
        if let contents = try? String(contentsOf: backupURL, encoding: .utf8),
           let backup = AerospaceGapBackup.decode(contents)
        {
            return AerospaceConfigLocation(
                candidateURL: candidateURL,
                configURL: backup.configURL
            )
        }
        guard let marker = try? String(contentsOf: activeURL, encoding: .utf8) else {
            return self
        }
        let path = marker.trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.hasPrefix("/") else { return self }
        return AerospaceConfigLocation(
            candidateURL: candidateURL,
            configURL: URL(fileURLWithPath: path).standardizedFileURL
        )
    }
}

/// Resolves the AeroSpace config on every access so readers and writers use the
/// same candidate. Recovery state stays beside the logical config path, while
/// its marker pins the resolved write target until restoration is complete.
final class AerospaceConfigLocator {
    static let shared = AerospaceConfigLocator()

    private let fileManager: FileManager
    private let candidates: () -> [URL]

    init(
        fileManager: FileManager = .default,
        candidates: @escaping () -> [URL] = AerospaceConfigLocator.defaultCandidates
    ) {
        self.fileManager = fileManager
        self.candidates = candidates
    }

    func location() -> AerospaceConfigLocation {
        let locations = candidates().map { candidate in
            AerospaceConfigLocation(
                candidateURL: candidate,
                configURL: candidate.resolvingSymlinksInPath().standardizedFileURL
            )
        }

        if let recovering = locations.first(where: { $0.hasRecoveryState(fileManager: fileManager) }) {
            return recovering.pinnedForRecovery()
        }
        if let readable = locations.first(where: {
            fileManager.isReadableFile(atPath: $0.candidateURL.path)
        }) {
            return readable
        }
        return locations.last ?? Self.fallbackLocation()
    }

    private static func defaultCandidates() -> [URL] {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return [
            home.appendingPathComponent(".aerospace.toml"),
            home.appendingPathComponent(".config/aerospace/aerospace.toml"),
        ]
    }

    private static func fallbackLocation() -> AerospaceConfigLocation {
        let candidate = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".config/aerospace/aerospace.toml")
        return AerospaceConfigLocation(
            candidateURL: candidate,
            configURL: candidate.resolvingSymlinksInPath().standardizedFileURL
        )
    }
}

enum AerospaceConfigSyntax {
    static func isAssignment(_ line: String, key: String) -> Bool {
        let content = strippingInlineComment(from: line)
            .trimmingCharacters(in: .whitespaces)
        for candidate in [key, "gaps.\(key)"] where content.hasPrefix(candidate) {
            let rest = content.dropFirst(candidate.count)
                .drop(while: { $0 == " " || $0 == "\t" })
            if rest.first == "=" {
                return true
            }
        }
        return false
    }

    static func strippingInlineComment(from line: String) -> String {
        var quote: Character?
        var escaped = false

        for index in line.indices {
            let character = line[index]
            if let currentQuote = quote {
                if currentQuote == "\"" && character == "\\" && !escaped {
                    escaped = true
                    continue
                }
                if character == currentQuote && !escaped {
                    quote = nil
                }
                escaped = false
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
            } else if character == "#" {
                return String(line[..<index])
            }
        }
        return line
    }

    static func containsUnquoted(_ sought: Character, in text: String) -> Bool {
        charactersOutsideQuotes(in: text).contains(sought)
    }

    static func charactersOutsideQuotes(in text: String) -> [Character] {
        var quote: Character?
        var escaped = false
        var result: [Character] = []

        for character in strippingInlineComment(from: text) {
            if let currentQuote = quote {
                if currentQuote == "\"" && character == "\\" && !escaped {
                    escaped = true
                    continue
                }
                if character == currentQuote && !escaped {
                    quote = nil
                }
                escaped = false
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
            } else {
                result.append(character)
            }
        }
        return result
    }
}
