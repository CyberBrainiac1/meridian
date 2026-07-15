import Foundation
import Supabase

struct HandoffLine: Identifiable {
    let id: String
    let copy: String
    let severity: IncidentSeverity
    let status: IncidentStatus
    let detectedAt: Date
}

@MainActor
final class ShiftHandoffViewModel: ObservableObject {
    @Published private(set) var lines: [HandoffLine] = []
    @Published private(set) var openCount = 0
    @Published private(set) var resolvedCount = 0
    @Published var errorMessage: String?
    private let facilityId: String

    init(facilityId: String) {
        self.facilityId = facilityId
    }

    /// "Auto-generated summary of the last 8 hours, readable in under 30
    /// seconds" — built from incident_events (care-team readable directly)
    /// rather than a new summary endpoint. Not an LLM-generated summary,
    /// a structured readout: this is the smallest reasonable reading of
    /// "auto-generated" that's honest about what's real data vs. synthesis.
    func load() async {
        do {
            let since = Calendar.current.date(byAdding: .hour, value: -8, to: Date()) ?? Date()
            let incidents: [IncidentEvent] = try await SupabaseManager.client
                .from("incident_events")
                .select()
                .eq("facility_id", value: facilityId)
                .gte("detected_at", value: ISO8601DateFormatter().string(from: since))
                .order("detected_at", ascending: false)
                .execute()
                .value

            let residents: [ResidentProfile] = try await SupabaseManager.client
                .from("resident_profiles")
                .select()
                .eq("facility_id", value: facilityId)
                .execute()
                .value
            let residentsById = Dictionary(uniqueKeysWithValues: residents.map { ($0.personId, $0) })

            lines = incidents.map { incident in
                let copy: String
                if let summary = incident.summary, !summary.isEmpty {
                    copy = summary
                } else {
                    let name = incident.residentId.flatMap { residentsById[$0]?.displayName } ?? "A resident"
                    copy = "\(name): \(incident.eventType.label.lowercased())"
                }
                return HandoffLine(
                    id: incident.id,
                    copy: copy,
                    severity: incident.severity,
                    status: incident.status,
                    detectedAt: incident.detectedAt
                )
            }
            openCount = incidents.filter { !["resolved", "dismissed_false_alarm"].contains($0.status.rawValue) }.count
            resolvedCount = incidents.count - openCount
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load the shift summary."
        }
    }

    var headline: String {
        if lines.isEmpty { return "Quiet shift — no alerts in the last 8 hours." }
        var parts = ["\(lines.count) alert\(lines.count == 1 ? "" : "s") in the last 8 hours."]
        if resolvedCount > 0 { parts.append("\(resolvedCount) resolved.") }
        if openCount > 0 { parts.append("\(openCount) still open.") }
        return parts.joined(separator: " ")
    }
}
