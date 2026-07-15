import SwiftUI

/// Hand-mirrored from meridian_software/design-tokens/tokens.json (the
/// canonical source shared with Insights and Family). Keep in sync with
/// that file and the other Swift mirror (Family) in the same commit.
enum MeridianColor {
    static let primary = Color(hex: 0x0369A1)
    static let primaryAlt = Color(hex: 0x0891B2)
    static let success = Color(hex: 0x059669)
    static let warning = Color(hex: 0xB45309)
    static let destructive = Color(hex: 0xDC2626)
    static let foreground = Color(hex: 0x0C4A6E)
    static let muted = Color(hex: 0xE7EFF5)
    static let border = Color(hex: 0xE0F2FE)
    /// Care app uses the mobile background tone (--color-background: mobile).
    static let background = Color(hex: 0xECFEFF)
    static let surface = Color.white
    static let onPrimary = Color.white
    static let onDestructive = Color.white
}

enum MeridianRadius {
    /// Care stays closer to Accessible & Ethical — smaller, less decorative
    /// radii than Family's warmed-up variant.
    static let card: CGFloat = 12
    static let control: CGFloat = 10
}

enum MeridianSpacing {
    static let unit: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum MeridianTouchTarget {
    /// Critical severity issue if violated — a mis-tap on the wrong
    /// resident's resolve button during a real emergency is a real
    /// failure mode, not a cosmetic one.
    static let minSize: CGFloat = 44
    static let minSpacing: CGFloat = 8
}

enum MeridianMotion {
    static let duration: Double = 0.2
}

enum MeridianFont {
    /// Figtree/Noto Sans aren't practical to bundle reliably for this
    /// timeline — San Francisco (system font) at matching weights hits the
    /// same "medical, clean, accessible, trustworthy" mood.
    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func bodyMedium(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
