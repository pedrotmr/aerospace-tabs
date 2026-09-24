import XCTest

@testable import AerospaceTabs

final class SessionTests: XCTestCase {
    func testApplyingSnapshotClearsStaleFocusedWindow() {
        let session = Session()
        let window = Win(
            id: 42,
            title: "Terminal",
            appName: "Terminal",
            bundleID: "com.apple.Terminal",
            bundlePath: "/System/Applications/Utilities/Terminal.app",
            workspace: "main",
            screenIndex: 1,
            parentLayout: "h_tiles"
        )
        session.windows = [window]
        session.focusedID = window.id

        var changeCount = 0
        session.onChange = { changeCount += 1 }

        let unfocusedSnapshot = Snapshot(windows: [window], focused: nil)
        session.apply(unfocusedSnapshot)

        XCTAssertNil(session.focusedID)
        XCTAssertEqual(changeCount, 1)

        session.apply(unfocusedSnapshot)
        XCTAssertEqual(changeCount, 1, "An unchanged nil focus should not keep triggering updates")
    }

    func testWindowCyclingDoesNotFallBackToVisibleWindowsOnAnotherMonitor() {
        let session = Session()
        let visibleElsewhere = makeWindow(
            id: 99,
            workspace: "other-monitor",
            screenIndex: 2,
            workspaceIsVisible: true
        )
        session.apply(Snapshot(
            windows: [visibleElsewhere],
            focused: nil,
            focusedWorkspace: "empty",
            focusedScreenIndex: 1
        ))

        XCTAssertTrue(session.cyclePool().isEmpty)
    }

    func testSpaceCyclingStaysOnFocusedMonitorWhenItsWorkspaceIsEmpty() {
        let session = Session()
        let hiddenOnFocusedMonitor = makeWindow(
            id: 1,
            workspace: "occupied-here",
            screenIndex: 1
        )
        let visibleElsewhere = makeWindow(
            id: 2,
            workspace: "other-monitor",
            screenIndex: 2,
            workspaceIsVisible: true
        )
        session.apply(Snapshot(
            windows: [hiddenOnFocusedMonitor, visibleElsewhere],
            focused: nil,
            focusedWorkspace: "empty",
            focusedScreenIndex: 1
        ))

        XCTAssertEqual(session.spaceCyclePool(), ["occupied-here"])
    }

    private func makeWindow(
        id: Int,
        workspace: String,
        screenIndex: Int,
        workspaceIsVisible: Bool = false
    ) -> Win {
        Win(
            id: id,
            title: "Window \(id)",
            appName: "Test",
            bundleID: "test.bundle",
            bundlePath: "/Applications/Test.app",
            workspace: workspace,
            screenIndex: screenIndex,
            parentLayout: "h_tiles",
            workspaceIsVisible: workspaceIsVisible
        )
    }
}
