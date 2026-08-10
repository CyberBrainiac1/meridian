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

    /// Accessibility pass: secondary/caption text used to be `foreground`
    /// at 50-70% opacity, which measured 2.55-4.25:1 against these
    /// backgrounds (computed via the WCAG relative-luminance formula) —
    /// below the 4.5:1 minimum. This solid color clears 4.5:1 everywhere
    /// (mostly 5-7:1). Severity-badge text used its own color at ~12%
    /// tint as background, which failed for warning/destructive/success;
    /// the *Strong variants are the accessible replacement for that text,
    /// and successStrong doubles as the success button-fill color (white
    /// text on raw success measured 3.77:1, also below minimum).
    static let foregroundMuted = Color(hex: 0x2F5D77)
    static let successStrong = Color(hex: 0x047857)
    static let warningStrong = Color(hex: 0x92400E)
    static let destructiveStrong = Color(hex: 0x991B1B)
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
