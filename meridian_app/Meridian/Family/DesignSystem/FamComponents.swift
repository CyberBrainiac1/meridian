import SwiftUI

struct FamButtonStyle: ButtonStyle {
    enum Kind { case primary, success, secondary }
    var kind: Kind = .primary

    private var background: Color {
        switch kind {
        case .primary: return FamColor.primary
        // White text on the base success color measured 3.77:1 (below
        // the 4.5:1 minimum) — successStrong is the accessible fill.
        case .success: return FamColor.successStrong
        case .secondary: return FamColor.surface
        }
    }

    private var foreground: Color {
        kind == .secondary ? FamColor.foreground : .white
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FamFont.bodyMedium(16))
            .frame(minWidth: FamTouchTarget.minSize, minHeight: FamTouchTarget.minSize)
            .padding(.horizontal, FamSpacing.md)
            .foregroundStyle(foreground)
            .background(background.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: FamRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: FamRadius.control)
                    .stroke(kind == .secondary ? FamColor.border : .clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: FamMotion.duration), value: configuration.isPressed)
    }
}

struct FamCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(FamSpacing.md)
            .background(FamColor.surface, in: RoundedRectangle(cornerRadius: FamRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: FamRadius.card)
                    .stroke(FamColor.border, lineWidth: 1)
            )
    }
}

extension View {
    func famCard() -> some View {
        modifier(FamCardBackground())
    }
}

/// One-time pop-in on arrival for the emergency banner, then hold steady —
/// same calm/emergency motion principle as Care/Insights. Respects Reduce
/// Motion.
struct FamAlertArrival: ViewModifier {
    let trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, newValue in
                guard newValue, !reduceMotion else { return }
                scale = 0.96
                withAnimation(.easeInOut(duration: FamMotion.duration)) {
                    scale = 1
                }
            }
    }
}

extension View {
    func famAlertArrival(_ trigger: Bool) -> some View {
        modifier(FamAlertArrival(trigger: trigger))
    }
}
