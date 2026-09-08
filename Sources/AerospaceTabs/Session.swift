import Foundation

struct Win: Equatable {
    let id: Int
    let title: String
    let appName: String
    let bundleID: String
    let bundlePath: String
    let workspace: String
    let screenIndex: Int
    /// AeroSpace parent layout: h_tiles, v_tiles, h_accordion, v_accordion, floating.
    let parentLayout: String

    var label: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appName : trimmed
    }

    var isAccordion: Bool {
        parentLayout.contains("accordion")
    }

    var isTiles: Bool {
        parentLayout.contains("tiles")
    }
}

struct WindowRow: Decodable {
    let windowId: Int
    let windowTitle: String?
    let appName: String?
    let appBundleId: String?
    let appBundlePath: String?
    let workspace: String?
    let monitorAppkitNsscreenScreensId: Int?
    let windowParentContainerLayout: String?

    enum CodingKeys: String, CodingKey {
        case windowId = "window-id"
        case windowTitle = "window-title"
        case appName = "app-name"
        case appBundleId = "app-bundle-id"
        case appBundlePath = "app-bundle-path"
        case workspace
        case monitorAppkitNsscreenScreensId = "monitor-appkit-nsscreen-screens-id"
        case windowParentContainerLayout = "window-parent-container-layout"
    }

    var asWin: Win? {
        guard windowId != 0 else { return nil }
        return Win(
            id: windowId,
            title: windowTitle ?? "",
            appName: appName ?? "",
            bundleID: appBundleId ?? "",
            bundlePath: appBundlePath ?? "",
            workspace: workspace ?? "",
            screenIndex: monitorAppkitNsscreenScreensId ?? 1,
            parentLayout: windowParentContainerLayout ?? ""
        )
    }
}

final class Session {
    private let client = AerospaceClient()
    private let subscribe = SubscribePump()
    private let order = TabOrder()
    private var refreshQueued = false
    private var focusing = false
    var windows: [Win] = []
    var focusedID: Int?
    var onChange: (() -> Void)?

    var displayFocusedID: Int? { focusedID }

    func start() {
        subscribe.onEvent = { [weak self] event in
            self?.handle(event)
        }
        subscribe.start()
        scheduleRefresh()
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self, !self.focusing else { return }
            self.scheduleRefresh()
        }
    }

    /// Advance and focus immediately so the window is visible while cycling.
    func stepCycle(reverse: Bool = false) {
        let pool = cyclePool()
        guard !pool.isEmpty else { return }
        let current = pool.firstIndex(where: { $0.id == focusedID }) ?? (reverse ? 0 : -1)
        let next = (current + (reverse ? -1 : 1) + pool.count) % pool.count
        focus(pool[next].id)
    }

    func commitCycle() {
        // Focus already applied on each step; nothing to do on release.
    }

    func focus(_ id: Int) {
        if focusedID != id {
            focusedID = id
            onChange?()
        }
        focusing = true
        client.focus(windowID: id) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self?.focusing = false
            }
        }
    }

    func reorder(ids: [Int], workspace: String) {
        order.setOrder(ids: ids, workspace: workspace)
        let sorted = order.apply(windows)
        if sorted != windows {
            windows = sorted
            onChange?()
        }
    }

    private func cyclePool() -> [Win] {
        let screen = windows.first(where: { $0.id == focusedID })?.screenIndex
        return screen.map { index in windows.filter { $0.screenIndex == index } } ?? windows
    }

    private func handle(_ event: AeroEvent) {
        switch event.kind {
        case "focus-changed":
            if let id = event.windowId {
                if windows.contains(where: { $0.id == id }) {
                    if focusedID != id {
                        focusedID = id
                        onChange?()
                    }
                    return
                }
            }
            scheduleRefresh()
        case "focused-workspace-changed", "focused-monitor-changed", "window-detected":
            scheduleRefresh()
        default:
            break
        }
    }

    private func scheduleRefresh() {
        if refreshQueued { return }
        refreshQueued = true
        DispatchQueue.main.async { [weak self] in
            self?.refreshQueued = false
            self?.refreshNow()
        }
    }

    private func refreshNow() {
        client.listVisibleWindows { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                // Keep the last good snapshot so a socket blip does not blank the strip.
                return
            case .success(let snapshot):
                self.apply(snapshot)
            }
        }
    }

    func apply(_ snapshot: Snapshot) {
        let sorted = order.apply(snapshot.windows)
        if sorted != windows || snapshot.focused != focusedID {
            windows = sorted
            focusedID = snapshot.focused
            onChange?()
        }
    }
}

struct Snapshot {
    var windows: [Win]
    var focused: Int?
}

struct AeroEvent {
    var kind: String
    var windowId: Int?
}

final class SubscribePump {
    private var process: Process?
    private var buffer = Data()
    var onEvent: ((AeroEvent) -> Void)?

    func start() {
        connect()
    }

    private func connect() {
        if let existing = process {
            if let pipe = existing.standardOutput as? Pipe {
                pipe.fileHandleForReading.readabilityHandler = nil
            }
            existing.terminationHandler = nil
            existing.terminate()
            process = nil
        }

        let process = Process()
        process.executableURL = AerospaceClient.binaryURL
        process.arguments = [
            "subscribe",
            "focus-changed",
            "focused-workspace-changed",
            "focused-monitor-changed",
            "window-detected",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            DispatchQueue.main.async {
                self?.consume(chunk)
            }
        }
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self?.connect()
            }
        }
        do {
            try process.run()
            self.process = process
        } catch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.connect()
            }
        }
    }

    private func consume(_ chunk: Data) {
        buffer.append(chunk)
        while let range = buffer.firstRange(of: Data([0x0A])) {
            let line = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            let kind = (object["_event"] as? String) ?? ""
            let windowId = object["windowId"] as? Int ?? (object["window-id"] as? Int)
            onEvent?(AeroEvent(kind: kind, windowId: windowId))
        }
    }
}
