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
    private var channel: RealtimeChannelV2?

    /// Bounded backoff between re-join attempts, held at 30s rather than
    /// growing without limit — a caregiver waiting on a fall alert can't be
    /// parked behind a minutes-long retry interval.
    private static let retryDelays: [Duration] = [
        .seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(15), .seconds(30)
    ]

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
        isConnected = false

        // Cancelling the task on its own leaves the channel joined and still
        // registered on the socket, so the next start() would hand back that
        // same stale topic instead of a fresh join.
        if let channel {
            self.channel = nil
            Task { [client] in
                await channel.unsubscribe()
                await client.removeChannel(channel)
            }
        }
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

            // Same trigger condition as CareRootView's urgentIncident: open and
            // above info severity. Diffed against the ids already on screen,
            // not against AlertNotificationService's own dedupe set, so this
            // stays correct even on the very first refresh after launch —
            // nothing "already on screen" counts as newly appeared.
            let previouslySeenIds = Set(incidents.map(\.id))
            let newlyAppeared = rows.filter {
                !previouslySeenIds.contains($0.id) && $0.status == .open && $0.severity != .info
            }

            incidents = rows
            errorMessage = nil

            for incident in newlyAppeared {
                AlertNotificationService.shared.notify(for: incident, copy: copy(for: incident))
            }
        } catch {
            errorMessage = "Couldn't load alerts. Pull to retry."
        }
    }

    private func watchRealtime() async {
        let channel = client.channel("incident-events-\(facilityId)")
        self.channel = channel
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "incident_events",
            filter: .eq("facility_id", value: facilityId)
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await _ in changes {
                    await self?.refresh()
                }
            }
            group.addTask { [weak self] in
                await self?.keepSubscribed(channel)
            }
            await group.waitForAll()
        }
    }

    /// Keeps the channel joined, and re-reads the feed every time it lands.
    ///
    /// Postgres Changes has no replay: an incident raised while this device
    /// was offline is never delivered once the socket comes back, so it would
    /// stay invisible until some later unrelated write happened to fire a
    /// refresh. A full fetch on every successful (re)join is the only thing
    /// that closes that gap. supabase-swift re-joins on its own after a socket
    /// reconnect, but a join that fails outright leaves the channel
    /// `.unsubscribed` with nothing retrying it — hence the backoff here.
    private func keepSubscribed(_ channel: RealtimeChannelV2) async {
        var attempt = 0

        while !Task.isCancelled {
            do {
                // No-op when the channel is already subscribed, and coalesces
                // with the library's own reconnect-driven join.
                try await channel.subscribeWithError()
            } catch {
                isConnected = false
                let delay = Self.retryDelays[min(attempt, Self.retryDelays.count - 1)]
                attempt += 1
                try? await Task.sleep(for: delay)
                continue
            }

            attempt = 0
            isConnected = true
            await refresh()

            // Park until the join is lost — a dropped socket, a server-side
            // close, and the library's own reconnect reset all leave
            // `.subscribed`.
            for await status in channel.statusChange where status != .subscribed {
                break
            }
            guard !Task.isCancelled else { break }
            isConnected = false
        }

        isConnected = false
    }

    func manualRefresh() async {
        await refresh()
    }
}
