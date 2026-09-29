import AppKit
import Foundation

/// Polls for the configured corner and fires once until the pointer leaves it.
final class HotCornerMonitor {
  var onTrigger: (() -> Void)?

  private var timer: Timer?
  private var settingsObserver: NSObjectProtocol?
  private var hasFired = false
  private var isSuspended = false

  private let cornerSize: CGFloat = 14

  func start() {
    guard settingsObserver == nil else { return }
    settingsObserver = NotificationCenter.default.addObserver(
      forName: OverviewSettings.didChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.syncTimer()
    }
    syncTimer()
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    hasFired = false
    if let settingsObserver {
      NotificationCenter.default.removeObserver(settingsObserver)
      self.settingsObserver = nil
    }
  }

  func setSuspended(_ suspended: Bool) {
    guard suspended != isSuspended else { return }
    isSuspended = suspended
    let activeCorner = Self.corner(at: NSEvent.mouseLocation, size: cornerSize)
    if let configuredCorner = OverviewSettings.shared.hotCorner,
      activeCorner == configuredCorner
    {
      hasFired = true
    } else {
      hasFired = false
    }
  }

  private func syncTimer() {
    hasFired = false
    guard OverviewSettings.shared.hotCorner != nil else {
      timer?.invalidate()
      timer = nil
      return
    }
    guard timer == nil else { return }
    let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
      self?.tick()
    }
    timer.tolerance = 0.005
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  private func tick() {
    guard !isSuspended, let configuredCorner = OverviewSettings.shared.hotCorner else { return }
    let currentCorner = Self.corner(at: NSEvent.mouseLocation, size: cornerSize)
    guard currentCorner == configuredCorner else {
      hasFired = false
      return
    }

    guard !hasFired else { return }
    hasFired = true
    onTrigger?()
  }

  private static func corner(at point: CGPoint, size: CGFloat) -> OverviewHotCorner? {
    for screen in NSScreen.screens {
      let frame = screen.frame
      // The pointer can sit exactly on maxY at a top corner. CGRect.contains
      // excludes that edge, so check all four screen edges inclusively.
      guard point.x >= frame.minX, point.x <= frame.maxX,
        point.y >= frame.minY, point.y <= frame.maxY
      else { continue }
      if point.x <= frame.minX + size, point.y >= frame.maxY - size { return .topLeft }
      if point.x >= frame.maxX - size, point.y >= frame.maxY - size { return .topRight }
      if point.x <= frame.minX + size, point.y <= frame.minY + size { return .bottomLeft }
      if point.x >= frame.maxX - size, point.y <= frame.minY + size { return .bottomRight }
    }
    return nil
  }
}
