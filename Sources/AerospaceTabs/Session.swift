import Foundation
import os
import SessionPolicy

final class Session {
    typealias SnapshotCompletion = (Result<Snapshot, Error>) -> Void
    typealias CommandCompletion = (Result<Void, Error>) -> Void

    private let listWindows: (@escaping SnapshotCompletion) -> Void
    private let focusWindowCommand: (Int, @escaping CommandCompletion) -> Void
    private let focusWorkspaceCommand: (String, @escaping CommandCompletion) -> Void
    private let logger = Logger(subsystem: "com.pedrotmr.AerospaceTabs", category: "Session")
    private var lastRefreshError: String?
    var isAerospaceUnavailable: Bool { lastRefreshError != nil }
    private let subscribe = SubscribePump()
    private let order = TabOrder()
    private var refreshQueued = false
    private var refreshGeneration = 0
    private var focusGeneration = 0
    private var focusing = false
    private var cycleWorkspace: String?
    private var focusedWorkspace: String?
    private var focusedScreenIndex: Int?
    var windows: [Win] = []
    var focusedID: Int?
    var onChange: (() -> Void)?

    var displayFocusedID: Int? { focusedID }

    init(
        listWindows: ((@escaping SnapshotCompletion) -> Void)? = nil,
        focusWindow: ((Int, @escaping CommandCompletion) -> Void)? = nil,
        focusWorkspace: ((String, @escaping CommandCompletion) -> Void)? = nil
    ) {
        let client = AerospaceClient()
        self.listWindows = listWindows ?? { completion in
            client.listAllWindows(completion: completion)
        }
        self.focusWindowCommand = focusWindow ?? { id, completion in
            client.focus(windowID: id, completion: completion)
        }
        self.focusWorkspaceCommand = focusWorkspace ?? { workspace, completion in
            client.focus(workspace: workspace, completion: completion)
        }
    }

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
    func stepCycle(_ cycle: HotkeyCycle, reverse: Bool = false) {
        switch cycle {
        case .spaces:
            stepSpaceCycle(reverse: reverse)
        case .windows:
            stepWindowCycle(reverse: reverse)
        }
    }

    func commitCycle(_ cycle: HotkeyCycle) {
        if cycle == .spaces { cycleWorkspace = nil }
    }

    private func stepWindowCycle(reverse: Bool) {
        let pool = cyclePool()
        guard !pool.isEmpty else { return }
        let current = pool.firstIndex(where: { $0.id == focusedID }) ?? (reverse ? 0 : -1)
        let next = (current + (reverse ? -1 : 1) + pool.count) % pool.count
        focus(pool[next].id)
    }

    private func stepSpaceCycle(reverse: Bool) {
        let pool = spaceCyclePool()
        guard !pool.isEmpty else { return }
        let currentName = cycleWorkspace ?? focusedWorkspaceName
        let current = pool.firstIndex(of: currentName ?? "") ?? (reverse ? 0 : -1)
        let next = (current + (reverse ? -1 : 1) + pool.count) % pool.count
        cycleWorkspace = pool[next]
        focus(workspace: pool[next])
    }

    func focus(_ id: Int) {
        focusGeneration += 1
        let requestGeneration = focusGeneration
        if let window = windows.first(where: { $0.id == id }) {
            focusedWorkspace = window.workspace
            focusedScreenIndex = window.screenIndex
        }
        if focusedID != id {
            focusedID = id
            onChange?()
        }
        focusing = true
        focusWindowCommand(id) { [weak self] result in
            guard let self, requestGeneration == self.focusGeneration else { return }
            switch result {
            case .success:
                self.refreshNow(forFocusGeneration: requestGeneration)
            case .failure(let error):
                self.focusFailed(error, requestGeneration: requestGeneration)
            }
        }
    }

    private func focus(workspace: String) {
        focusGeneration += 1
        let requestGeneration = focusGeneration
        focusedWorkspace = workspace
        focusing = true
        focusWorkspaceCommand(workspace) { [weak self] result in
            guard let self, requestGeneration == self.focusGeneration else { return }
            switch result {
            case .success:
                self.refreshNow(forFocusGeneration: requestGeneration)
            case .failure(let error):
                self.focusFailed(error, requestGeneration: requestGeneration)
            }
        }
    }

    private func focusFailed(_ error: Error, requestGeneration: Int) {
        guard requestGeneration == focusGeneration else { return }
        focusing = false
        logger.error("AeroSpace focus command failed: \(String(describing: error), privacy: .public)")
        scheduleRefresh()
    }

    func reorder(ids: [Int], workspace: String) {
        order.setOrder(ids: ids, workspace: workspace)
        let sorted = order.apply(windows)
        if sorted != windows {
            windows = sorted
            onChange?()
        }
    }

    func cyclePool() -> [Win] {
        SessionPolicy.cyclePool(windows: windows, focusedID: focusedID)
    }

    private var focusedWorkspaceName: String? {
        SessionPolicy.focusedWorkspaceName(
            windows: windows,
            focusedID: focusedID,
            fallbackWorkspace: focusedWorkspace
        )
    }

    func spaceCyclePool() -> [String] {
        SessionPolicy.spaceCyclePool(
            windows: windows,
            focusedID: focusedID,
            focusedScreenIndex: focusedScreenIndex
        )
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
        guard !focusing else { return }
        if refreshQueued { return }
        refreshQueued = true
        DispatchQueue.main.async { [weak self] in
            self?.refreshQueued = false
            self?.refreshNow()
        }
    }

    func refreshNow(forFocusGeneration requestFocusGeneration: Int? = nil) {
        guard !focusing || requestFocusGeneration != nil else { return }
        refreshGeneration += 1
        let requestGeneration = refreshGeneration
        let focusRequestGeneration = requestFocusGeneration ?? focusGeneration
        listWindows { [weak self] result in
            guard let self,
                  requestGeneration == self.refreshGeneration,
                  focusRequestGeneration == self.focusGeneration
            else { return }
            switch result {
            case .failure(let error):
                self.markUnavailable(error)
            case .success(let snapshot):
                self.apply(snapshot)
            }
        }
    }

    func markUnavailable(_ error: Error) {
        focusing = false
        let description = String(describing: error)
        guard description != lastRefreshError else { return }
        logger.error("Window refresh failed: \(description, privacy: .public)")
        let wasUnavailable = isAerospaceUnavailable
        lastRefreshError = description
        if !wasUnavailable {
            onChange?()
        }
    }

    func apply(_ snapshot: Snapshot) {
        focusing = false
        let recovered = isAerospaceUnavailable
        lastRefreshError = nil
        let sorted = order.apply(snapshot.windows)
        let changed = sorted != windows
            || snapshot.focused != focusedID
            || snapshot.focusedWorkspace != focusedWorkspace
            || snapshot.focusedScreenIndex != focusedScreenIndex
        windows = sorted
        focusedID = snapshot.focused
        focusedWorkspace = snapshot.focusedWorkspace
        focusedScreenIndex = snapshot.focusedScreenIndex
        if changed || recovered {
            onChange?()
        }
    }
}

struct Snapshot {
    var windows: [Win]
    var focused: Int?
    var focusedWorkspace: String? = nil
    var focusedScreenIndex: Int? = nil
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
