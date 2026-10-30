import XCTest
import Sparkle
@testable import AerospaceTabs

final class HomebrewInstallDetectorTests: XCTestCase {
    func testUsesSeparateMarkerDomainWithoutChangingAppPreferences() {
        let bundleIdentifier = "com.example.AeroTest.\(UUID().uuidString)"
        let marker = UserDefaults(suiteName: HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier))!
        let bundleURL = URL(fileURLWithPath: "/Applications/AeroTest.app")
        defer { marker.removePersistentDomain(forName: HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier)) }

        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundleURL,
            defaults: marker
        ))
        marker.set(true, forKey: HomebrewInstallDetector.markerKey)
        marker.set("1.0", forKey: HomebrewInstallDetector.versionKey)
        marker.set(bundleURL.path, forKey: HomebrewInstallDetector.bundlePathKey)
        XCTAssertTrue(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundleURL,
            defaults: marker
        ))
        XCTAssertNil(UserDefaults(suiteName: bundleIdentifier)?.object(forKey: HomebrewInstallDetector.markerKey))
    }

    func testHomebrewMarkerSurvivesAnInAppUpdateAtTheSameBundlePath() throws {
        let bundleIdentifier = "com.example.AeroTest.\(UUID().uuidString)"
        let markerDomain = HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier)
        let marker = try XCTUnwrap(UserDefaults(suiteName: markerDomain))
        defer { marker.removePersistentDomain(forName: markerDomain) }

        marker.set(true, forKey: HomebrewInstallDetector.markerKey)
        marker.set("1.0.0", forKey: HomebrewInstallDetector.versionKey)
        let homebrewBundleURL = URL(fileURLWithPath: "/Applications/AeroTest.app")
        marker.set(homebrewBundleURL.path, forKey: HomebrewInstallDetector.bundlePathKey)

        marker.set("2.0.0", forKey: HomebrewInstallDetector.versionKey)
        XCTAssertTrue(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            bundleURL: homebrewBundleURL
        ))
        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            bundleURL: URL(fileURLWithPath: "/Users/example/Downloads/AeroTest.app")
        ))
    }

    func testUpdateCheckPolicyAllowsUserAndInformationChecksButBlocksScheduledChecks() {
        XCTAssertTrue(UpdateCheckPolicy.allows(.updates))
        XCTAssertTrue(UpdateCheckPolicy.allows(.updateInformation))
        XCTAssertFalse(UpdateCheckPolicy.allows(.updatesInBackground))
    }

    func testOnlyInstallableUpdatesHaveAVisibleVersion() {
        XCTAssertEqual(
            UpdateAvailabilityPolicy.installableVersion(isInformationOnlyUpdate: false, displayVersion: "2.0.0"),
            "2.0.0"
        )
        XCTAssertNil(
            UpdateAvailabilityPolicy.installableVersion(isInformationOnlyUpdate: true, displayVersion: "2.0.0")
        )
    }

    func testUpdateProbeScheduleRetriesTransientFailuresAndThenReturnsToNormalInterval() {
        var schedule = UpdateProbeSchedule()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

        for _ in 0..<UpdateProbeSchedule.maximumRetries {
            XCTAssertEqual(
                schedule.nextInterval(after: error, normalInterval: 86_400, automaticChecksEnabled: true),
                .some(UpdateProbeSchedule.retryInterval)
            )
        }

        XCTAssertEqual(
            schedule.nextInterval(after: error, normalInterval: 86_400, automaticChecksEnabled: true),
            .some(86_400)
        )
        XCTAssertEqual(schedule.consecutiveRetries, 0)
    }

    func testNoUpdateIsACompletedProbeAndResetsRetryCount() {
        var schedule = UpdateProbeSchedule()
        let noUpdateError = NSError(domain: SUSparkleErrorDomain, code: Int(SUError.noUpdateError.rawValue))
        let transientError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        _ = schedule.nextInterval(after: transientError, normalInterval: 86_400, automaticChecksEnabled: true)

        XCTAssertEqual(
            schedule.nextInterval(after: noUpdateError, normalInterval: 86_400, automaticChecksEnabled: true),
            .some(86_400)
        )
        XCTAssertEqual(schedule.consecutiveRetries, 0)
    }

    func testChangingAutomaticChecksOffStopsTheNextProbeAndTurningItBackOnResumes() {
        var schedule = UpdateProbeSchedule()

        XCTAssertEqual(
            schedule.nextInterval(after: nil, normalInterval: 86_400, automaticChecksEnabled: true),
            .some(86_400)
        )
        XCTAssertNil(schedule.nextInterval(after: nil, normalInterval: 86_400, automaticChecksEnabled: false))
        XCTAssertEqual(schedule.consecutiveRetries, 0)
        XCTAssertEqual(
            schedule.nextInterval(after: nil, normalInterval: 86_400, automaticChecksEnabled: true),
            .some(86_400)
        )
    }
}
