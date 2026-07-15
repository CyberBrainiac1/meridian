import SwiftUI

struct MeridianButtonStyle: ButtonStyle {
    enum Kind { case primary, success, secondary }
    var kind: Kind = .primary

    private var background: Color {
        switch kind {
        case .primary: return MeridianColor.primary
        case .success: return MeridianColor.success
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

/// One-time pop-in on arrival for the emergency banner, then hold steady —
/// same calm/emergency motion principle as Care/Insights. Respects Reduce
/// Motion.
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
