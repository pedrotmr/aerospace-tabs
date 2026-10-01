import AppKit
@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import CoreImage
import Darwin
import SwiftUI
import os

/// One window stream, rendered without publishing video frames through SwiftUI.
final class OverviewLivePreview: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let displayLayer = AVSampleBufferDisplayLayer()
    private let renderer: AVSampleBufferVideoRenderer
    private let outputQueue: DispatchQueue
    private var stream: SCStream?
    private var pixelSize: CGSize
    private var stopped = false
    private let onFailure: () -> Void
    private let onSnapshot: (CGImage) -> Void
    private let logger = Logger(subsystem: "com.pedrotmr.AerospaceTabs", category: "OverviewLive")
    private let windowID: Int

    // Accessed only on outputQueue.
    private var acceptingFrames = true
    private var latestBuffer: CVPixelBuffer?
    private var frameCount = 0
    private let started = ContinuousClock.now
    private static let imageContext = CIContext(options: [.cacheIntermediates: false])

    static func releaseTransientResources() {
        imageContext.clearCaches()
        // Return freed capture buffers that the allocator otherwise keeps for reuse.
        malloc_zone_pressure_relief(nil, 0)
    }

    init(windowID: Int, pixelSize: CGSize, onFailure: @escaping () -> Void,
         onSnapshot: @escaping (CGImage) -> Void) {
        self.windowID = windowID
        self.pixelSize = pixelSize
        self.onFailure = onFailure
        self.onSnapshot = onSnapshot
        renderer = displayLayer.sampleBufferRenderer
        outputQueue = DispatchQueue(label: "overview.video.\(windowID)", qos: .userInteractive)
        super.init()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = NSColor.clear.cgColor
        displayLayer.isHidden = true
    }

    @MainActor
    func start(window: SCWindow) async throws {
        guard !stopped else { return }
        let stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: window),
                              configuration: configuration(), delegate: self)
        self.stream = stream
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        logger.debug("Window \(self.windowID): stream resolution \(Int(self.pixelSize.width)) × \(Int(self.pixelSize.height))")
        try await stream.startCapture()
        // Closing during startCapture must not leave a late-starting stream running.
        if stopped { try? await stream.stopCapture() }
    }

    @MainActor
    func resize(to size: CGSize) async {
        guard size != pixelSize, !stopped else { return }
        pixelSize = size
        try? await stream?.updateConfiguration(configuration())
    }

    @MainActor
    private func configuration() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = max(2, Int(pixelSize.width))
        config.height = max(2, Int(pixelSize.height))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false
        config.capturesAudio = false
        config.ignoreShadowsSingleWindow = true
        config.scalesToFit = true
        config.captureResolution = .best
        return config
    }

    /// Stop accepting frames immediately; release the stream asynchronously.
    @MainActor
    func stop(keepSnapshot: Bool = true) {
        guard !stopped else { return }
        stopped = true
        displayLayer.removeFromSuperlayer()
        let stream = self.stream
        self.stream = nil
        outputQueue.async { [self] in
            acceptingFrames = false
            if keepSnapshot, let buffer = latestBuffer {
                let image = CIImage(cvPixelBuffer: buffer)
                if let snapshot = Self.imageContext.createCGImage(image, from: image.extent) {
                    DispatchQueue.main.async { [self] in onSnapshot(snapshot) }
                }
            }
            latestBuffer = nil
            renderer.flush(removingDisplayedImage: true)
            let frames = frameCount
            logger.debug("Window \(self.windowID): stopped after \(frames) frames")
        }
        Task { @MainActor in
            try? await stream?.stopCapture()
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard acceptingFrames, outputType == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let buffer = sampleBuffer.imageBuffer else { return }
        latestBuffer = buffer
        if renderer.status == .failed { renderer.flush() }
        guard renderer.isReadyForMoreMediaData else { return }
        if let array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(array) > 0 {
            let values = unsafeBitCast(CFArrayGetValueAtIndex(array, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(values,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        renderer.enqueue(sampleBuffer)
        frameCount += 1
        if frameCount == 1 {
            logger.debug("Window \(self.windowID): first live frame after \(String(describing: self.started.duration(to: .now)), privacy: .public)")
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.stopped else { return }
                self.displayLayer.isHidden = false
            }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Window \(self.windowID): stream stopped: \(error.localizedDescription, privacy: .public)")
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.stopped else { return }
            self.onFailure()
        }
    }
}

struct OverviewLivePreviewView: NSViewRepresentable {
    let preview: OverviewLivePreview

    func makeNSView(context: Context) -> OverviewVideoView {
        let view = OverviewVideoView()
        view.setPreview(preview)
        return view
    }

    func updateNSView(_ nsView: OverviewVideoView, context: Context) {
        nsView.setPreview(preview)
    }
}

final class OverviewVideoView: NSView {
    private weak var preview: OverviewLivePreview?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func setPreview(_ preview: OverviewLivePreview) {
        guard self.preview !== preview else { return }
        self.preview?.displayLayer.removeFromSuperlayer()
        self.preview = preview
        wantsLayer = true
        layer?.addSublayer(preview.displayLayer)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        layer?.contentsScale = scale
        preview?.displayLayer.contentsScale = scale
        preview?.displayLayer.frame = bounds
        CATransaction.commit()
    }
}
