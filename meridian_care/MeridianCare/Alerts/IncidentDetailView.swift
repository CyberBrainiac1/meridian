import SwiftUI

struct IncidentDetailView: View {
    let incident: IncidentEvent
    let copy: String
    let onUpdated: () async -> Void

    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeridianSpacing.md) {
                VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
                    SeverityBadge(severity: incident.severity)
                    Text(copy)
                        .font(MeridianFont.heading(22))
                        .foregroundStyle(MeridianColor.foreground)
                    Text("\(incident.eventType.label) · \(MeridianFormat.relativeTime(incident.detectedAt))")
                        .font(.footnote)
                        .foregroundStyle(MeridianColor.foregroundMuted)
                }

                if let resolutionNote = incident.resolutionNote {
                    VStack(alignment: .leading, spacing: MeridianSpacing.unit) {
                        Text("Resolution note").font(.footnote.weight(.semibold))
                        Text(resolutionNote).font(MeridianFont.body(15))
                    }
                    .meridianCard()
                }

                if incident.status.nextStatuses.isEmpty {
                    HStack(spacing: MeridianSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(MeridianColor.success)
                        Text("This alert is closed.").font(MeridianFont.body(15))
                    }
                    .meridianCard()
                } else {
                    VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                        Text("Note (optional)").font(.footnote.weight(.semibold))
                        TextField("e.g. Assisted back to bed, no injury.", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(MeridianSpacing.sm)
                            .frame(minHeight: MeridianTouchTarget.minSize)
                            .background(MeridianColor.background, in: RoundedRectangle(cornerRadius: MeridianRadius.control))
                            .overlay(RoundedRectangle(cornerRadius: MeridianRadius.control).stroke(MeridianColor.border))

                        // Buttons stacked with full-width min-height targets
                        // and generous spacing — a mis-tap here during a
                        // real emergency is the failure mode to design
                        // against, not a cosmetic detail.
                        VStack(spacing: MeridianTouchTarget.minSpacing) {
                            ForEach(incident.status.nextStatuses, id: \.self) { status in
                                Button {
                                    Task { await respond(status) }
                                } label: {
                                    HStack {
                                        Text(actionLabel(status))
                                        Spacer()
                                        if isSubmitting { ProgressView().tint(buttonKind(status) == .secondary ? MeridianColor.foreground : .white) }
                                    }
                                }
                                .buttonStyle(MeridianButtonStyle(kind: buttonKind(status)))
                                .disabled(isSubmitting)
                            }
                        }
                    }
                    .meridianCard()
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(MeridianColor.destructive)
                }
                if didSucceed {
                    Label("Updated.", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(MeridianColor.success)
                }
            }
            .padding(MeridianSpacing.md)
        }
        .background(MeridianColor.background)
        .navigationTitle("Alert")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func actionLabel(_ status: IncidentStatus) -> String {
        switch status {
        case .acknowledged: return "Acknowledge"
        case .responding: return "Mark responding"
        case .resolved: return "Resolve"
        case .dismissedFalseAlarm: return "Dismiss as false alarm"
        case .escalated: return "Escalate"
        default: return status.label
        }
    }

    private func buttonKind(_ status: IncidentStatus) -> MeridianButtonStyle.Kind {
        switch status {
        case .resolved: return .success
        case .escalated: return .destructive
        default: return .secondary
        }
    }

    private func respond(_ status: IncidentStatus) async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let result = await IncidentActionService.respond(incidentId: incident.id, newStatus: status, note: note)
        switch result {
        case .success:
            didSucceed = true
            await onUpdated()
        case .failure(let error):
            errorMessage = error.errorDescription
        }
    }
}
