import XCTest
@testable import AerospaceTabs

final class HotkeysTests: XCTestCase {
    func testInstallationFailurePresentationIsScheduled() throws {
        var scheduledPresentation: (() -> Void)?
        var presentedError: HotkeyInstallationError?
        let hotkeys = Hotkeys(
            scheduleFailurePresentation: { scheduledPresentation = $0 },
            presentInstallationFailure: { presentedError = $0 }
        )
        let error = HotkeyInstallationError.forwardHotKey(status: -1)

        hotkeys.reportInstallationFailure(error)

        XCTAssertNil(presentedError)
        let presentation = try XCTUnwrap(scheduledPresentation)
        presentation()
        XCTAssertEqual(presentedError, error)
    }
}
