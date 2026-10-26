import XCTest
@testable import AerospaceTabs

final class HomebrewInstallDetectorTests: XCTestCase {
    func testUsesSeparateMarkerDomainWithoutChangingAppPreferences() {
        let bundleIdentifier = "com.example.AeroTest.\(UUID().uuidString)"
        let marker = UserDefaults(suiteName: HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier))!
        defer { marker.removePersistentDomain(forName: HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier)) }

        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier, defaults: marker))
        marker.set(true, forKey: HomebrewInstallDetector.markerKey)
        XCTAssertTrue(HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier, defaults: marker))
        XCTAssertNil(UserDefaults(suiteName: bundleIdentifier)?.object(forKey: HomebrewInstallDetector.markerKey))
    }
}
