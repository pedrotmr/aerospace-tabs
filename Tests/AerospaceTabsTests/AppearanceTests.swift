import XCTest
@testable import AerospaceTabs

final class AppearanceTests: XCTestCase {
    func testThemeTitlesCoverEveryCase() {
        XCTAssertEqual(StripTheme.allCases.map(\.title), ["Glass", "Solid"])
    }

    func testGlassHidesWashAndSolidProvidesWash() {
        XCTAssertNil(StripTheme.glass.chrome.wash)
        XCTAssertNotNil(StripTheme.solid.chrome.wash)
    }

    func testAppearanceSettingsPersistsSelection() {
        let suite = "AerospaceTabs.AppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppearanceSettings(defaults: defaults)
        XCTAssertEqual(settings.theme, .glass)

        var notified = 0
        let observer = NotificationCenter.default.addObserver(
            forName: AppearanceSettings.didChangeNotification,
            object: settings,
            queue: nil
        ) { _ in notified += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        settings.select(.solid)
        XCTAssertEqual(settings.theme, .solid)
        XCTAssertEqual(notified, 1)
        XCTAssertEqual(defaults.string(forKey: AppearanceSettings.themeDefaultsKey), "solid")

        settings.select(.solid)
        XCTAssertEqual(notified, 1)

        let reloaded = AppearanceSettings(defaults: defaults)
        XCTAssertEqual(reloaded.theme, .solid)
    }

    func testUnknownSavedThemeFallsBackToGlass() {
        let suite = "AerospaceTabs.AppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("neon", forKey: AppearanceSettings.themeDefaultsKey)

        let settings = AppearanceSettings(defaults: defaults)
        XCTAssertEqual(settings.theme, .glass)
    }
}
