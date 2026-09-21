import CoreGraphics
import XCTest
@testable import AerospaceTabs

final class MissionControlTests: XCTestCase {
    private let screenSizes = [CGSize(width: 1_440, height: 900)]

    func testGapBoostStaysOnWhileMissionControlHidesStrip() {
        // Opening Mission Control must not restore outer.top — that reloads
        // AeroSpace and shifts every tiled window by the boost amount.
        XCTAssertTrue(
            AppDelegate.shouldBoostGaps(anyStripVisible: true, missionControlActive: true)
        )
        XCTAssertTrue(
            AppDelegate.shouldBoostGaps(anyStripVisible: true, missionControlActive: false)
        )
        XCTAssertFalse(
            AppDelegate.shouldBoostGaps(anyStripVisible: false, missionControlActive: true)
        )
        XCTAssertFalse(
            AppDelegate.shouldBoostGaps(anyStripVisible: false, missionControlActive: false)
        )
    }

    func testThirdPartyWindowNamesDoNotTriggerDetection() {
        let windows = [
            window(owner: "Notes", name: "Mission Control"),
            window(owner: "My Switcher", name: "Window Switcher"),
            window(owner: "Demo", name: "App Exposé"),
        ]

        XCTAssertFalse(MissionControlWatcher.detect(windows: windows, screenSizes: screenSizes))
    }

    func testSystemOwnerAndActivityNameTriggerDetection() {
        let windows = [window(owner: "Dock", name: "App Exposé")]

        XCTAssertTrue(MissionControlWatcher.detect(windows: windows, screenSizes: screenSizes))
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

        XCTAssertTrue(MissionControlWatcher.detect(windows: windows, screenSizes: screenSizes))
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

        XCTAssertFalse(MissionControlWatcher.detect(windows: windows, screenSizes: screenSizes))
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
