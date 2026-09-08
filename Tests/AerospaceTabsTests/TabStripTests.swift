import AppKit
import XCTest
@testable import AerospaceTabs

final class TabStripTests: XCTestCase {
    func testLargeTabCountStaysInsideStripBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 120, height: 34)
        let frames = TabStripLayout(bounds: bounds, count: 1_000).frames

        XCTAssertEqual(frames.count, 1_000)
        XCTAssertTrue(frames.allSatisfy { frame in
            frame.width > 0
                && frame.height > 0
                && frame.minX >= bounds.minX
                && frame.maxX <= bounds.maxX
                && frame.minY >= bounds.minY
                && frame.maxY <= bounds.maxY
        })
    }

    func testVeryNarrowStripStillProducesReachableFrames() {
        let bounds = CGRect(x: 20, y: 10, width: 0.5, height: 1)
        let frames = TabStripLayout(bounds: bounds, count: 100).frames

        XCTAssertTrue(frames.allSatisfy { frame in
            frame.width > 0
                && frame.height > 0
                && frame.minX >= bounds.minX
                && frame.maxX <= bounds.maxX
                && frame.minY >= bounds.minY
                && frame.maxY <= bounds.maxY
        })
    }

    func testLastCompactTabCanBePickedAndReachedByDragging() {
        let view = TabStripView(frame: CGRect(x: 0, y: 0, width: 120, height: 34))
        let windows = (1...100).map(makeWindow)
        let frames = TabStripLayout(bounds: view.bounds, count: windows.count).frames
        let firstPoint = CGPoint(x: frames[0].midX, y: frames[0].midY)
        let lastPoint = CGPoint(x: frames[99].midX, y: frames[99].midY)
        view.set(windows: windows, focused: 1)

        var picked: Int?
        view.onPick = { picked = $0 }
        view.beginPress(at: lastPoint)
        view.endPress(at: lastPoint)
        XCTAssertEqual(picked, 100)

        var reorderedIDs: [Int] = []
        view.onReorder = { ids, _ in reorderedIDs = ids }
        view.beginPress(at: firstPoint)
        view.continuePress(to: lastPoint)
        view.endPress(at: lastPoint)
        XCTAssertEqual(reorderedIDs.last, 1)
        XCTAssertEqual(Set(reorderedIDs), Set(1...100))
    }

    func testModelUpdateFromReorderCallbackIsAppliedAfterDrag() {
        let view = makeView()
        view.set(windows: [makeWindow(id: 1), makeWindow(id: 2)], focused: 1)
        view.beginPress(at: CGPoint(x: 50, y: 17))
        view.continuePress(to: CGPoint(x: 170, y: 17))
        view.onReorder = { _, _ in
            view.set(windows: [self.makeWindow(id: 3)], focused: 3)
        }

        view.endPress(at: CGPoint(x: 170, y: 17))

        var picked: Int?
        view.onPick = { picked = $0 }
        view.beginPress(at: CGPoint(x: 50, y: 17))
        view.endPress(at: CGPoint(x: 50, y: 17))
        XCTAssertEqual(picked, 3)
    }

    func testVanishedDraggedWindowIsNotSentToReorderCallback() {
        let view = makeView()
        view.set(windows: [makeWindow(id: 1), makeWindow(id: 2)], focused: 1)
        view.beginPress(at: CGPoint(x: 50, y: 17))
        view.continuePress(to: CGPoint(x: 170, y: 17))
        view.set(windows: [makeWindow(id: 2)], focused: 2)

        var reorderedIDs: [[Int]] = []
        view.onReorder = { ids, _ in reorderedIDs.append(ids) }
        view.endPress(at: CGPoint(x: 170, y: 17))

        XCTAssertTrue(reorderedIDs.isEmpty)
        var picked: Int?
        view.onPick = { picked = $0 }
        view.beginPress(at: CGPoint(x: 50, y: 17))
        view.endPress(at: CGPoint(x: 50, y: 17))
        XCTAssertEqual(picked, 2)
    }

    private func makeView() -> TabStripView {
        TabStripView(frame: CGRect(x: 0, y: 0, width: 200, height: 34))
    }

    private func makeWindow(id: Int) -> Win {
        Win(
            id: id,
            title: "Window \(id)",
            appName: "Test",
            bundleID: "test.bundle",
            bundlePath: "/Applications/Test.app",
            workspace: "main",
            screenIndex: 1,
            parentLayout: "h_tiles"
        )
    }
}
