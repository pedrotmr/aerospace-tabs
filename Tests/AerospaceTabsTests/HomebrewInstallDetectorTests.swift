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

    func testHomebrewUpdatePolicyAllowsUpdateFlowsButBlocksScheduledChecks() {
        XCTAssertTrue(HomebrewUpdateCheckPolicy.allows(.updates, managedByHomebrew: true))
        XCTAssertFalse(HomebrewUpdateCheckPolicy.allows(.updatesInBackground, managedByHomebrew: true))
        XCTAssertTrue(HomebrewUpdateCheckPolicy.allows(.updatesInBackground, managedByHomebrew: false))
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
}
