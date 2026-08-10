import SwiftUI

struct IncidentRow: View {
    let incident: IncidentEvent
    let copy: String

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.unit * 1.5) {
            HStack {
                SeverityBadge(severity: incident.severity)
                Spacer()
                Text(MeridianFormat.relativeTime(incident.detectedAt))
                    .font(.footnote)
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }
            Text(copy)
                .font(MeridianFont.bodyMedium(17))
                .foregroundStyle(MeridianColor.foreground)
            Text(incident.status.label)
                .font(.footnote)
                .foregroundStyle(MeridianColor.foregroundMuted)
        }
        .padding(.vertical, MeridianSpacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(incident.severity.label). \(copy). \(incident.status.label). \(MeridianFormat.relativeTime(incident.detectedAt))")
    }
}
