import SwiftUI
import AppKit

// MARK: - Palettes

/// Five colors. The app works out which color does which job (see `PaletteRoles`).
struct ColorPalette: Identifiable, Hashable {
    let id: String
    let name: String
    let colors: [UInt32]

    static let customID = "custom"

    static let presets: [ColorPalette] = [
        ColorPalette(id: "sea-glass", name: "Sea Glass",
                     colors: [0x93B7BE, 0x554348, 0xD4F5F5, 0x8C9A9E, 0x747578]),
        ColorPalette(id: "terracotta", name: "Terracotta",
                     colors: [0xF6EDE3, 0xD9774F, 0xA89A8F, 0x7A6A60, 0x3B2A24]),
        ColorPalette(id: "sage", name: "Sage",
                     colors: [0xF1F4EC, 0x8FAE8B, 0xA3A79E, 0x6F746B, 0x2F3A2F]),
        ColorPalette(id: "lavender", name: "Lavender",
                     colors: [0xF3F0FA, 0x9C8AD0, 0xA7A3B3, 0x6F6A7D, 0x37304A]),
        ColorPalette(id: "graphite", name: "Graphite",
                     colors: [0xF2F3F5, 0x5B8DEF, 0xA0A4AB, 0x6B7078, 0x25282D]),
    ]

    var roles: PaletteRoles { PaletteRoles(colors) }

    /// Every six-digit hex code in the text, in order. Accepts "#93b7be, #554348",
    /// "93b7be 554348", or a coolors.co link.
    static func parseHexList(_ text: String) -> [UInt32] {
        guard let regex = try? NSRegularExpression(pattern: "[0-9A-Fa-f]{6}") else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { UInt32(ns.substring(with: $0.range), radix: 16) }
    }

    static func hexString(_ colors: [UInt32]) -> String {
        colors.map { String(format: "%06X", $0) }.joined(separator: "-")
    }
}

/// Assigns each color a job from its brightness and saturation:
/// the darkest is text, the lightest is the background, the most colorful
/// of the middle three is the accent, and the other two are the grays.
struct PaletteRoles {
    let darkest: UInt32
    let lightest: UInt32
    let accent: UInt32
    let darkerGray: UInt32
    let lighterGray: UInt32

    init(_ colors: [UInt32]) {
        let five = colors.count >= 5 ? Array(colors.prefix(5)) : ColorPalette.presets[0].colors
        let sorted = five.sorted { Self.luminance($0) < Self.luminance($1) }
        darkest = sorted[0]
        lightest = sorted[4]

        var middle = Array(sorted[1...3])
        let chosen = middle.max { Self.chroma($0) < Self.chroma($1) } ?? middle[0]
        accent = chosen
        if let index = middle.firstIndex(of: chosen) { middle.remove(at: index) }
        darkerGray = middle[0]
        lighterGray = middle[1]
    }

    /// Readability problems worth telling the person about.
    var warnings: [String] {
        var result: [String] = []
        if Self.contrast(darkest, lightest) < 4.5 {
            result.append("Text may be hard to read. Use a darker dark color or a lighter light color.")
        }
        if Self.contrast(accent, lightest) < 1.5 {
            result.append("Check marks may be hard to see. Use a stronger accent color.")
        }
        return result
    }

    // WCAG relative luminance.
    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ value: UInt32) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF)
            + 0.7152 * channel((hex >> 8) & 0xFF)
            + 0.0722 * channel(hex & 0xFF)
    }

    static func chroma(_ hex: UInt32) -> Int {
        let r = Int((hex >> 16) & 0xFF), g = Int((hex >> 8) & 0xFF), b = Int(hex & 0xFF)
        return max(r, g, b) - min(r, g, b)
    }

    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

// MARK: - Saved choice

final class PaletteStore: ObservableObject {
    static let shared = PaletteStore()

    @Published private(set) var selectionID: String
    @Published private(set) var customColors: [UInt32]?

    private let defaults = UserDefaults.standard

    private init() {
        selectionID = defaults.string(forKey: "paletteID") ?? ColorPalette.presets[0].id
        let saved = ColorPalette.parseHexList(defaults.string(forKey: "customPalette") ?? "")
        customColors = saved.count == 5 ? saved : nil
    }

    var customPalette: ColorPalette? {
        customColors.map { ColorPalette(id: ColorPalette.customID, name: "Custom", colors: $0) }
    }

    var current: ColorPalette {
        if selectionID == ColorPalette.customID, let custom = customPalette { return custom }
        return ColorPalette.presets.first { $0.id == selectionID } ?? ColorPalette.presets[0]
    }

    func select(_ id: String) {
        selectionID = id
        defaults.set(id, forKey: "paletteID")
    }

    func useCustom(_ colors: [UInt32]) {
        customColors = colors
        defaults.set(ColorPalette.hexString(colors), forKey: "customPalette")
        select(ColorPalette.customID)
    }
}

// MARK: - Color jobs

/// What each color is for. Views use these, never raw hex values.
enum Theme {
    private static var roles: PaletteRoles { PaletteStore.shared.current.roles }

    /// Fills: check circles, progress ring, current-section dot, badges.
    static var accent: Color { .adaptive(light: roles.accent, dark: roles.accent) }
    /// The checkmark drawn on top of an accent fill.
    static var onAccent: Color { .adaptive(light: roles.darkest, dark: roles.darkest) }
    /// Emphasis: current section name, active pin, badge text.
    static var strong: Color { .adaptive(light: roles.darkest, dark: roles.accent) }
    /// Main text.
    static var ink: Color { .adaptive(light: roles.darkest, dark: roles.lightest) }
    /// Dates, times, counts.
    static var muted: Color { .adaptive(light: roles.darkerGray, dark: roles.lighterGray) }
    /// Finished items, chevrons.
    static var faint: Color { .adaptive(light: roles.lighterGray, dark: roles.darkerGray) }
    /// Tint laid over the frosted window background.
    static var wash: Color {
        .adaptive(light: roles.lightest, dark: roles.darkest, lightAlpha: 0.6, darkAlpha: 0.55)
    }
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
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }

    /// A color that follows the system's light or dark appearance.
    static func adaptive(light: UInt32, dark: UInt32,
                         lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? NSColor(hex: dark, alpha: darkAlpha) : NSColor(hex: light, alpha: lightAlpha)
        })
    }
}
