import AppKit
import XCTest
@testable import AerospaceTabs

final class WindowPreviewStoreTests: XCTestCase {
    @MainActor
    func testClosedOverviewDoesNotCaptureOnWindowOrVisibilityUpdates() async {
        let capture = expectation(description: "No captures while closed")
        capture.isInverted = true
        let store = WindowPreviewStore(screenRecordingAccess: { true }) { _ in
            capture.fulfill()
            return nil
        }
        let window = makeWindow(id: 1)

        store.update(windows: [window])
        store.registerVisible(window, size: CGSize(width: 640, height: 480), scale: 2)
        store.setPriorityWindow(window)
        store.request(window, refresh: true)
        store.refreshScreenRecordingAccess()

        await fulfillment(of: [capture], timeout: 0.1)
    }

    @MainActor
    func testDismissalDropsQueuedCapturesAndKeepsCompletedImage() async {
        let started = expectation(description: "Visible overview starts captures")
        started.expectedFulfillmentCount = 3
        let queued = expectation(description: "Queued captures stop on close")
        queued.isInverted = true
        let probe = CaptureProbe()
        let image = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let store = WindowPreviewStore(screenRecordingAccess: { true }) { id in
            let count = await probe.begin()
            if count <= 3 { started.fulfill() }
            else { queued.fulfill() }
            await probe.wait()
            return image
        }
        store.update(windows: (1...8).map { makeWindow(id: $0) })
        store.beginSession()
        await fulfillment(of: [started], timeout: 1)

        store.endSession()
        let cached = expectation(description: "Finished capture is cached")
        let observation = store.$images.sink { images in
            if images.count == 3 { cached.fulfill() }
        }
        await probe.release()
        await fulfillment(of: [cached], timeout: 1)
        await fulfillment(of: [queued], timeout: 0.1)
        XCTAssertEqual(store.images.count, 3)
        withExtendedLifetime(observation) {}
    }

    private func makeWindow(id: Int) -> Win {
        Win(id: id, title: "Window \(id)", appName: "Test", bundleID: "test.bundle",
            bundlePath: "/Applications/Test.app", workspace: "1", screenIndex: 1,
            parentLayout: "h_tiles", workspaceIsVisible: true)
    }
}

private actor CaptureProbe {
    private var count = 0
    private var released = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func begin() -> Int {
        count += 1
        return count
    }

    func wait() async {
        guard !released else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        released = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}
