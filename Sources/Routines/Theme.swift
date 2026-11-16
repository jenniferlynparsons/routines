import SwiftUI
import AppKit

/// The palette: coolors.co/93b7be-554348-d4f5f5-8c9a9e-747578
enum Palette {
    static let ash: UInt32 = 0x93B7BE     // soft teal
    static let plum: UInt32 = 0x554348    // deep taupe
    static let mist: UInt32 = 0xD4F5F5    // pale aqua
    static let slate: UInt32 = 0x8C9A9E   // light gray-blue
    static let pewter: UInt32 = 0x747578  // mid gray
}

/// What each color is for. Change colors here, not in the views.
enum Theme {
    /// Fills: check circles, progress ring, current-section dot, badges.
    static let accent = Color.adaptive(light: Palette.ash, dark: Palette.ash)
    /// The checkmark drawn on top of an accent fill.
    static let onAccent = Color.adaptive(light: Palette.plum, dark: Palette.plum)
    /// Emphasis: current section name, active pin, badge text.
    static let strong = Color.adaptive(light: Palette.plum, dark: Palette.ash)
    /// Main text.
    static let ink = Color.adaptive(light: Palette.plum, dark: Palette.mist)
    /// Dates, times, counts.
    static let muted = Color.adaptive(light: Palette.pewter, dark: Palette.slate)
    /// Finished items, chevrons.
    static let faint = Color.adaptive(light: Palette.slate, dark: Palette.pewter)
    /// Tint laid over the frosted window background.
    static let wash = Color.adaptive(light: Palette.mist, dark: Palette.plum,
                                     lightAlpha: 0.6, darkAlpha: 0.55)
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    /// A color that follows the system's light or dark appearance.
    static func adaptive(light: UInt32, dark: UInt32,
                         lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? NSColor(hex: dark, alpha: darkAlpha) : NSColor(hex: light, alpha: lightAlpha)
        })
    }
}
