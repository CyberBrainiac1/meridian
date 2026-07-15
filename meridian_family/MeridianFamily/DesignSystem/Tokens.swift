import SwiftUI

/// Hand-mirrored from meridian_software/design-tokens/tokens.json (the
/// canonical source shared with Insights and Care). Keep in sync with that
/// file and Care's Tokens.swift mirror in the same commit.
///
/// Family uses the same base palette as Care, warmed up: primary/success
/// swap emphasis (success-forward, since most of what Family sees is good
/// news), larger radii, more whitespace — never a separate design
/// language. See MeridianRadius/MeridianSpacing below for the concrete
/// deltas from Care.
enum MeridianColor {
    static let primary = Color(hex: 0x0369A1)
    static let primaryAlt = Color(hex: 0x0891B2)
    static let success = Color(hex: 0x059669)
    static let warning = Color(hex: 0xB45309)
    static let destructive = Color(hex: 0xDC2626)
    static let foreground = Color(hex: 0x0C4A6E)
    static let muted = Color(hex: 0xE7EFF5)
    static let border = Color(hex: 0xE0F2FE)
    static let background = Color(hex: 0xECFEFF)
    static let surface = Color.white
    static let onPrimary = Color.white
    static let onDestructive = Color.white

    /// Accessibility pass: secondary/caption text used to be `foreground`
    /// at 50-70% opacity, which measured 2.55-4.25:1 against these
    /// backgrounds (computed via the WCAG relative-luminance formula) —
    /// below the 4.5:1 minimum. This solid color clears 4.5:1 everywhere
    /// (mostly 5-7:1). successStrong is the accessible success button-fill
    /// color (white text on raw success measured 3.77:1, also below
    /// minimum).
    static let foregroundMuted = Color(hex: 0x2F5D77)
    static let successStrong = Color(hex: 0x047857)
    static let warningStrong = Color(hex: 0x92400E)
    static let destructiveStrong = Color(hex: 0x991B1B)
}

enum MeridianRadius {
    /// Family's warmed-up variant: larger card radii than Care/Insights.
    static let card: CGFloat = 20
    static let control: CGFloat = 14
}

enum MeridianSpacing {
    static let unit: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    /// Family leans on more generous whitespace than Care throughout.
    static let md: CGFloat = 20
    static let lg: CGFloat = 32
    static let xl: CGFloat = 40
}

enum MeridianTouchTarget {
    static let minSize: CGFloat = 44
    static let minSpacing: CGFloat = 8
}

enum MeridianMotion {
    static let duration: Double = 0.2
}

enum MeridianFont {
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
