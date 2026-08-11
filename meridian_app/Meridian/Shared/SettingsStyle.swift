import SwiftUI

/// One Settings screen, three design systems.
///
/// Care, Hub and Family deliberately do NOT share a design system — the Hub's
/// type is sized for an 88-year-old with cataracts and would look absurd on a
/// caregiver's alert list, and Care's 44pt targets are a mis-tap waiting to
/// happen under a tremor. `SettingsView` is the first screen all three share,
/// so rather than let it pick one house style and impose it on the other two,
/// it resolves this bundle from the surface it is showing and never names
/// `MeridianColor`/`HubColor`/`FamColor` directly.
///
/// Adding a surface means adding a case here, and the compiler will not let
/// that be forgotten.
struct SettingsStyle {
    // Colour
    let background: Color
    let surface: Color
    let foreground: Color
    let foregroundMuted: Color
    let primary: Color
    let onPrimary: Color
    let border: Color
    let success: Color
    let warning: Color
    let destructive: Color
    /// A soft fill for callouts that must not read as an alert.
    let wash: Color

    // Type. Held as resolved `Font` values rather than as sizes, so the Hub's
    // live text-size multiplier is applied once, here, by `HubFont`.
    let titleFont: Font
    let headingFont: Font
    let sectionFont: Font
    let bodyFont: Font
    let bodyStrongFont: Font
    let captionFont: Font
    /// Icons are sized off the body text so they grow with it on the Hub.
    let iconFont: Font

    // Metrics
    let spacingXS: CGFloat
    let spacingSM: CGFloat
    let spacingMD: CGFloat
    let spacingLG: CGFloat
    let cardRadius: CGFloat
    let controlRadius: CGFloat
    /// Never violated by anything on this screen — see each surface's own
    /// touch-target token for why the number is what it is.
    let minTouchTarget: CGFloat
    let minSpacing: CGFloat
    /// Border weight. The Hub draws heavy strokes because a hairline is not
    /// visible to the eyes this surface is built for.
    let borderWidth: CGFloat

    static func resolve(for surface: MeridianSurface) -> SettingsStyle {
        switch surface {
        case .care: return .care
        case .hub: return .hub
        case .family: return .family
        }
    }

    private static let care = SettingsStyle(
        background: MeridianColor.background,
        surface: MeridianColor.surface,
        foreground: MeridianColor.foreground,
        foregroundMuted: MeridianColor.foregroundMuted,
        primary: MeridianColor.primary,
        onPrimary: MeridianColor.onPrimary,
        border: MeridianColor.border,
        success: MeridianColor.successStrong,
        warning: MeridianColor.warningStrong,
        destructive: MeridianColor.destructiveStrong,
        wash: MeridianColor.muted,
        titleFont: MeridianFont.heading(26),
        headingFont: MeridianFont.heading(19),
        sectionFont: MeridianFont.bodyMedium(13),
        bodyFont: MeridianFont.body(16),
        bodyStrongFont: MeridianFont.bodyMedium(16),
        captionFont: MeridianFont.body(14),
        iconFont: MeridianFont.bodyMedium(18),
        spacingXS: MeridianSpacing.xs,
        spacingSM: MeridianSpacing.sm,
        spacingMD: MeridianSpacing.md,
        spacingLG: MeridianSpacing.lg,
        cardRadius: MeridianRadius.card,
        controlRadius: MeridianRadius.control,
        minTouchTarget: MeridianTouchTarget.minSize,
        minSpacing: MeridianTouchTarget.minSpacing,
        borderWidth: 1
    )

    /// Not a static stored property: `HubFont` multiplies every size by the
    /// resident's chosen text scale, so these have to be read fresh each time
    /// the setting changes rather than frozen at first access.
    private static var hub: SettingsStyle {
        SettingsStyle(
            background: HubColor.background,
            surface: HubColor.surface,
            foreground: HubColor.foreground,
            foregroundMuted: HubColor.foregroundMuted,
            primary: HubColor.primary,
            onPrimary: HubColor.onPrimary,
            border: HubColor.borderSoft,
            success: HubColor.success,
            warning: HubColor.warning,
            destructive: HubColor.destructive,
            wash: HubColor.accentWash,
            titleFont: HubFont.heading(32),
            headingFont: HubFont.heading(26),
            sectionFont: HubFont.bodyStrong(21),
            bodyFont: HubFont.body(21),
            bodyStrongFont: HubFont.bodyStrong(21),
            captionFont: HubFont.body(19),
            iconFont: HubFont.bodyStrong(24),
            spacingXS: HubSpacing.xs,
            spacingSM: HubSpacing.sm,
            spacingMD: HubSpacing.md,
            spacingLG: HubSpacing.lg,
            cardRadius: HubRadius.card,
            controlRadius: HubRadius.control,
            minTouchTarget: HubTouchTarget.minSize,
            minSpacing: HubTouchTarget.minSpacing,
            borderWidth: 3
        )
    }

    private static let family = SettingsStyle(
        background: FamColor.background,
        surface: FamColor.surface,
        foreground: FamColor.foreground,
        foregroundMuted: FamColor.foregroundMuted,
        primary: FamColor.primary,
        onPrimary: FamColor.onPrimary,
        border: FamColor.border,
        success: FamColor.successStrong,
        warning: FamColor.warningStrong,
        destructive: FamColor.destructiveStrong,
        wash: FamColor.muted,
        titleFont: FamFont.heading(26),
        headingFont: FamFont.heading(19),
        sectionFont: FamFont.bodyMedium(13),
        bodyFont: FamFont.body(16),
        bodyStrongFont: FamFont.bodyMedium(16),
        captionFont: FamFont.body(14),
        iconFont: FamFont.bodyMedium(18),
        spacingXS: FamSpacing.xs,
        spacingSM: FamSpacing.sm,
        spacingMD: FamSpacing.md,
        spacingLG: FamSpacing.lg,
        cardRadius: FamRadius.card,
        controlRadius: FamRadius.control,
        minTouchTarget: FamTouchTarget.minSize,
        minSpacing: FamTouchTarget.minSpacing,
        borderWidth: 1
    )
}
