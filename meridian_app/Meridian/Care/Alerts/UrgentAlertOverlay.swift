import SwiftUI

/// Full-screen interrupt for an open, non-info incident — a fall alert
/// shouldn't wait for a caregiver to happen to have the Alerts tab open.
/// Dismissing only suppresses it for this incident for the rest of the
/// session (CareRootView's `dismissedUrgentIds`); it isn't a substitute for
/// acknowledging or resolving the underlying incident.
struct UrgentAlertOverlay: View {
    let incident: IncidentEvent
    let copy: String
    let onAcknowledge: () -> Void
    let onView: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label {
                        Text(incident.severity.label)
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

                Text(incident.roomId ?? "Unknown room")
                    .font(MeridianFont.heading(30))
                    .foregroundStyle(.white)
                    .padding(.bottom, MeridianSpacing.unit)

                Text(copy)
                    .font(MeridianFont.bodyMedium(17))
                    .foregroundStyle(.white)

                Text("\(incident.eventType.label) · \(MeridianFormat.relativeTime(incident.detectedAt))")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.bottom, MeridianSpacing.lg)

                VStack(spacing: MeridianTouchTarget.minSpacing) {
                    Button(action: onAcknowledge) {
                        Text("Acknowledge").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(UrgentButtonStyle(kind: .solid))

                    Button(action: onView) {
                        Text("View alert").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(UrgentButtonStyle(kind: .outline))
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

private struct UrgentButtonStyle: ButtonStyle {
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
