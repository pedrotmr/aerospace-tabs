import Foundation
import XCTest
@testable import AerospaceTabs

final class ConfigGapTests: XCTestCase {
    func testIsUneditedBoostRequiresExactAppliedDelta() {
        let backup = "outer.top = 10"
        let boosted40 = "outer.top = 50"
        let boosted34 = "outer.top = 44"
        XCTAssertTrue(GapBoost.isUneditedBoost(current: boosted40, backup: backup, delta: 40))
        XCTAssertFalse(GapBoost.isUneditedBoost(current: boosted34, backup: backup, delta: 40))
        XCTAssertTrue(GapBoost.isUneditedBoost(current: boosted34, backup: backup, delta: 34))
        XCTAssertFalse(GapBoost.isUneditedBoost(current: "outer.top = 99", backup: backup, delta: 40))
    }

    func testAppliedDeltaDefaultsPathOnlyMarkerToStripHeight() {
        XCTAssertEqual(GapBoost.appliedDelta(fromActiveMarker: nil), GapBoost.stripHeight)
        XCTAssertEqual(
            GapBoost.appliedDelta(fromActiveMarker: "/tmp/aerospace.toml\n"),
            GapBoost.stripHeight
        )
        XCTAssertEqual(
            GapBoost.appliedDelta(fromActiveMarker: "/tmp/aerospace.toml\n40\n"),
            40
        )
    }

    func testEditedLegacyBoostSubtractsPersistedStripHeightNotCurrentBoost() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let original = "[gaps]\nouter.top = 10\n"
        try original.write(to: fixture.target, atomically: true, encoding: .utf8)
        let location = fixture.locator.location()

        let backup = AerospaceGapBackup(configURL: fixture.target, originalBlock: "outer.top = 10")
        try backup.serialized.write(to: location.backupURL, atomically: true, encoding: .utf8)
        // Path-only active marker from a pre-clearance build (implicit delta 34).
        try fixture.target.path.write(to: location.activeURL, atomically: true, encoding: .utf8)
        // Live value was 44 (10+34), then edited +5 while still boosted.
        try "[gaps]\nouter.top = 49\n".write(to: fixture.target, atomically: true, encoding: .utf8)

        let boost = GapBoost(locator: fixture.locator, reloadHandler: {})
        XCTAssertTrue(boost.restoreIfNeeded(reload: false))
        XCTAssertEqual(
            try String(contentsOf: fixture.target, encoding: .utf8),
            "[gaps]\nouter.top = 15\n"
        )
    }

    func testEditedCurrentBoostMatchingLegacyCandidateSubtractsAppliedDelta() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let original = "[gaps]\nouter.top = 10\n"
        try original.write(to: fixture.target, atomically: true, encoding: .utf8)
        let location = fixture.locator.location()

        let backup = AerospaceGapBackup(configURL: fixture.target, originalBlock: "outer.top = 10")
        try backup.serialized.write(to: location.backupURL, atomically: true, encoding: .utf8)
        try "\(fixture.target.path)\n40\n".write(to: location.activeURL, atomically: true, encoding: .utf8)
        // Live was 50 (10+40); user edited to 44, which equals a legacy 10+34 candidate.
        try "[gaps]\nouter.top = 44\n".write(to: fixture.target, atomically: true, encoding: .utf8)

        let boost = GapBoost(locator: fixture.locator, reloadHandler: {})
        XCTAssertTrue(boost.restoreIfNeeded(reload: false))
        XCTAssertEqual(
            try String(contentsOf: fixture.target, encoding: .utf8),
            "[gaps]\nouter.top = 4\n"
        )
    }

    func testUnterminatedOuterTopArrayHasNoRange() {
        let text = """
        [gaps]
        outer.top = [
            { monitor.main = 20 },

        [mode.main.binding]
        1 = "workspace 1"
        """

        XCTAssertNil(GapBoost.outerTopBlockRange(in: text))
    }

    func testOuterTopRangeSupportsDottedAssignmentAndExactKeyMatching() {
        let text = """
        gaps.outer.topology = 99
        gaps.outer.top = 20
        """

        let range = GapBoost.outerTopBlockRange(in: text)

        XCTAssertNotNil(range)
        XCTAssertTrue(range.map { text[$0].hasPrefix("gaps.outer.top = 20") } == true)
    }

    func testShiftNumbersLeavesIdentifierQuotedAndCommentDigitsAlone() {
        let block = #"""
        outer.top = [
            { monitor.main2 = 10 },
            { monitor."Side 3" = 20 },
            4, # keep 99 in this comment
        ]
        """#

        let shifted = GapBoost.shiftNumbers(in: block, by: 34)

        XCTAssertTrue(shifted.contains("monitor.main2 = 44"))
        XCTAssertTrue(shifted.contains(#"monitor."Side 3" = 54"#))
        XCTAssertTrue(shifted.contains("38, # keep 99 in this comment"))
    }

    func testShiftNumbersPreservesNumericMonitorKey() {
        let block = """
        outer.top = [
            { monitor.2 = 10 },
            20,
        ]
        """

        let shifted = GapBoost.shiftNumbers(in: block, by: 34)

        XCTAssertTrue(shifted.contains("monitor.2 = 44"))
        XCTAssertFalse(shifted.contains("monitor.36"))
    }

    func testGapParserIgnoresCommentNumbersButKeepsHashesInsideQuotes() throws {
        let text = #"""
        [gaps]
        outer.top = [
            { monitor."Studio #2" = 12 },
            20, # 999 must not become the fallback
        ]
        outer.left = 8
        outer.right = 9
        """#

        let parsed = try XCTUnwrap(GapsConfig.parse(text))

        XCTAssertEqual(parsed.top.resolve(monitorName: "Studio #2"), 12)
        XCTAssertEqual(parsed.top.resolve(monitorName: "Other"), 20)
    }

    func testUnderscoredGapNumbersParseBoostAndRestore() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let original = """
        [gaps]
        outer.top = [
            { monitor.main_2 = 1_000 },
            2_000,
        ]
        outer.left = 1_234.5_0

        """
        try original.write(to: fixture.target, atomically: true, encoding: .utf8)
        let parsed = try XCTUnwrap(GapsConfig.parse(original))

        XCTAssertEqual(parsed.top.resolve(monitorName: "main_2"), 1_000)
        XCTAssertEqual(parsed.top.resolve(monitorName: "other"), 2_000)
        XCTAssertEqual(parsed.left.resolve(monitorName: "other"), 1_234.50)

        let boost = GapBoost(locator: fixture.locator, reloadHandler: {})
        boost.sync(shouldBoost: true)
        let boosted = try String(contentsOf: fixture.target, encoding: .utf8)
        XCTAssertTrue(boosted.contains("monitor.main_2 = 1040"))
        XCTAssertTrue(boosted.contains("2040,"))

        boost.sync(shouldBoost: false)
        XCTAssertEqual(try String(contentsOf: fixture.target, encoding: .utf8), original)
    }

    func testSignedAndExponentGapNumbersParseBoostAndRestore() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let original = """
        [gaps]
        outer.top = [
            { monitor.main = +1e2 },
            2.5e1,
        ]
        outer.left = +1_0e0

        """
        try original.write(to: fixture.target, atomically: true, encoding: .utf8)
        let parsed = try XCTUnwrap(GapsConfig.parse(original))

        XCTAssertEqual(parsed.top.resolve(monitorName: "main"), 100)
        XCTAssertEqual(parsed.top.resolve(monitorName: "other"), 25)
        XCTAssertEqual(parsed.left.resolve(monitorName: "other"), 10)
        XCTAssertNil(AerospaceConfigSyntax.parseGapNumber("1__0"))
        XCTAssertNil(AerospaceConfigSyntax.parseGapNumber("1e_2"))

        let boost = GapBoost(locator: fixture.locator, reloadHandler: {})
        boost.sync(shouldBoost: true)
        let boosted = try String(contentsOf: fixture.target, encoding: .utf8)
        XCTAssertTrue(boosted.contains("monitor.main = 140"))
        XCTAssertTrue(boosted.contains("65,"))

        boost.sync(shouldBoost: false)
        XCTAssertEqual(try String(contentsOf: fixture.target, encoding: .utf8), original)
    }

    func testInvalidMonitorValueDoesNotLeakIntoArrayFallback() throws {
        let text = """
        [gaps]
        outer.top = [
            20,
            { monitor.2 = 1__0 },
        ]
        """

        let parsed = try XCTUnwrap(GapsConfig.parse(text))

        XCTAssertEqual(parsed.top.resolve(monitorName: "2"), 20)
        XCTAssertEqual(parsed.top.resolve(monitorName: "other"), 20)
    }

    func testRestoreRecognizesAlreadyRestoredBlockAndOnlyCleansState() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let original = "[gaps]\nouter.top = 10\n"
        try original.write(to: fixture.target, atomically: true, encoding: .utf8)
        let location = fixture.locator.location()
        let range = try XCTUnwrap(GapBoost.outerTopBlockRange(in: original))
        try String(original[range]).write(to: location.backupURL, atomically: true, encoding: .utf8)
        try fixture.target.path.write(to: location.activeURL, atomically: true, encoding: .utf8)
        let boost = GapBoost(locator: fixture.locator, reloadHandler: {})

        XCTAssertTrue(boost.restoreIfNeeded(reload: false))
        XCTAssertEqual(try String(contentsOf: fixture.target, encoding: .utf8), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: location.backupURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: location.activeURL.path))
    }

    func testFailedRestoreKeepsRecoveryState() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try "[gaps]\nouter.left = 10\n".write(
            to: fixture.target,
            atomically: true,
            encoding: .utf8
        )
        let location = fixture.locator.location()
        try "outer.top = 10\n".write(to: location.backupURL, atomically: true, encoding: .utf8)
        try fixture.target.path.write(to: location.activeURL, atomically: true, encoding: .utf8)
        let boost = GapBoost(locator: fixture.locator, reloadHandler: {})

        XCTAssertFalse(boost.restoreIfNeeded(reload: false))
        XCTAssertTrue(FileManager.default.fileExists(atPath: location.backupURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: location.activeURL.path))
    }

    func testReloadDoesNotWaitForChildProcessExit() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try "[gaps]\nouter.top = 10\n".write(
            to: fixture.target,
            atomically: true,
            encoding: .utf8
        )
        let release = fixture.root.appendingPathComponent("release-reload")
        defer { try? "".write(to: release, atomically: true, encoding: .utf8) }
        let executable = fixture.root.appendingPathComponent("slow-reload")
        let script = "#!/bin/sh\nwhile [ ! -e '\(release.path)' ]; do sleep 0.01; done\n"
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        let childExited = DispatchSemaphore(value: 0)
        let boost = GapBoost(
            locator: fixture.locator,
            reloadExecutableURL: executable,
            reloadDidTerminate: { childExited.signal() }
        )
        let returned = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            boost.sync(shouldBoost: true)
            returned.signal()
        }

        let result = returned.wait(timeout: .now() + 2)
        try "".write(to: release, atomically: true, encoding: .utf8)
        if result == .timedOut {
            _ = returned.wait(timeout: .now() + 2)
        }

        XCTAssertEqual(result, .success, "sync waited for the reload child to exit")
        XCTAssertEqual(childExited.wait(timeout: .now() + 2), .success)
    }

    func testBoostWritesResolvedTargetWithoutReplacingSymlink() throws {
        let fixture = try Fixture(useSymlink: true)
        defer { fixture.remove() }
        try "[gaps]\nouter.top = 10\n".write(
            to: fixture.target,
            atomically: true,
            encoding: .utf8
        )
        var reloads = 0
        let boost = GapBoost(locator: fixture.locator, reloadHandler: { reloads += 1 })

        boost.sync(shouldBoost: true)

        XCTAssertNoThrow(try FileManager.default.destinationOfSymbolicLink(atPath: fixture.candidate.path))
        XCTAssertEqual(
            try String(contentsOf: fixture.target, encoding: .utf8),
            "[gaps]\nouter.top = 50\n"
        )
        let location = fixture.locator.location()
        XCTAssertEqual(location.configURL, fixture.target.standardizedFileURL)
        XCTAssertEqual(location.backupURL.deletingLastPathComponent(), fixture.candidate.deletingLastPathComponent())

        boost.sync(shouldBoost: false)

        XCTAssertEqual(
            try String(contentsOf: fixture.target, encoding: .utf8),
            "[gaps]\nouter.top = 10\n"
        )
        XCTAssertEqual(reloads, 2)
    }

    func testRecoveryMarkerPinsOriginalSymlinkTarget() throws {
        let fixture = try Fixture(useSymlink: true)
        defer { fixture.remove() }
        let otherTarget = fixture.root.appendingPathComponent("other.toml")
        try "gaps.outer.top = 1\n".write(to: otherTarget, atomically: true, encoding: .utf8)
        let initial = fixture.locator.location()
        try "gaps.outer.top = 10\n".write(to: initial.backupURL, atomically: true, encoding: .utf8)
        try fixture.target.path.write(to: initial.activeURL, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: fixture.candidate)
        try FileManager.default.createSymbolicLink(at: fixture.candidate, withDestinationURL: otherTarget)

        XCTAssertEqual(fixture.locator.location().configURL, fixture.target.standardizedFileURL)
    }

    func testBackupAlonePinsAndRestoresOriginalSymlinkTarget() throws {
        let fixture = try Fixture(useSymlink: true)
        defer { fixture.remove() }
        let original = "gaps.outer.top = 10\n"
        let otherTarget = fixture.root.appendingPathComponent("other.toml")
        try original.write(to: fixture.target, atomically: true, encoding: .utf8)
        try "gaps.outer.top = 1\n".write(to: otherTarget, atomically: true, encoding: .utf8)
        let boost = GapBoost(locator: fixture.locator, reloadHandler: {})
        boost.sync(shouldBoost: true)
        let boostedLocation = fixture.locator.location()
        // Simulate a verified restore followed by a crash after marker cleanup.
        try original.write(to: fixture.target, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: boostedLocation.activeURL)
        try FileManager.default.removeItem(at: fixture.candidate)
        try FileManager.default.createSymbolicLink(at: fixture.candidate, withDestinationURL: otherTarget)

        XCTAssertEqual(fixture.locator.location().configURL, fixture.target.standardizedFileURL)
        XCTAssertTrue(boost.restoreIfNeeded(reload: false))
        XCTAssertEqual(try String(contentsOf: fixture.target, encoding: .utf8), original)
        XCTAssertEqual(
            try String(contentsOf: otherTarget, encoding: .utf8),
            "gaps.outer.top = 1\n"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: boostedLocation.backupURL.path))
    }

    func testLocatorRefreshesCandidatesButKeepsRecoveryLocationSelected() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AerospaceTabsTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let preferredDirectory = root.appendingPathComponent("preferred", isDirectory: true)
        let fallbackDirectory = root.appendingPathComponent("fallback", isDirectory: true)
        try FileManager.default.createDirectory(at: preferredDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)
        let preferred = preferredDirectory.appendingPathComponent("aerospace.toml")
        let fallback = fallbackDirectory.appendingPathComponent("aerospace.toml")
        try "outer.top = 20\n".write(to: fallback, atomically: true, encoding: .utf8)
        let locator = AerospaceConfigLocator(candidates: { [preferred, fallback] })

        XCTAssertEqual(locator.location().candidateURL, fallback)

        try "outer.top = 10\n".write(to: preferred, atomically: true, encoding: .utf8)
        XCTAssertEqual(locator.location().candidateURL, preferred)

        let fallbackLocation = AerospaceConfigLocation(candidateURL: fallback, configURL: fallback)
        try "outer.top = 20\n".write(
            to: fallbackLocation.backupURL,
            atomically: true,
            encoding: .utf8
        )
        XCTAssertEqual(locator.location().candidateURL, fallback)
    }

    func testTransientReadFailureDoesNotSuppressRetryAtSameMtime() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try "[gaps]\nouter.top = 10\n".write(
            to: fixture.target,
            atomically: true,
            encoding: .utf8
        )
        var attempts = 0
        let config = GapsConfig(locator: fixture.locator) { url in
            attempts += 1
            if attempts == 1 {
                throw CocoaError(.fileReadUnknown)
            }
            return try String(contentsOf: url, encoding: .utf8)
        }

        config.reload(force: false)
        config.reload(force: false)

        XCTAssertEqual(attempts, 2)
    }

}

private final class Fixture {
    let root: URL
    let candidate: URL
    let target: URL
    let locator: AerospaceConfigLocator

    init(useSymlink: Bool = false) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AerospaceTabsTests-\(UUID().uuidString)", isDirectory: true)
        let configDirectory = root.appendingPathComponent("config", isDirectory: true)
        let targetDirectory = root.appendingPathComponent("dotfiles", isDirectory: true)
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        candidate = configDirectory.appendingPathComponent("aerospace.toml")
        target = useSymlink
            ? targetDirectory.appendingPathComponent("aerospace.toml")
            : candidate
        if useSymlink {
            try "".write(to: target, atomically: true, encoding: .utf8)
            try FileManager.default.createSymbolicLink(at: candidate, withDestinationURL: target)
        }
        let selectedCandidate = candidate
        locator = AerospaceConfigLocator(candidates: { [selectedCandidate] in [selectedCandidate] })
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
