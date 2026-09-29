import CoreFoundation
import Foundation
import AppKit
import Darwin
import os

/// Reads three-finger trackpad movement through MultitouchSupport when that
/// private framework is present. No private framework is linked at build time.
final class ThreeFingerSwipeMonitor {
    enum Direction { case up, down }
    var onSwipe: ((Direction) -> Void)?
    var onAvailabilityChanged: (() -> Void)?
    private static let logger = Logger(subsystem: "com.pedrotmr.AerospaceTabs", category: "Trackpad")
    private(set) var isRunning = false
    private(set) var isAvailable = false
    var canOwnGesture: Bool { wantsMonitoring && framework != nil && hasConnectedDevice }

    private typealias DeviceRef = UnsafeMutableRawPointer
    private typealias ContactCallback = @convention(c) (
        UnsafeMutableRawPointer?, UnsafeRawPointer?, Int32, Double, Int32
    ) -> Int32

    private var framework: Framework?
    private var devices: CFArray?
    private var wakeObserver: NSObjectProtocol?
    private var recoveryTimer: Timer?
    private var wantsMonitoring = false
    private var hasConnectedDevice = false

    private static let active = ActiveState()

    private final class ActiveState: @unchecked Sendable {
        private let lock = NSLock()
        private var receivedFrame = false
        private weak var monitor: ThreeFingerSwipeMonitor?
        private var detectors: [UnsafeRawPointer: VerticalSwipeDetector] = [:]

        func activate(_ monitor: ThreeFingerSwipeMonitor, detectors: [UnsafeRawPointer: VerticalSwipeDetector]) {
            lock.lock()
            defer { lock.unlock() }
            receivedFrame = false
            self.monitor = monitor
            self.detectors = detectors
        }

        func deactivate() {
            lock.lock()
            defer { lock.unlock() }
            monitor = nil
            detectors.removeAll()
        }

        func lookup(_ device: UnsafeRawPointer?) -> (ThreeFingerSwipeMonitor, VerticalSwipeDetector)? {
            lock.lock()
            defer { lock.unlock() }
            guard let monitor, let device, let detector = detectors[device] else { return nil }
            if !receivedFrame {
                receivedFrame = true
                ThreeFingerSwipeMonitor.logger.info("Trackpad contact frames are arriving")
            }
            return (monitor, detector)
        }
    }

    @discardableResult
    func start() -> Bool {
        wantsMonitoring = true
        observeWake()
        if recoveryTimer == nil {
            recoveryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                guard let self, self.wantsMonitoring else { return }
                self.refreshDevices()
            }
        }
        return isRunning || connectDevices()
    }

    private var devicesAreRunning: Bool {
        guard let devices, let framework else { return false }
        guard let isDeviceRunning = framework.isDeviceRunning else { return isRunning }
        return (0..<CFArrayGetCount(devices)).allSatisfy { index in
            guard let raw = CFArrayGetValueAtIndex(devices, index) else { return false }
            return isDeviceRunning(DeviceRef(mutating: raw))
        }
    }

    private func connectDevices(using discoveredDevices: CFArray? = nil) -> Bool {
        guard let framework = framework ?? Framework.load() else {
            setAvailable(false)
            Self.logger.error("MultitouchSupport could not be loaded; will retry")
            return false
        }
        self.framework = framework
        guard let list = discoveredDevices ?? framework.createList()?.takeRetainedValue(),
              CFArrayGetCount(list) > 0 else {
            setAvailable(false)
            Self.logger.info("No trackpad devices yet; waiting for device recovery")
            return false
        }

        var detectors: [UnsafeRawPointer: VerticalSwipeDetector] = [:]
        for index in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let size = framework.padSizeMM(of: DeviceRef(mutating: raw))
            detectors[raw] = VerticalSwipeDetector(widthMM: size.width, heightMM: size.height)
        }
        guard !detectors.isEmpty else { setAvailable(false); return false }
        devices = list
        // Install routing before devices can deliver their first callback.
        Self.active.activate(self, detectors: detectors)
        for raw in detectors.keys {
            let device = DeviceRef(mutating: raw)
            framework.register(device, Self.contactCallback)
            framework.start(device, 0)
        }
        isRunning = true
        let devicesStarted = devicesAreRunning
        isRunning = devicesStarted
        if devicesStarted { hasConnectedDevice = true }
        setAvailable(devicesStarted)
        Self.logger.info(
            "Three-finger swipe started on \(detectors.count) trackpad device(s); running=\(devicesStarted)"
        )
        return devicesStarted
    }

    private func refreshDevices() {
        guard let framework else {
            _ = connectDevices()
            return
        }
        guard let discovered = framework.createList()?.takeRetainedValue() else { return }
        let currentIDs = deviceIDs(in: devices)
        let discoveredIDs = deviceIDs(in: discovered)
        if discoveredIDs.isEmpty, !currentIDs.isEmpty, devicesAreRunning { return }
        guard !isRunning || !devicesAreRunning || currentIDs != discoveredIDs else { return }
        stopDevices()
        _ = connectDevices(using: discovered)
    }

    private func deviceIDs(in devices: CFArray?) -> Set<UInt> {
        guard let devices else { return [] }
        return Set((0..<CFArrayGetCount(devices)).compactMap { index in
            CFArrayGetValueAtIndex(devices, index).map { UInt(bitPattern: $0) }
        })
    }

    private func setAvailable(_ available: Bool) {
        guard available != isAvailable else { return }
        isAvailable = available
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wantsMonitoring else { return }
            self.onAvailabilityChanged?()
        }
    }

    func stop() {
        wantsMonitoring = false
        hasConnectedDevice = false
        recoveryTimer?.invalidate()
        recoveryTimer = nil
        removeWakeObserver()
        stopDevices()
    }

    private func stopDevices() {
        Self.active.deactivate()
        isRunning = false
        guard let framework, let devices else { return }
        for index in 0..<CFArrayGetCount(devices) {
            guard let rawDevice = CFArrayGetValueAtIndex(devices, index) else { continue }
            let device = DeviceRef(mutating: rawDevice)
            framework.stop(device)
            framework.unregister(device, Self.contactCallback)
        }
        self.devices = nil
    }

    private func observeWake() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            guard self.wantsMonitoring else { return }
            self.stopDevices()
            _ = self.connectDevices()
        }
    }

    private func removeWakeObserver() {
        guard let wakeObserver else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        self.wakeObserver = nil
    }

    private static let contactCallback: ContactCallback = { device, touches, count, timestamp, _ in
        guard let (monitor, detector) = active.lookup(device.map(UnsafeRawPointer.init)) else {
            return 0
        }
        if let direction = detector.consume(touches: touches, count: Int(count), timestamp: timestamp) {
            DispatchQueue.main.async { [weak monitor] in
                guard let monitor, monitor.isRunning, OverviewSettings.shared.swipeEnabled else { return }
                ThreeFingerSwipeMonitor.logger.info("Three-finger swipe \(direction == .up ? "up" : "down") recognized")
                monitor.onSwipe?(direction)
            }
        }
        return 0
    }

    private struct Framework {
        let handle: UnsafeMutableRawPointer
        let createList: @convention(c) () -> Unmanaged<CFArray>?
        let register: @convention(c) (DeviceRef?, ContactCallback?) -> Void
        let unregister: @convention(c) (DeviceRef?, ContactCallback?) -> Void
        let start: @convention(c) (DeviceRef?, Int32) -> Void
        let stop: @convention(c) (DeviceRef?) -> Void
        let isDeviceRunning: (@convention(c) (DeviceRef?) -> Bool)?
        let surfaceDimensions: (@convention(c) (
            DeviceRef?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?
        ) -> Int32)?

        func padSizeMM(of device: DeviceRef) -> (width: Float, height: Float) {
            var width: Int32 = 0
            var height: Int32 = 0
            _ = surfaceDimensions?(device, &width, &height)
            guard width > 1000, width < 50000, height > 1000, height < 50000 else {
                return (120, 80)
            }
            return (Float(width) / 100, Float(height) / 100)
        }

        static func load() -> Framework? {
            let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
            guard let handle = dlopen(path, RTLD_NOW) else { return nil }

            func symbol<T>(_ name: String, as _: T.Type) -> T? {
                guard let pointer = dlsym(handle, name) else { return nil }
                return unsafeBitCast(pointer, to: T.self)
            }

            guard
                let createList = symbol("MTDeviceCreateList", as: (@convention(c) () -> Unmanaged<CFArray>?).self),
                let register = symbol(
                    "MTRegisterContactFrameCallback",
                    as: (@convention(c) (DeviceRef?, ContactCallback?) -> Void).self
                ),
                let unregister = symbol(
                    "MTUnregisterContactFrameCallback",
                    as: (@convention(c) (DeviceRef?, ContactCallback?) -> Void).self
                ),
                let start = symbol("MTDeviceStart", as: (@convention(c) (DeviceRef?, Int32) -> Void).self),
                let stop = symbol("MTDeviceStop", as: (@convention(c) (DeviceRef?) -> Void).self)
            else {
                dlclose(handle)
                return nil
            }

            return Framework(
                handle: handle,
                createList: createList,
                register: register,
                unregister: unregister,
                start: start,
                stop: stop,
                isDeviceRunning: symbol("MTDeviceIsRunning", as: (@convention(c) (DeviceRef?) -> Bool).self),
                surfaceDimensions: symbol(
                    "MTDeviceGetSensorSurfaceDimensions",
                    as: (@convention(c) (
                        DeviceRef?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?
                    ) -> Int32).self
                )
            )
        }
    }
}

/// The MultitouchSupport contact layout used by current Mac trackpads. Its
/// memory layout follows AeroKit's community-documented MTTouch definition;
/// see THIRD-PARTY-NOTICES.md. The detector reads identity, state, and position.
private struct MultitouchContact {
    struct Point { var x: Float; var y: Float }
    struct Readout { var position: Point; var velocity: Point }

    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalized: Readout
    var total: Float
    var pressure: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absolute: Readout
    var field14: Int32
    var field15: Int32
    var density: Float

    var isTouching: Bool { state == 3 || state == 4 }
}

private final class VerticalSwipeDetector: @unchecked Sendable {
    private let lock = NSLock()
    private let widthMM: Float
    private let heightMM: Float
    private var baselines: [Int32: MultitouchContact.Point] = [:]
    private var didFire = false
    private var cancelled = false
    private var startedAt: Double?

    init(widthMM: Float, heightMM: Float) {
        self.widthMM = widthMM
        self.heightMM = heightMM
    }

    func consume(touches: UnsafeRawPointer?, count: Int, timestamp: Double) -> ThreeFingerSwipeMonitor.Direction? {
        lock.lock()
        defer { lock.unlock() }

        guard (0...16).contains(count) else {
            reset()
            return nil
        }
        let records = touches?.assumingMemoryBound(to: MultitouchContact.self)
        var active: [(id: Int32, x: Float, y: Float)] = []
        if let records {
            active.reserveCapacity(min(count, 4))
            for index in 0..<count where records[index].isTouching {
                guard records[index].normalized.position.x.isFinite,
                      records[index].normalized.position.y.isFinite else { continue }
                active.append((
                    records[index].identifier,
                    records[index].normalized.position.x,
                    records[index].normalized.position.y
                ))
            }
        }

        if active.count == 0 {
            reset()
            return nil
        }
        if active.count > 3 {
            cancelled = true
            baselines.removeAll()
            return nil
        }
        guard active.count == 3, !cancelled, !didFire else { return nil }

        if baselines.isEmpty {
            baselines = Dictionary(uniqueKeysWithValues: active.map { ($0.id, MultitouchContact.Point(x: $0.x, y: $0.y)) })
            startedAt = timestamp
            return nil
        }
        if let startedAt, timestamp - startedAt > 1.4 {
            baselines = Dictionary(uniqueKeysWithValues: active.map { ($0.id, MultitouchContact.Point(x: $0.x, y: $0.y)) })
            self.startedAt = timestamp
            return nil
        }
        guard Set(active.map(\.id)) == Set(baselines.keys) else {
            baselines = Dictionary(uniqueKeysWithValues: active.map { ($0.id, MultitouchContact.Point(x: $0.x, y: $0.y)) })
            startedAt = timestamp
            return nil
        }

        let verticalTravel = active.compactMap { finger -> Float? in
            guard let baseline = baselines[finger.id] else { return nil }
            return (finger.y - baseline.y) * heightMM
        }
        let horizontalTravel = active.compactMap { finger -> Float? in
            guard let baseline = baselines[finger.id] else { return nil }
            return (finger.x - baseline.x) * widthMM
        }
        let vertical = verticalTravel.reduce(0, +) / Float(max(verticalTravel.count, 1))
        let horizontal = horizontalTravel.reduce(0, +) / Float(max(horizontalTravel.count, 1))
        guard verticalTravel.count == 3,
              horizontalTravel.count == 3,
              verticalTravel.allSatisfy({ vertical > 0 ? $0 >= 5 : $0 <= -5 }),
              abs(vertical) >= 9,
              abs(vertical) > abs(horizontal) * 1.25
        else {
            return nil
        }

        didFire = true
        return vertical > 0 ? .up : .down
    }

    private func reset() {
        baselines.removeAll()
        didFire = false
        cancelled = false
        startedAt = nil
    }
}
