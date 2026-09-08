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
}
