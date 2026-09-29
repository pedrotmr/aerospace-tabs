import AppKit
import CoreGraphics
@preconcurrency import ScreenCaptureKit
import Darwin
import os

/// All observable state is confined to the main queue. Captures run off that queue.
@MainActor
final class WindowPreviewStore: ObservableObject {
    @Published private(set) var livePreviews: [Int: OverviewLivePreview] = [:]
    @Published private(set) var images: [Int: NSImage] = [:]
    @Published private(set) var needsScreenRecording = !CGPreflightScreenCaptureAccess()
    @Published private(set) var aspectRatios: [Int: CGFloat] = [:]

    private var windows: [Int: Win] = [:]
    private var pending: [Int] = []
    private var inFlight: Set<Int> = []
    private var captureDates: [Int: Date] = [:]
    private var attemptDates: [Int: Date] = [:]
    private var costs: [Int: Int] = [:]
    private var visibleIDs: Set<Int> = []
    private var priorityID: Int?
    private var targetSizes: [Int: CGSize] = [:]
    private var liveSizes: [Int: CGSize] = [:]
    private var liveRetryDates: [Int: Date] = [:]
    private var generation = 0
    private var isPresented = false
    private var liveEnabled = false
    private var timer: Timer?
    private let discovery = OverviewWindowDiscovery()
    private let memoryLimit = 96 * 1024 * 1024
    private let logger = Logger(subsystem: "com.pedrotmr.AerospaceTabs", category: "OverviewPreviews")

    deinit { timer?.invalidate() }

    func aspectRatio(for id: Int) -> CGFloat { aspectRatios[id] ?? 1.66 }

    func update(windows: [Win]) {
        let latest = Dictionary(windows.map { ($0.id, $0) }) { first, _ in first }
        let membershipChanged = Set(latest.keys) != Set(self.windows.keys)
        for (id, previous) in self.windows where latest[id]?.bundleID != previous.bundleID {
            livePreviews.removeValue(forKey: id)?.stop(keepSnapshot: false)
            targetSizes.removeValue(forKey: id)
            liveSizes.removeValue(forKey: id)
            liveRetryDates.removeValue(forKey: id)
            images.removeValue(forKey: id)
            costs.removeValue(forKey: id)
            captureDates.removeValue(forKey: id)
            attemptDates.removeValue(forKey: id)
        }
        self.windows = latest
        pending.removeAll { latest[$0] == nil }
        visibleIDs.formIntersection(latest.keys)
        if membershipChanged { updateAspectRatios() }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refreshDuePreviews()
                }
            }
            updateAspectRatios()
        }
        refreshDuePreviews()
    }

    func beginSession() {
        generation += 1
        isPresented = true
        liveEnabled = false
        liveRetryDates.removeAll()
        refreshScreenRecordingAccess()
        updateAspectRatios()
        logger.debug("Overview opening: \(self.images.count) cached previews for \(self.windows.count) windows")
        // Hosting views survive orderOut; their onAppear is not a presentation callback.
        reconcileLivePreviews()
        for window in windows.values { request(window) }
    }

    func startLivePreviews() {
        guard isPresented else { return }
        liveEnabled = true
        reconcileLivePreviews()
    }

    func endSession() {
        isPresented = false
        liveEnabled = false
        priorityID = nil
        pending.removeAll()
        stopLivePreviews()
        // Keep the last valid images in RAM for the next presentation.
    }

    func registerVisible(_ window: Win, size: CGSize, scale: CGFloat) {
        visibleIDs.insert(window.id)
        let desired = CGSize(width: size.width * scale, height: size.height * scale)
        targetSizes[window.id] = desired
        reconcileLivePreviews()
        request(window)
    }

    func unregisterVisible(_ window: Win) {
        visibleIDs.remove(window.id)
        livePreviews.removeValue(forKey: window.id)?.stop()
        liveSizes.removeValue(forKey: window.id)
    }

    func setPriorityWindow(_ window: Win?) {
        priorityID = window?.id
        if let window { request(window) }
    }

    func requestScreenRecordingAccess() {
        guard !CGPreflightScreenCaptureAccess() else {
            refreshScreenRecordingAccess()
            return
        }
        let granted = CGRequestScreenCaptureAccess()
        refreshScreenRecordingAccess()
        if !granted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshScreenRecordingAccess() {
        let unavailable = !CGPreflightScreenCaptureAccess()
        if needsScreenRecording != unavailable { needsScreenRecording = unavailable }
        if unavailable {
            stopLivePreviews(keepSnapshots: false)
            images.removeAll()
            costs.removeAll()
            pending.removeAll()
        } else {
            refreshDuePreviews()
        }
    }

    private func updateAspectRatios() {
        guard let info = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else { return }
        var ratios = aspectRatios.filter { windows[$0.key] != nil }
        for item in info {
            guard let id = item[kCGWindowNumber as String] as? Int, windows[id] != nil,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  frame.width > 1, frame.height > 1 else { continue }
            ratios[id] = frame.width / frame.height
        }
        if aspectRatios != ratios { aspectRatios = ratios }
    }

    private func refreshDuePreviews() {
        guard !needsScreenRecording, !isPresented || liveEnabled else { return }
        reconcileLivePreviews()
        let now = Date()
        for window in windows.values {
            let interval: TimeInterval
            if isPresented {
                guard visibleIDs.contains(window.id) || images[window.id] == nil else { continue }
                guard livePreviews[window.id] == nil else { continue }
                interval = 3
            } else {
                // Warm every new window once, then only refresh the visible workspace.
                guard window.workspaceIsVisible || captureDates[window.id] == nil else { continue }
                interval = 5
            }
            let lastAttempt = attemptDates[window.id] ?? .distantPast
            let lastCapture = captureDates[window.id] ?? .distantPast
            let failedLastTime = lastAttempt > lastCapture
            if now.timeIntervalSince(lastAttempt) >= (failedLastTime ? 10 : interval) {
                request(window, refresh: true)
            }
        }
    }

    func request(_ window: Win, refresh: Bool = false) {
        guard !needsScreenRecording, windows[window.id] != nil,
              livePreviews[window.id] == nil || images[window.id] == nil,
              !inFlight.contains(window.id), !pending.contains(window.id),
              refresh || images[window.id] == nil else { return }
        if window.id == priorityID { pending.insert(window.id, at: 0) }
        else { pending.append(window.id) }
        pump()
    }

    private func pump() {
        while inFlight.count < 3, !pending.isEmpty {
            let id = pending.removeFirst()
            guard let window = windows[id] else { continue }
            inFlight.insert(id)
            attemptDates[id] = Date()
            let started = Date()
            let discovery = discovery
            Task.detached(priority: .userInitiated) { [weak self] in
                // Most windows can be captured immediately, without SCShareableContent discovery.
                var image = OverviewWindowCapture.captureBackingStore(windowID: CGWindowID(id))
                if image == nil, let captureWindow = await discovery.window(id: id) {
                    image = await OverviewWindowCapture.capture(captureWindow)
                }
                let captured = image
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.inFlight.remove(id)
                    guard self.windows[id]?.bundleID == window.bundleID, !self.needsScreenRecording else {
                        self.pump()
                        return
                    }
                    if let captured {
                        self.images[id] = NSImage(cgImage: captured,
                            size: NSSize(width: captured.width, height: captured.height))
                        self.costs[id] = captured.bytesPerRow * captured.height
                        self.captureDates[id] = Date()
                        self.trimCache()
                    }
                    let elapsed = Int(Date().timeIntervalSince(started) * 1000)
                    self.logger.debug("Preview \(id): \(captured != nil ? "ready" : "unavailable") in \(elapsed) ms")
                    self.pump()
                }
            }
        }
    }

    private func stopLivePreviews(keepSnapshots: Bool = true) {
        for preview in livePreviews.values { preview.stop(keepSnapshot: keepSnapshots) }
        livePreviews.removeAll()
        liveSizes.removeAll()
    }

    private func reconcileLivePreviews() {
        guard isPresented, liveEnabled, !needsScreenRecording else { return }
        let wanted = visibleIDs.intersection(windows.keys)
        for id in livePreviews.keys where !wanted.contains(id) {
            livePreviews.removeValue(forKey: id)?.stop()
            liveSizes.removeValue(forKey: id)
        }
        // Bound the total video surface area across all displays, then let the
        // compositor reuse unchanged frames for static windows.
        let requested = Dictionary(uniqueKeysWithValues: wanted.map { id in
            let size = targetSizes[id] ?? CGSize(width: 960, height: 960 / aspectRatio(for: id))
            let factor = min(1, 3200 / max(1, max(size.width, size.height)))
            return (id, CGSize(width: size.width * factor, height: size.height * factor))
        })
        let pixels = requested.values.reduce(CGFloat.zero) { $0 + $1.width * $1.height }
        let budgetScale = min(1, sqrt(20_000_000 / max(1, pixels)))
        for id in wanted.sorted() {
            guard let window = windows[id], let requestedSize = requested[id] else { continue }
            let size = CGSize(width: max(2, floor(requestedSize.width * budgetScale / 2) * 2),
                              height: max(2, floor(requestedSize.height * budgetScale / 2) * 2))
            if let preview = livePreviews[id] {
                if liveSizes[id] != size {
                    liveSizes[id] = size
                    Task { @MainActor in await preview.resize(to: size) }
                }
                continue
            }
            guard Date() >= (liveRetryDates[id] ?? .distantPast) else { continue }
            let token = generation
            let preview = OverviewLivePreview(windowID: id, pixelSize: size, onFailure: { [weak self] in
                guard let self, token == self.generation else { return }
                self.livePreviews.removeValue(forKey: id)?.stop()
                self.liveSizes.removeValue(forKey: id)
                self.liveRetryDates[id] = Date().addingTimeInterval(5)
            }, onSnapshot: { [weak self] image in
                guard let self, token == self.generation, !self.needsScreenRecording,
                      self.windows[id]?.bundleID == window.bundleID else { return }
                self.images[id] = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                self.costs[id] = image.bytesPerRow * image.height
                self.captureDates[id] = Date()
                self.trimCache()
            })
            livePreviews[id] = preview
            liveSizes[id] = size
            let discovery = discovery
            Task { @MainActor [weak self, weak preview] in
                let captureWindow = await discovery.window(id: id)
                guard let self, let preview, token == self.generation,
                      self.isPresented, self.livePreviews[id] === preview else { return }
                do {
                    guard let captureWindow else { throw CocoaError(.fileNoSuchFile) }
                    try await preview.start(window: captureWindow)
                } catch {
                    guard self.livePreviews[id] === preview else { return }
                    preview.stop()
                    self.livePreviews.removeValue(forKey: id)
                    self.liveSizes.removeValue(forKey: id)
                    self.liveRetryDates[id] = Date().addingTimeInterval(5)
                    self.logger.error("Live preview unavailable for window \(id): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func trimCache() {
        var total = costs.values.reduce(0, +)
        for id in costs.keys.sorted(by: { (captureDates[$0] ?? .distantPast) < (captureDates[$1] ?? .distantPast) }) {
            guard total > memoryLimit else { break }
            total -= costs.removeValue(forKey: id) ?? 0
            images.removeValue(forKey: id)
        }
    }
}

private actor OverviewWindowDiscovery {
    private var lookup: Task<[Int: SCWindow]?, Never>?
    private var expires = Date.distantPast
    private var generation = 0

    func window(id: Int) async -> SCWindow? {
        if lookup == nil || Date() >= expires {
            generation += 1
            let generation = generation
            expires = Date().addingTimeInterval(10)
            lookup = Task {
                guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                else { return nil }
                return Dictionary(content.windows.map { (Int($0.windowID), $0) }) { first, _ in first }
            }
            return await result(id: id, generation: generation)
        }
        return await result(id: id, generation: generation)
    }

    private func result(id: Int, generation: Int) async -> SCWindow? {
        guard let lookup else { return nil }
        let windows = await lookup.value
        guard generation == self.generation else { return windows?[id] }
        if windows?[id] == nil {
            // Keep one shared retry window for concurrent preview requests.
            expires = Date().addingTimeInterval(0.5)
        }
        return windows?[id]
    }
}

private enum OverviewWindowCapture {
    private typealias CreateWindowImage = @convention(c) (
        CGRect, UInt32, UInt32, UInt32
    ) -> Unmanaged<CGImage>?

    /// Fast access to a window's backing store, resolved dynamically because
    /// Apple deprecated this entry point and may remove it in a future macOS.
    private static let createWindowImage: CreateWindowImage? = {
        guard let handle = dlopen(nil, RTLD_NOW),
              let symbol = dlsym(handle, "CGWindowListCreateImage")
        else {
            return nil
        }
        return unsafeBitCast(symbol, to: CreateWindowImage.self)
    }()

    static func capture(_ window: SCWindow) async -> CGImage? {
        let size = window.frame.size
        let maxDimension: CGFloat = 1920
        let scale = min(1, maxDimension / max(max(size.width, size.height), 1))
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((size.width * scale).rounded()))
        configuration.height = max(1, Int((size.height * scale).rounded()))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.captureResolution = .best

        do {
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            return downscaled(image, maxDimension: maxDimension)
        } catch {
            return nil
        }
    }

    static func captureBackingStore(windowID: CGWindowID) -> CGImage? {
        guard let createWindowImage,
              // kCGWindowListOptionIncludingWindow
              let result = createWindowImage(.null, 1 << 3, windowID, (1 << 0) | (1 << 3))?.takeRetainedValue(),
              result.width > 1,
              result.height > 1
        else {
            return nil
        }
        return downscaled(result, maxDimension: 1920)
    }

    private static func downscaled(_ image: CGImage, maxDimension: CGFloat) -> CGImage {
        let longEdge = CGFloat(max(image.width, image.height))
        let scale = min(1, maxDimension / max(longEdge, 1))
        guard scale < 1 else { return image }
        let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return image
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}
