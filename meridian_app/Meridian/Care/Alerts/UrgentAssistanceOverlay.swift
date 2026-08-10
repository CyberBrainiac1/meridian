import SwiftUI

/// Full-screen interrupt for an open `.emergency`-kind assistance request —
/// a resident pressing Emergency on their Hub device is genuinely as urgent
/// as a detected fall, so this gets the same klaxon-tier visual treatment as
/// UrgentAlertOverlay. Kept as a sibling component rather than extending
/// UrgentAlertOverlay directly: that file's init and behavior are specific
/// to IncidentEvent and already proven working, and shouldn't be touched.
///
/// Dismissing only suppresses it for this request for the rest of the
/// session (CareRootView's `dismissedUrgentAssistanceIds`); it isn't a
/// substitute for acknowledging or resolving the underlying request.
struct UrgentAssistanceOverlay: View {
    let request: AssistanceRequest
    let residentName: String
    let onAcknowledge: () -> Void
    let onView: () -> Void
    let onClose: () -> Void

    private var kindDescription: String {
        switch request.requestKind {
        case .emergency: return "Emergency help requested"
        case .assistance: return "Assistance requested"
        case .familyContact: return "Family contact requested"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label {
                        Text(request.requestKind.label)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .textCase(.uppercase)

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(minWidth: MeridianTouchTarget.minSize, minHeight: MeridianTouchTarget.minSize)
                    .accessibilityLabel("Dismiss")
                }
                .padding(.bottom, MeridianSpacing.sm)

                Text("\(residentName) · \(request.roomId)")
                    .font(MeridianFont.heading(30))
                    .foregroundStyle(.white)
                    .padding(.bottom, MeridianSpacing.unit)

                Text(kindDescription)
                    .font(MeridianFont.bodyMedium(17))
                    .foregroundStyle(.white)

                Text(MeridianFormat.relativeTime(request.requestedAt))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.bottom, MeridianSpacing.lg)

                VStack(spacing: MeridianTouchTarget.minSpacing) {
                    Button(action: onAcknowledge) {
                        Text("Acknowledge").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(UrgentAssistanceButtonStyle(kind: .solid))

                    Button(action: onView) {
                        Text("View").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(UrgentAssistanceButtonStyle(kind: .outline))
                }
            }
            .padding(MeridianSpacing.lg)
            .background(MeridianColor.destructive, in: RoundedRectangle(cornerRadius: MeridianRadius.card))
            .padding(MeridianSpacing.lg)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

/// Equivalent of UrgentAlertOverlay's UrgentButtonStyle, recreated here
/// rather than shared: that type is file-private to UrgentAlertOverlay.swift.
private struct UrgentAssistanceButtonStyle: ButtonStyle {
    enum Kind { case solid, outline }
    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MeridianFont.bodyMedium(16))
            .frame(minHeight: MeridianTouchTarget.minSize)
            .foregroundStyle(kind == .solid ? MeridianColor.destructiveStrong : .white)
            .background(
                kind == .solid
                    ? Color.white.opacity(configuration.isPressed ? 0.85 : 1)
                    : Color.white.opacity(configuration.isPressed ? 0.24 : 0.14),
                in: RoundedRectangle(cornerRadius: MeridianRadius.control)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MeridianRadius.control)
                    .stroke(kind == .outline ? Color.white.opacity(0.6) : .clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: MeridianMotion.duration), value: configuration.isPressed)
    }
}
