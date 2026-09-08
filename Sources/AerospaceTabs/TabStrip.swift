import AppKit

struct TabStripLayout {
    let bounds: CGRect
    let count: Int
    let inset: CGFloat
    let gap: CGFloat
    let tabWidth: CGFloat
    let verticalPadding: CGFloat

    init(bounds: CGRect, count: Int) {
        self.bounds = bounds
        self.count = max(0, count)

        let slotCount = max(count, 1)
        let stripWidth = max(0, bounds.width)
        let stripHeight = max(0, bounds.height)
        inset = min(6, stripWidth * 0.05)

        let contentWidth = max(0, stripWidth - inset * 2)
        gap = slotCount > 1
            ? min(4, contentWidth / CGFloat(slotCount * 4))
            : 0
        let available = max(0, contentWidth - gap * CGFloat(slotCount - 1))
        tabWidth = min(260, available / CGFloat(slotCount))
        verticalPadding = min(4, stripHeight * 0.25)
    }

    var frames: [CGRect] {
        var x = bounds.minX + inset
        let rightEdge = bounds.maxX - inset
        let height = max(0, bounds.height - verticalPadding * 2)
        var result: [CGRect] = []
        result.reserveCapacity(count)

        for _ in 0..<count {
            let width = min(tabWidth, max(0, rightEdge - x))
            result.append(CGRect(
                x: x,
                y: bounds.minY + verticalPadding,
                width: width,
                height: height
            ))
            x += tabWidth + gap
        }
        return result
    }
}

final class TabStrip {
    private let panel: NSPanel
    private let glass: NSVisualEffectView
    private let view: TabStripView

    init(
        onPick: @escaping (Int) -> Void,
        onReorder: @escaping ([Int], String) -> Void,
        onQuit: @escaping () -> Void
    ) {
        view = TabStripView()
        view.onPick = onPick
        view.onReorder = onReorder
        view.onQuit = onQuit

        glass = NSVisualEffectView()
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = TabStripView.chromeRadius
        glass.layer?.masksToBounds = true
        glass.autoresizingMask = [.width, .height]

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: GapBoost.stripHeight))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        glass.frame = root.bounds
        view.frame = root.bounds
        view.autoresizingMask = [.width, .height]
        root.addSubview(glass)
        root.addSubview(view)

        panel = NSPanel(
            contentRect: root.bounds,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        // Above app windows, below macOS notification banners (statusBar covers them).
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenNone, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        panel.contentView = root
        panel.orderFrontRegardless()
    }

    func update(screen: NSScreen, windows: [Win], focused: Int?, hidden: Bool, gaps: OuterGaps) {
        let frame = Self.frame(on: screen, gaps: gaps)
        if panel.frame != frame {
            panel.setFrame(frame, display: false)
        }
        view.set(windows: windows, focused: focused)
        if hidden {
            setHidden(true)
            return
        }
        setHidden(false)
    }

    func setHidden(_ hidden: Bool) {
        if hidden {
            panel.alphaValue = 0
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
        } else {
            panel.ignoresMouseEvents = false
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
    }

    static let preferredBarHeight: CGFloat = GapBoost.stripHeight

    private static func frame(on screen: NSScreen, gaps: OuterGaps) -> NSRect {
        let full = screen.frame
        let visible = screen.visibleFrame
        let reserved = max(gaps.top, Self.preferredBarHeight)
        let height = min(Self.preferredBarHeight, reserved)
        let y = visible.maxY - reserved
        let width = max(120, full.width - gaps.left - gaps.right)
        return NSRect(
            x: full.minX + gaps.left,
            y: y,
            width: width,
            height: height
        )
    }
}

final class TabStripView: NSView {
    static let chromeRadius: CGFloat = 12
    private static let tabRadius: CGFloat = 9
    private static let dragThreshold: CGFloat = 4

    var onPick: ((Int) -> Void)?
    var onReorder: (([Int], String) -> Void)?
    var onQuit: (() -> Void)?

    private var windows: [Win] = []
    private var focused: Int?
    private var hover: Int?
    private var frames: [CGRect] = []

    private var pressIndex: Int?
    private var pressPoint: CGPoint = .zero
    private var dragging = false
    private var dragIndex: Int?
    private var draggedWindowID: Int?
    private var dragOffsetX: CGFloat = 0
    private var dragX: CGFloat = 0
    private var pendingModel: (windows: [Win], focused: Int?)?

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    func set(windows: [Win], focused: Int?) {
        if dragging {
            pendingModel = (windows, focused)
            return
        }
        apply(windows: windows, focused: focused)
    }

    private func apply(windows: [Win], focused: Int?) {
        if self.windows == windows && self.focused == focused { return }
        self.windows = windows
        self.focused = focused
        recomputeFrames()
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        guard !dragging else { return }
        hoverAt(event)
    }

    override func mouseExited(with event: NSEvent) {
        guard !dragging else { return }
        if hover != nil {
            hover = nil
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        beginPress(at: point)
    }

    func beginPress(at point: CGPoint) {
        guard let index = index(at: point) else {
            pressIndex = nil
            return
        }
        pressIndex = index
        pressPoint = point
        dragging = false
        dragIndex = nil
        draggedWindowID = windows[index].id
        dragOffsetX = point.x - frames[index].minX
        dragX = frames[index].minX
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        continuePress(to: point)
    }

    func continuePress(to point: CGPoint) {
        guard let from = pressIndex else { return }

        if !dragging {
            let dx = abs(point.x - pressPoint.x)
            let dy = abs(point.y - pressPoint.y)
            guard dx > Self.dragThreshold || dy > Self.dragThreshold else { return }
            dragging = true
            dragIndex = from
            hover = nil
        }

        guard let dragIndex else { return }
        let layout = tabLayout()
        let m = (inset: layout.inset, gap: layout.gap, width: layout.tabWidth)
        let minX = bounds.minX + m.inset
        let maxX = max(minX, bounds.maxX - m.inset - m.width)
        dragX = min(max(point.x - dragOffsetX, minX), maxX)

        let centerX = dragX + m.width / 2
        let slotWidth = m.width + m.gap
        let slot = slotWidth > 0
            ? Int(((centerX - minX) / slotWidth).rounded(.down))
            : dragIndex
        let target = min(max(slot, 0), windows.count - 1)
        if target != dragIndex {
            var next = windows
            let item = next.remove(at: dragIndex)
            next.insert(item, at: target)
            windows = next
            self.dragIndex = target
            recomputeFrames()
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        endPress(at: point)
    }

    func endPress(at point: CGPoint) {
        defer {
            pressIndex = nil
            dragging = false
            dragIndex = nil
            draggedWindowID = nil
            if let pendingModel {
                self.pendingModel = nil
                apply(windows: pendingModel.windows, focused: pendingModel.focused)
            }
            needsDisplay = true
        }

        if dragging {
            commitReorder()
            return
        }

        if let index = index(at: point) ?? pressIndex, windows.indices.contains(index) {
            onPick?(windows[index].id)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let restore = menu.addItem(
            withTitle: "Restore AeroSpace gaps",
            action: #selector(restoreGaps),
            keyEquivalent: ""
        )
        restore.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Aerospace Tabs", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func restoreGaps() {
        GapBoost.shared.restoreIfNeeded()
    }

    @objc private func quit() {
        GapBoost.shared.deactivate()
        onQuit?()
    }

    private func commitReorder() {
        var ordered = windows
        if let pendingModel {
            if let draggedWindowID,
                !pendingModel.windows.contains(where: { $0.id == draggedWindowID })
            {
                return
            }

            let latestByID = Dictionary(
                uniqueKeysWithValues: pendingModel.windows.map { ($0.id, $0) }
            )
            var included = Set<Int>()
            ordered = windows.compactMap { window in
                guard let latest = latestByID[window.id] else { return nil }
                included.insert(window.id)
                return latest
            }
            ordered.append(contentsOf: pendingModel.windows.filter { !included.contains($0.id) })
        }

        guard let first = ordered.first else { return }
        let workspace = first.workspace
        let byWS = Dictionary(grouping: ordered, by: \.workspace)
        for (ws, members) in byWS {
            onReorder?(members.map(\.id), ws.isEmpty ? workspace : ws)
        }
    }

    private func hoverAt(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let next = index(at: point)
        if next != hover {
            hover = next
            needsDisplay = true
        }
    }

    private func index(at point: CGPoint) -> Int? {
        frames.firstIndex(where: { $0.contains(point) })
    }

    private func tabLayout() -> TabStripLayout {
        TabStripLayout(bounds: bounds, count: windows.count)
    }

    private func recomputeFrames() {
        frames = tabLayout().frames
    }

    override func draw(_ dirtyRect: NSRect) {
        // Glass comes from the NSVisualEffectView underneath.
        // Soft outer rim so the chrome reads against wallpaper.
        let rim = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: Self.chromeRadius, yRadius: Self.chromeRadius)
        NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
        rim.lineWidth = 1
        rim.stroke()

        let count = windows.count
        guard count > 0 else {
            frames = []
            return
        }

        recomputeFrames()

        for (i, win) in windows.enumerated() {
            if dragging, i == dragIndex { continue }
            drawTab(win, in: frames[i], selected: win.id == focused, hovered: i == hover && !dragging)
        }

        if dragging, let dragIndex, windows.indices.contains(dragIndex) {
            let home = frames[dragIndex]
            let rect = NSRect(x: dragX, y: home.minY, width: home.width, height: home.height)
            drawTab(windows[dragIndex], in: rect, selected: true, hovered: false, elevating: true)
        }
    }

    private func drawTab(
        _ win: Win,
        in rect: NSRect,
        selected: Bool,
        hovered: Bool,
        elevating: Bool = false
    ) {
        let radius = min(Self.tabRadius, rect.height / 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        let fill: NSColor
        if elevating {
            fill = NSColor(calibratedWhite: 0.48, alpha: 0.58)
        } else if selected {
            fill = NSColor(calibratedWhite: 0.58, alpha: 0.42)
        } else if hovered {
            fill = NSColor(calibratedWhite: 0.38, alpha: 0.30)
        } else {
            // Every tab is a chip so inactive ones still separate visually.
            fill = NSColor(calibratedWhite: 0.28, alpha: 0.26)
        }
        fill.setFill()
        path.fill()

        // Hairline on all chips; stronger on the active one.
        let strokeAlpha: CGFloat = (selected || elevating) ? 0.22 : 0.10
        NSColor(calibratedWhite: 1, alpha: strokeAlpha).setStroke()
        let stroke = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
        stroke.lineWidth = 1
        stroke.stroke()

        let sidePad = min(10, max(0, rect.width * 0.15))
        let contentWidth = max(0, rect.width - sidePad * 2)
        let iconSize = min(14, contentWidth)
        let fontSize: CGFloat = 12
        let gap = min(6, max(0, contentWidth - iconSize))
        let font = NSFont.systemFont(ofSize: fontSize, weight: selected || elevating ? .medium : .regular)
        let color = selected || elevating
            ? NSColor.white
            : NSColor(calibratedWhite: 0.86, alpha: 1)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .left
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]

        let label = win.label as NSString
        let maxTextWidth = max(0, rect.width - sidePad * 2 - iconSize - gap)
        let textSize = label.boundingRect(
            with: NSSize(width: maxTextWidth, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        ).size

        let iconRect = NSRect(
            x: rect.minX + sidePad,
            y: rect.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        if iconSize >= 2 {
            Icons.shared.icon(for: win).draw(in: iconRect)
        }

        let textRect = NSRect(
            x: iconRect.maxX + gap,
            y: rect.midY - textSize.height / 2,
            width: maxTextWidth,
            height: textSize.height
        )
        if maxTextWidth >= 2 {
            label.draw(in: textRect, withAttributes: attrs)
        }
    }
}
