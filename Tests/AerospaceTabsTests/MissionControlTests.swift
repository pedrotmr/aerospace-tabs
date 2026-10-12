import CoreGraphics
import XCTest
import SessionPolicy
@testable import AerospaceTabs

final class MissionControlTests: XCTestCase {
    private let screenSizes = [CGSize(width: 1_440, height: 900)]

    func testThirdPartyWindowNamesDoNotTriggerDetection() {
        let windows = [
            window(owner: "Notes", name: "Mission Control"),
            window(owner: "My Switcher", name: "Window Switcher"),
            window(owner: "Demo", name: "App Exposé"),
        ]

        XCTAssertFalse(MissionControlPolicy.detect(windows: windows, screenSizes: screenSizes))
    }

    func testSystemOwnerAndActivityNameTriggerDetection() {
        let windows = [window(owner: "Dock", name: "App Exposé")]

        XCTAssertTrue(MissionControlPolicy.detect(windows: windows, screenSizes: screenSizes))
    }

    func testWindowManagerSurfaceStillTriggersDetection() {
        let windows = [
            window(
                owner: "WindowManager",
                layer: 17,
                width: 1_440,
                height: 900
            ),
        ]

        XCTAssertTrue(MissionControlPolicy.detect(windows: windows, screenSizes: screenSizes))
    }

    func testDockLayerTwentyAloneDoesNotTriggerDetection() {
        let windows = [
            window(
                owner: "Dock",
                layer: 20,
                width: 1_440,
                height: 900
            ),
        ]

        XCTAssertFalse(MissionControlPolicy.detect(windows: windows, screenSizes: screenSizes))
    }

    func testMissionControlDebouncerEntersAfterThreeConsecutiveDetections() {
        var debouncer = MissionControlDebouncer()

        XCTAssertNil(debouncer.update(detected: true))
        XCTAssertNil(debouncer.update(detected: true))
        XCTAssertEqual(debouncer.update(detected: true), true)
        XCTAssertTrue(debouncer.isActive)
    }

    func testMissionControlDebouncerMissResetsEntryStreak() {
        var debouncer = MissionControlDebouncer()

        XCTAssertNil(debouncer.update(detected: true))
        XCTAssertNil(debouncer.update(detected: false))
        XCTAssertNil(debouncer.update(detected: true))
        XCTAssertNil(debouncer.update(detected: true))
        XCTAssertFalse(debouncer.isActive)
        XCTAssertEqual(debouncer.update(detected: true), true)
        XCTAssertTrue(debouncer.isActive)
    }

    func testMissionControlDebouncerClearsOnFirstMissAfterActivation() {
        var debouncer = MissionControlDebouncer()
        _ = debouncer.update(detected: true)
        _ = debouncer.update(detected: true)
        _ = debouncer.update(detected: true)
        XCTAssertTrue(debouncer.isActive)

        XCTAssertEqual(debouncer.update(detected: false), false)
        XCTAssertFalse(debouncer.isActive)
    }

    private func window(
        owner: String,
        name: String = "",
        layer: Int = 0,
        width: CGFloat = 0,
        height: CGFloat = 0
    ) -> MissionControlWindowInfo {
        MissionControlWindowInfo(
            owner: owner,
            name: name,
            layer: layer,
            width: width,
            height: height
        )
    }
}
