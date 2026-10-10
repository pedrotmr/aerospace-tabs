import Foundation
import XCTest
@testable import SessionPolicy

final class SessionPolicyTests: XCTestCase {
    func testStripRequiresTwoWindows() {
        XCTAssertFalse(SessionPolicy.shouldShowTabs([]))
        XCTAssertFalse(SessionPolicy.shouldShowTabs([window(1, workspace: "1")]))
        XCTAssertTrue(SessionPolicy.shouldShowTabs([
            window(1, workspace: "1"),
            window(2, workspace: "1"),
        ]))
        let accordionWindows = [
            window(1, workspace: "1", layout: "h_accordion"),
            window(2, workspace: "1", layout: "h_accordion"),
        ]
        XCTAssertTrue(accordionWindows.allSatisfy(\.isAccordion))
        XCTAssertTrue(SessionPolicy.shouldShowTabs(accordionWindows))
    }

    func testGapBoostFollowsStripEligibility() {
        let oneWindow = [window(1, workspace: "1")]
        let twoAccordionWindows = [
            window(2, workspace: "2", layout: "h_accordion"),
            window(3, workspace: "2", layout: "v_accordion"),
        ]

        XCTAssertTrue(SessionPolicy.shouldBoostGaps(windowsByScreen: [oneWindow, twoAccordionWindows]))
        XCTAssertFalse(SessionPolicy.shouldBoostGaps(windowsByScreen: [oneWindow]))
        XCTAssertFalse(SessionPolicy.shouldBoostGaps(windowsByScreen: []))
    }

    func testWindowCyclePoolStaysOnFocusedWorkspaceAndMonitor() {
        let windows = [
            window(1, workspace: "1", screen: 1),
            window(2, workspace: "1", screen: 1),
            window(3, workspace: "2", screen: 1),
            window(4, workspace: "1", screen: 2),
        ]

        XCTAssertEqual(SessionPolicy.cyclePool(windows: windows, focusedID: 2).map(\.id), [1, 2])
    }

    func testWorkspaceCycleUsesTheFocusedMonitorWhenItsWorkspaceIsEmpty() {
        let windows = [
            window(1, workspace: "occupied", screen: 1),
            window(2, workspace: "elsewhere", screen: 2),
            window(3, workspace: "second-here", screen: 1),
        ]

        XCTAssertEqual(
            SessionPolicy.spaceCyclePool(windows: windows, focusedID: nil, focusedScreenIndex: 1),
            ["occupied", "second-here"]
        )
    }

    func testTabOrderSortsNumericSpacesAndAppliesSavedWorkspaceOrder() {
        let windows = [
            window(1, workspace: "mail"),
            window(2, workspace: "10"),
            window(3, workspace: "2"),
            window(4, workspace: "mail"),
            window(5, workspace: "mail"),
        ]

        let ordered = SessionPolicy.applyTabOrder(
            windows,
            preferredIDsByWorkspace: ["mail": [4, 99, 1]]
        )

        XCTAssertEqual(ordered.map(\.id), [3, 2, 4, 1, 5])
    }

    func testNamedWorkspacesKeepTheirFirstSeenOrder() {
        let windows = [
            window(1, workspace: "design"),
            window(2, workspace: "terminal"),
            window(3, workspace: "design"),
        ]

        XCTAssertEqual(SessionPolicy.applyTabOrder(windows, preferredIDsByWorkspace: [:]).map(\.id), [1, 3, 2])
    }

    func testMissionControlDetectionUsesFixtureValuesAndIgnoresDockLayerTwentyAlone() {
        let screen = CGSize(width: 1_440, height: 900)
        let dock = MissionControlWindowInfo(
            owner: "Dock", name: "", layer: 20, width: 1_440, height: 900
        )
        let exposé = MissionControlWindowInfo(
            owner: "WindowManager", name: "", layer: 17, width: 1_440, height: 900
        )

        XCTAssertFalse(MissionControlPolicy.detect(windows: [dock], screenSizes: [screen]))
        XCTAssertTrue(MissionControlPolicy.detect(windows: [exposé], screenSizes: [screen]))
    }

    private func window(
        _ id: Int,
        workspace: String,
        screen: Int = 1,
        layout: String = "h_tiles"
    ) -> Win {
        Win(
            id: id,
            title: "Window \(id)",
            appName: "Test",
            bundleID: "test.bundle",
            bundlePath: "/Applications/Test.app",
            workspace: workspace,
            screenIndex: screen,
            parentLayout: layout
        )
    }
}
