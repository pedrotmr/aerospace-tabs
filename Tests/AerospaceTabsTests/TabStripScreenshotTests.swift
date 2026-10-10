import AppKit
import XCTest
@testable import AerospaceTabs
import SessionPolicy

final class TabStripScreenshotTests: XCTestCase {
    @MainActor
    func testRendersSyntheticStripExample() throws {
        let size = NSSize(width: 1_280, height: 80)
        let image = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        image.size = size

        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: image))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context

        let canvas = NSRect(origin: .zero, size: size)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.33, alpha: 1),
            NSColor(calibratedRed: 0.31, green: 0.28, blue: 0.34, alpha: 1),
        ])?.draw(in: canvas, angle: 0)

        let windows = [
            demoWindow(
                1,
                title: "Browser",
                app: "com.apple.Safari",
                path: "/Applications/Safari.app",
                workspace: "1",
                focused: true
            ),
            demoWindow(
                2,
                title: "Terminal",
                app: "com.apple.Terminal",
                path: "/System/Applications/Utilities/Terminal.app",
                workspace: "1"
            ),
            demoWindow(
                3,
                title: "Calendar",
                app: "com.apple.iCal",
                path: "/System/Applications/Calendar.app",
                workspace: "2"
            ),
            demoWindow(
                4,
                title: "Notes",
                app: "com.apple.Notes",
                path: "/System/Applications/Notes.app",
                workspace: "2"
            ),
        ]
        let frame = NSRect(x: 24, y: 22, width: size.width - 48, height: 34)
        let view = TabStripView(frame: frame)
        view.set(windows: windows, focused: 1)

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: frame.minX, yBy: frame.minY)
        transform.concat()
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()

        let png = try XCTUnwrap(image.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 1_000)

        guard let outputPath = ProcessInfo.processInfo.environment["AEROSPACE_TABS_SCREENSHOT_PATH"] else {
            return
        }
        let output = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try png.write(to: output)
    }

    private func demoWindow(
        _ id: Int,
        title: String,
        app: String,
        path: String,
        workspace: String,
        focused: Bool = false
    ) -> Win {
        Win(
            id: id,
            title: title,
            appName: title,
            bundleID: app,
            bundlePath: path,
            workspace: workspace,
            screenIndex: 1,
            parentLayout: "h_tiles",
            workspaceIsFocused: focused,
            workspaceIsVisible: focused
        )
    }
}
