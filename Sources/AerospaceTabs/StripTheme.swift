import AppKit

/// Visual chrome for the tab strip. Add a case + `chrome` branch to ship a new look.
enum StripTheme: String, CaseIterable, Equatable {
    case glass
    case solid

    var title: String {
        switch self {
        case .glass: return "Glass"
        case .solid: return "Solid"
        }
    }

    var chrome: StripChromeStyle {
        switch self {
        case .glass:
            return StripChromeStyle(
                material: .hudWindow,
                blendingMode: .behindWindow,
                appearanceName: nil,
                wash: nil,
                rimAlpha: 0.10
            )
        case .solid:
            return StripChromeStyle(
                material: .popover,
                blendingMode: .withinWindow,
                appearanceName: .darkAqua,
                wash: NSColor(calibratedWhite: 0.12, alpha: 0.88),
                rimAlpha: 0.14
            )
        }
    }
}

struct StripChromeStyle {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var appearanceName: NSAppearance.Name?
    /// `nil` hides the wash layer so vibrancy shows through.
    var wash: NSColor?
    var rimAlpha: CGFloat
}
