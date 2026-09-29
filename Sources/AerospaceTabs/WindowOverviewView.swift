import AppKit
import CoreGraphics
import SwiftUI

struct OverviewDisplayDescriptor: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let screenIndex: Int
    let frame: CGRect
    let backingScale: CGFloat
    let topInset: CGFloat

    init(screen: NSScreen) {
        id = screen.displayID
        screenIndex = screen.aerospaceScreenIndex
        frame = screen.frame
        backingScale = screen.backingScaleFactor
        topInset = screen.safeAreaInsets.top
    }
}

struct OverviewWorkspaceGroup: Identifiable {
    let workspace: String
    let windows: [Win]

    var id: String { workspace }
}

/// Choose the row count that gives real window images the most screen area.
struct WindowOverviewGridPlan {
    struct Row: Identifiable {
        struct ID: Hashable {
            let workspace: String
            let index: Int
        }

        let workspace: String
        let index: Int
        let windows: [Win]
        let startsWorkspace: Bool
        var id: ID { ID(workspace: workspace, index: index) }
    }

    let rows: [Row]
    let imageHeight: CGFloat
    let aspects: [Int: CGFloat]
    static let itemSpacing: CGFloat = 20
    static let rowSpacing: CGFloat = 20
    static let workspaceSpacing: CGFloat = 36

    static func make(
        groups: [OverviewWorkspaceGroup],
        availableSize: CGSize,
        aspectRatioForWindow: (Int) -> CGFloat
    ) -> Self {
        let width = max(1, availableSize.width)
        let height = max(1, availableSize.height)
        let windows = groups.flatMap(\.windows)
        let aspects = Dictionary(uniqueKeysWithValues: windows.map {
            ($0.id, max(0.25, min(4, aspectRatioForWindow($0.id))))
        })
        let maxColumns = max(1, groups.map(\.windows.count).max() ?? 1)
        var best: Self?
        var bestArea: CGFloat = -1

        for columns in 1...maxColumns {
            let rows = groups.flatMap { group in
                stride(from: 0, to: group.windows.count, by: columns).enumerated().map { row, start in
                    Row(workspace: group.workspace,
                        index: row,
                        windows: Array(group.windows[start..<min(start + columns, group.windows.count)]),
                        startsWorkspace: start == 0)
                }
            }
            let gaps = rows.dropFirst().reduce(CGFloat.zero) {
                $0 + ($1.startsWorkspace ? workspaceSpacing : rowSpacing)
            }
            let widthLimitedHeight = rows.map { row in
                let totalAspect = row.windows.reduce(CGFloat.zero) { $0 + (aspects[$1.id] ?? 1.66) }
                return max(1, width - CGFloat(row.windows.count - 1) * itemSpacing) / totalAspect
            }.min() ?? height
            let fittingHeight = max(1, (height - gaps) / CGFloat(max(1, rows.count)))
            // Dense overviews scroll before previews become too small to recognize.
            let imageHeight = min(widthLimitedHeight, max(140, fittingHeight))
            let contentHeight = CGFloat(rows.count) * imageHeight + gaps
            let area = imageHeight * imageHeight * aspects.values.reduce(0, +)
                * min(1, height / max(1, contentHeight))
            if area > bestArea {
                bestArea = area
                best = Self(rows: rows, imageHeight: imageHeight, aspects: aspects)
            }
        }
        return best!
    }

    func size(for window: Win) -> CGSize {
        CGSize(width: imageHeight * (aspects[window.id] ?? 1.66), height: imageHeight)
    }

    func frames() -> [Int: CGRect] {
        let widest = rows.map { row in
            row.windows.reduce(CGFloat.zero) { $0 + size(for: $1).width }
                + CGFloat(max(0, row.windows.count - 1)) * Self.itemSpacing
        }.max() ?? 0
        var result: [Int: CGRect] = [:]
        var y: CGFloat = 0
        for (index, row) in rows.enumerated() {
            if index > 0 { y += row.startsWorkspace ? Self.workspaceSpacing : Self.rowSpacing }
            let width = row.windows.reduce(CGFloat.zero) { $0 + size(for: $1).width }
                + CGFloat(max(0, row.windows.count - 1)) * Self.itemSpacing
            var x = (widest - width) / 2
            for window in row.windows {
                let size = size(for: window)
                result[window.id] = CGRect(origin: CGPoint(x: x, y: y), size: size)
                x += size.width + Self.itemSpacing
            }
            y += imageHeight
        }
        return result
    }
}

final class WindowOverviewModel: ObservableObject {
    @Published private(set) var windows: [Win] = []
    @Published private(set) var focusedID: Int?
    @Published private(set) var selectedID: Int?
    @Published private(set) var theme: StripTheme

    init() {
        theme = AppearanceSettings.shared.theme
    }

    var focusedScreenIndex: Int? {
        windows.first(where: { $0.id == focusedID })?.screenIndex
            ?? windows.first(where: \.workspaceIsFocused)?.screenIndex
            ?? NSScreen.main?.aerospaceScreenIndex
    }

    func update(windows: [Win], focusedID: Int?) {
        let focusChanged = self.focusedID != focusedID
        if self.windows != windows {
            let windowIDs = Set(windows.map(\.id))
            windowFrames = windowFrames.filter { windowIDs.contains($0.key) }
            self.windows = windows
        }
        if focusChanged { self.focusedID = focusedID }
        if let selectedID, !windows.contains(where: { $0.id == selectedID }) {
            self.selectedID = nil
        }
        if selectedID == nil || focusChanged && !navigationWindows.contains(where: { $0.id == selectedID }) {
            self.selectedID = focusedID ?? windows.first?.id
        }
    }

    func beginPresentation() {
        selectedID = focusedID ?? windows.first?.id
    }

    func updateSettings() {
        theme = AppearanceSettings.shared.theme
        if let selectedID, !navigationWindows.contains(where: { $0.id == selectedID }) {
            self.selectedID = navigationWindows.first?.id
        }
    }

    func groups(on screenIndex: Int) -> [OverviewWorkspaceGroup] {
        let filtered = displayWindows(on: screenIndex)
        let byWorkspace = Dictionary(grouping: filtered, by: \.workspace)
        let workspaceNames = byWorkspace.keys.sorted { lhs, rhs in
            if let leftNumber = Int(lhs), let rightNumber = Int(rhs), leftNumber != rightNumber {
                return leftNumber < rightNumber
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        return workspaceNames.map { name in
            let members = byWorkspace[name] ?? []
            return OverviewWorkspaceGroup(
                workspace: name,
                windows: members
            )
        }
    }

    func displayWindows(on screenIndex: Int) -> [Win] {
        windows.filter { $0.screenIndex == screenIndex }
    }

    var navigationWindows: [Win] {
        Set(windows.map(\.screenIndex)).sorted().flatMap { screen in
            groups(on: screen).flatMap(\.windows)
        }
    }

    private var windowFrames: [Int: CGRect] = [:]

    func setFrames(_ frames: [Int: CGRect], screenIndex: Int) {
        let displayIDs = Set(displayWindows(on: screenIndex).map(\.id))
        windowFrames = windowFrames.filter { !displayIDs.contains($0.key) }
        windowFrames.merge(frames) { _, new in new }
    }

    func select(_ id: Int) {
        guard navigationWindows.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    func moveSelection(_ direction: OverviewNavigationDirection) {
        guard let current = windows.first(where: { $0.id == selectedID }),
              let origin = windowFrames[current.id] else { return }
        let horizontal = direction == .left || direction == .right
        let sign: CGFloat = direction == .left || direction == .up ? -1 : 1
        let candidates = displayWindows(on: current.screenIndex).compactMap { window -> (Int, CGFloat)? in
            guard window.id != current.id, let frame = windowFrames[window.id] else { return nil }
            let dx = frame.midX - origin.midX
            let dy = frame.midY - origin.midY
            let forward = (horizontal ? dx : dy) * sign
            guard forward > 1 else { return nil }
            let cross = abs(horizontal ? dy : dx)
            return (window.id, forward + cross * 3)
        }
        if let next = candidates.min(by: { $0.1 < $1.1 }) { selectedID = next.0 }
    }

}

enum OverviewNavigationDirection {
    case left
    case right
    case up
    case down
}

private enum OverviewIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for path: String) -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

struct WindowOverviewScreen: View {
    @ObservedObject var model: WindowOverviewModel
    @ObservedObject var previews: WindowPreviewStore

    let display: OverviewDisplayDescriptor
    let onDismiss: () -> Void
    let onFocus: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var groups: [OverviewWorkspaceGroup] {
        model.groups(on: display.screenIndex)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(model.theme == .solid ? 0.42 : 0.16))
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    let horizontalInset: CGFloat = 32
                    let availableSize = CGSize(
                        width: geometry.size.width - horizontalInset * 2,
                        height: geometry.size.height - verticalInset * 2
                    )
                    let plan = WindowOverviewGridPlan.make(
                        groups: groups,
                        availableSize: availableSize,
                        aspectRatioForWindow: previews.aspectRatio(for:)
                    )
                    let frames = plan.frames()

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(plan.rows.enumerated()), id: \.element.id) { index, row in
                                HStack(spacing: WindowOverviewGridPlan.itemSpacing) {
                                    ForEach(row.windows, id: \.id) { window in
                                        WindowOverviewCard(
                                            window: window, model: model, previews: previews,
                                            viewportSize: geometry.size,
                                            onFocus: { onFocus(window.id) }
                                        )
                                        .frame(width: plan.size(for: window).width, height: plan.imageHeight)
                                        .id(window.id)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, index == 0 ? 0 : (row.startsWorkspace
                                    ? WindowOverviewGridPlan.workspaceSpacing : WindowOverviewGridPlan.rowSpacing))
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: max(0, availableSize.height),
                            alignment: .center
                        )
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, verticalInset)
                        .padding(.bottom, verticalInset)
                        .background {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture(perform: onDismiss)
                        }
                    }
                    .coordinateSpace(name: "overviewViewport")
                    .scrollIndicators(.hidden)
                    .onAppear {
                        model.select(model.selectedID ?? model.focusedID ?? model.navigationWindows.first?.id ?? -1)
                        model.setFrames(frames, screenIndex: display.screenIndex)
                        updatePriorityPreview()
                    }
                    .onChange(of: frames) { _, frames in
                        model.setFrames(frames, screenIndex: display.screenIndex)
                    }
                    .onChange(of: model.selectedID) { _, selectedID in
                        updatePriorityPreview()
                        guard selectedID != nil else { return }
                        scrollToSelection(using: proxy, animated: true)
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if previews.needsScreenRecording {
                Button {
                    previews.requestScreenRecordingAccess()
                } label: {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Allow Screen Recording to show window previews")
                .padding(.top, max(12, display.topInset + 6))
                .padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.displayScale, display.backingScale)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            previews.refreshScreenRecordingAccess()
        }
        .onExitCommand(perform: onDismiss)
        .focusable()
    }

    private var verticalInset: CGFloat {
        max(26, display.topInset + 18)
    }

    private func scrollToSelection(using proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedID = model.selectedID else { return }
        let scroll = { proxy.scrollTo(selectedID, anchor: .center) }
        if animated && !reduceMotion {
            withAnimation(.easeOut(duration: 0.18), scroll)
        } else {
            scroll()
        }
    }

    private func updatePriorityPreview() {
        let selected = model.navigationWindows.first(where: { $0.id == model.selectedID })
        previews.setPriorityWindow(selected)
    }

}

private struct WindowOverviewCard: View {
    let window: Win
    @ObservedObject var model: WindowOverviewModel
    @ObservedObject var previews: WindowPreviewStore
    let viewportSize: CGSize
    let onFocus: () -> Void

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button {
            onFocus()
        } label: {
            preview
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            isHovered ? Color.accentColor.opacity(0.96) : .clear,
                            lineWidth: 3
                        )
                )
                .shadow(color: .black.opacity(0.28), radius: 7, y: 3)
                .overlay {
                    if isHovered {
                        Text(window.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color(white: 0.78).opacity(0.94), in: Capsule())
                            .padding(.horizontal, 24)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(window.label), \(window.appName), space \(window.workspace)")
        .accessibilityHint("Opens this window")
        .onHover { isHovered = $0 }
        .onDisappear { previews.unregisterVisible(window) }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.07), value: isHovered)
    }

    private var preview: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(model.theme == .solid ? 0.32 : 0.18)
                if let image = previews.images[window.id] {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    placeholder
                }
                if let live = previews.livePreviews[window.id] {
                    OverviewLivePreviewView(preview: live)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .onAppear { updateVisibility(geometry) }
            .onChange(of: geometry.frame(in: .named("overviewViewport"))) { _, _ in
                updateVisibility(geometry)
            }
        }
    }

    private func updateVisibility(_ geometry: GeometryProxy) {
        if geometry.frame(in: .named("overviewViewport")).intersects(CGRect(origin: .zero, size: viewportSize)) {
            previews.registerVisible(window, size: geometry.size, scale: displayScale)
        } else {
            previews.unregisterVisible(window)
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.8)
            appIcon(size: 42).opacity(0.65)
        }
    }

    private func appIcon(size: CGFloat) -> some View {
        let icon = OverviewIconCache.icon(for: window.bundlePath)
        return Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size > 30 ? 13 : 5, style: .continuous))
            .accessibilityHidden(true)
    }

}
