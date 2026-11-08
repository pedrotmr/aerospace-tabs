import Foundation

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
        let backup = try? String(contentsOf: backupURL, encoding: .utf8)
        let marker = try? String(contentsOf: activeURL, encoding: .utf8)
        let targetURL = GapBoostRecoveryState.targetURL(
            backupContents: backup,
            activeMarkerContents: marker,
            fallbackURL: configURL
        )
        return AerospaceConfigLocation(
            candidateURL: candidateURL,
            configURL: targetURL
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
