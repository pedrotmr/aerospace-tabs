import XCTest
@testable import AerospaceTabs

final class HomebrewInstallDetectorTests: XCTestCase {
    func testUsesSeparateMarkerDomainWithoutChangingAppPreferences() {
        let bundleIdentifier = "com.example.AeroTest.\(UUID().uuidString)"
        let marker = UserDefaults(suiteName: HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier))!
        defer { marker.removePersistentDomain(forName: HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier)) }

        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: "1.0",
            defaults: marker
        ))
        marker.set(true, forKey: HomebrewInstallDetector.markerKey)
        marker.set("1.0", forKey: HomebrewInstallDetector.versionKey)
        XCTAssertTrue(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: "1.0",
            defaults: marker
        ))
        XCTAssertNil(UserDefaults(suiteName: bundleIdentifier)?.object(forKey: HomebrewInstallDetector.markerKey))
    }

    func testInstalledAppVersionMustMatchHomebrewMarkerFromProductionDefaultsPath() throws {
        let bundleIdentifier = "com.example.AeroTest.\(UUID().uuidString)"
        let markerDomain = HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier)
        let marker = try XCTUnwrap(UserDefaults(suiteName: markerDomain))
        defer { marker.removePersistentDomain(forName: markerDomain) }

        marker.set(true, forKey: HomebrewInstallDetector.markerKey)
        marker.set("1.0.0", forKey: HomebrewInstallDetector.versionKey)

        XCTAssertTrue(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: "1.0.0"
        ))
        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: "1.0.1"
        ))
    }
}
