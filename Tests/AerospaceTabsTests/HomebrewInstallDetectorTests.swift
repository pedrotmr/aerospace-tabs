import XCTest
@testable import AerospaceTabs

final class HomebrewInstallDetectorTests: XCTestCase {
    func testUsesSeparateMarkerDomainWithoutChangingAppPreferences() {
        let bundleIdentifier = "com.example.AeroTest.\(UUID().uuidString)"
        let marker = UserDefaults(suiteName: HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier))!
        let bundleURL = URL(fileURLWithPath: "/Applications/AeroTest.app")
        defer { marker.removePersistentDomain(forName: HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier)) }

        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: "1.0",
            bundleURL: bundleURL,
            defaults: marker
        ))
        marker.set(true, forKey: HomebrewInstallDetector.markerKey)
        marker.set("1.0", forKey: HomebrewInstallDetector.versionKey)
        marker.set(bundleURL.path, forKey: HomebrewInstallDetector.bundlePathKey)
        XCTAssertTrue(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: "1.0",
            bundleURL: bundleURL,
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
        let homebrewBundleURL = URL(fileURLWithPath: "/Applications/AeroTest.app")
        marker.set(homebrewBundleURL.path, forKey: HomebrewInstallDetector.bundlePathKey)

        XCTAssertTrue(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: "1.0.0",
            bundleURL: homebrewBundleURL
        ))
        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: "1.0.1",
            bundleURL: homebrewBundleURL
        ))
        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: "1.0.0",
            bundleURL: URL(fileURLWithPath: "/Users/example/Downloads/AeroTest.app")
        ))
    }
}
