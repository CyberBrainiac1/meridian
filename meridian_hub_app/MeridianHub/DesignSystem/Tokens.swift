import SwiftUI

/// Carried over from the web Hub's globals.css, which is being retired.
/// Every pair below was computed with the WCAG relative-luminance formula,
/// not eyeballed, and the critical actions clear AAA (7:1) rather than AA:
///
///     white on primary      #075985  ->  7.56:1  (AAA)
///     white on destructive  #991b1b  ->  8.31:1  (AAA)
///     white on success      #065f46  ->  7.68:1  (AAA)
///     foreground   #0c4a6e on white  ->  9.46:1  (AAA)
///     foregroundMuted #0f3d54 on white -> 11.57:1 (AAA)
///     border       #0284c7 on white  ->  4.10:1  (non-text needs 3:1)
///
/// These are deliberately NOT the same values as Care's and Family's tokens.
/// Those two are read by staff and adult family on their own phones; this app
/// is read by someone who may be 88 with cataracts, so it trades brand
/// subtlety for contrast headroom.
enum MeridianColor {
    static let primary = Color(hex: 0x075985)
    static let primaryHover = Color(hex: 0x0C4A6E)
    static let foreground = Color(hex: 0x0C4A6E)
    static let foregroundMuted = Color(hex: 0x0F3D54)
    static let background = Color(hex: 0xECFEFF)
    static let surface = Color.white
    static let border = Color(hex: 0x0284C7)
    static let borderSoft = Color(hex: 0x7DD3FC)
    static let destructive = Color(hex: 0x991B1B)
    static let success = Color(hex: 0x065F46)
    static let warning = Color(hex: 0x92400E)
    static let accentWash = Color(hex: 0xE0F2FE)
    static let onPrimary = Color.white
}

/// Type sized for presbyopic eyes. The web Hub used 22px body / 32px+ action
/// labels; on a phone held closer than a room tablet these land at 21pt and
/// 30pt, still far above the 16pt/24pt floor the senior-UX audit set.
enum MeridianFont {
    static func title(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    static func heading(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func action(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    static func body(_ size: CGFloat = 21) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func bodyStrong(_ size: CGFloat = 21) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
}

enum MeridianSpacing {
    static let unit: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum MeridianRadius {
    static let card: CGFloat = 20
    static let control: CGFloat = 16
}

enum MeridianTouchTarget {
    /// Well past Apple's 44pt floor. A tremor plus a 44pt target is a
    /// mis-tap, and on this app a mis-tap can mean pressing Emergency by
    /// accident — or worse, missing it.
    static let minSize: CGFloat = 60
    /// 16pt between adjacent controls, so a slipped thumb lands on nothing
    /// rather than on the wrong action.
    static let minSpacing: CGFloat = 16
    static let primaryHeight: CGFloat = 116
}

enum MeridianMotion {
    static let duration: Double = 0.2
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
