import Foundation
import Supabase

@MainActor
final class AlertFeedViewModel: ObservableObject {
    @Published private(set) var incidents: [IncidentEvent] = []
    @Published private(set) var residents: [String: ResidentProfile] = [:]
    @Published private(set) var isConnected = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.client
    private let facilityId: String
    private var watchTask: Task<Void, Never>?

    init(facilityId: String) {
        self.facilityId = facilityId
    }

    func start() {
        guard watchTask == nil else { return }
        watchTask = Task {
            await loadResidents()
            await refresh()
            await watchRealtime()
        }
    }

    func stop() {
        watchTask?.cancel()
        watchTask = nil
    }

    /// Resident-first copy: prefer the incident's own `summary` (the seed
    /// data already writes it as "Maggie needs help in Room 101"), fall
    /// back to composing name + room from resident_profiles. Never shows a
    /// raw event ID — that's the PRD's hard content rule for this app.
    func copy(for incident: IncidentEvent) -> String {
        if let summary = incident.summary, !summary.isEmpty { return summary }
        let name = incident.residentId.flatMap { residents[$0]?.displayName } ?? "A resident"
        let room = incident.roomId ?? residents[incident.residentId ?? ""]?.roomId
        if let room {
            return "\(name) needs attention in \(room)"
        }
        return "\(name) needs attention"
    }

    private func loadResidents() async {
        do {
            let rows: [ResidentProfile] = try await client
                .from("resident_profiles")
                .select()
                .eq("facility_id", value: facilityId)
                .execute()
                .value
            residents = Dictionary(uniqueKeysWithValues: rows.map { ($0.personId, $0) })
        } catch {
            // Non-fatal — copy(for:) falls back to "A resident" without a name.
        }
    }

    private func refresh() async {
        do {
            let rows: [IncidentEvent] = try await client
                .from("incident_events")
                .select()
                .eq("facility_id", value: facilityId)
                .in("status", values: ["open", "acknowledged", "responding"])
                .order("detected_at", ascending: false)
                .execute()
                .value
            incidents = rows
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load alerts. Pull to retry."
        }
    }

    private func watchRealtime() async {
        let channel = client.channel("incident-events-\(facilityId)")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "incident_events",
            filter: .eq("facility_id", value: facilityId)
        )
        await channel.subscribe()
        isConnected = true

        for await _ in changes {
            await refresh()
        }
    }

    func manualRefresh() async {
        await refresh()
    }
}
