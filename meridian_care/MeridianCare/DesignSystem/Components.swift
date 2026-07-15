import SwiftUI

struct SeverityBadge: View {
    let severity: IncidentSeverity

    /// Background tint uses the base severity color; text uses the
    /// *Strong variant. The base color as both text and its own 12% tint
    /// background measured 3.25-4.39:1 (below the 4.5:1 minimum) for
    /// warning/critical — see Tokens.swift's accessibility-pass note.
    private var tintColor: Color {
        switch severity {
        case .info: return MeridianColor.primary
        case .warning: return MeridianColor.warning
        case .critical: return MeridianColor.destructive
        }
    }

    private var textColor: Color {
        switch severity {
        case .info: return MeridianColor.primary
        case .warning: return MeridianColor.warningStrong
        case .critical: return MeridianColor.destructiveStrong
        }
    }

    private var systemImage: String {
        switch severity {
        case .info: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    var body: some View {
        Label(severity.label, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tintColor.opacity(0.12), in: Capsule())
            .accessibilityLabel(severity.label)
    }
}

/// Primary action button — meets the 44pt minimum touch target everywhere
/// it's used (critical for one-handed, in-a-hurry use per the Care spec).
struct MeridianButtonStyle: ButtonStyle {
    enum Kind {
        case primary, destructive, success, secondary
    }

    var kind: Kind = .primary

    private var background: Color {
        switch kind {
        case .primary: return MeridianColor.primary
        case .destructive: return MeridianColor.destructive
        // White text on the base success color measured 3.77:1 (below
        // the 4.5:1 minimum) — successStrong is the accessible fill.
        case .success: return MeridianColor.successStrong
        case .secondary: return MeridianColor.surface
        }
    }

    private var foreground: Color {
        kind == .secondary ? MeridianColor.foreground : .white
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MeridianFont.bodyMedium(16))
            .frame(minWidth: MeridianTouchTarget.minSize, minHeight: MeridianTouchTarget.minSize)
            .padding(.horizontal, MeridianSpacing.md)
            .foregroundStyle(foreground)
            .background(background.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: MeridianRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: MeridianRadius.control)
                    .stroke(kind == .secondary ? MeridianColor.border : .clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: MeridianMotion.duration), value: configuration.isPressed)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(MeridianSpacing.md)
            .background(MeridianColor.surface, in: RoundedRectangle(cornerRadius: MeridianRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: MeridianRadius.card)
                    .stroke(MeridianColor.border, lineWidth: 1)
            )
    }
}

extension View {
    func meridianCard() -> some View {
        modifier(CardBackground())
    }
}

/// One-time pop-in on arrival, then hold steady — the calm/emergency
/// two-state motion principle. Never a repeating pulse. Respects Reduce
/// Motion automatically via the environment check inside.
struct AlertArrival: ViewModifier {
    let trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, newValue in
                guard newValue, !reduceMotion else { return }
                scale = 0.96
                withAnimation(.easeInOut(duration: MeridianMotion.duration)) {
                    scale = 1
                }
            }
    }
}

extension View {
    func alertArrival(_ trigger: Bool) -> some View {
        modifier(AlertArrival(trigger: trigger))
    }
}
