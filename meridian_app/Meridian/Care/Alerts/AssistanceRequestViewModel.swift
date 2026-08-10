import Foundation
import Supabase

/// Watches public.assistance_requests — a resident-initiated (or
/// auto-fall-dispatch) call for help, kept as its own feed rather than
/// merged into AlertFeedViewModel's incident feed so "AI flagged a possible
/// fall" and "resident pressed Emergency" stay honestly distinguishable.
/// Structure deliberately mirrors AlertFeedViewModel: same realtime +
/// bounded-backoff reconnect pattern, same "always refresh() on every
/// successful (re)join" reasoning (Postgres Changes has no replay), same
/// unsubscribe+removeChannel on stop() to avoid a stale topic on restart.
@MainActor
final class AssistanceRequestViewModel: ObservableObject {
    @Published private(set) var requests: [AssistanceRequest] = []
    @Published private(set) var residents: [String: ResidentProfile] = [:]
    @Published private(set) var isConnected = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.client
    private let facilityId: String
    private var watchTask: Task<Void, Never>?
    private var channel: RealtimeChannelV2?

    /// Bounded backoff between re-join attempts, held at 30s rather than
    /// growing without limit — same reasoning as AlertFeedViewModel: a
    /// caregiver waiting on an emergency press can't be parked behind a
    /// minutes-long retry interval.
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

    /// Resident-first copy, matching AlertFeedViewModel.copy(for:)'s tone:
    /// "Maggie Alvarez needs help in Room 101". Falls back gracefully if the
    /// resident profile hasn't loaded yet.
    func copy(for request: AssistanceRequest) -> String {
        let name = residentName(for: request)
        let room = residents[request.residentId]?.roomId ?? request.roomId
        let verb: String
        switch request.requestKind {
        case .emergency: verb = "needs emergency help"
        case .familyContact: verb = "is requesting a family call"
        case .assistance: verb = "needs help"
        }
        return "\(name) \(verb) in \(room)"
    }

    /// Plain resident display name, for surfaces (like UrgentAssistanceOverlay)
    /// that render the resident and the request context as separate pieces
    /// of UI rather than one composed sentence. Same fallback as copy(for:).
    func residentName(for request: AssistanceRequest) -> String {
        residents[request.residentId]?.displayName ?? "A resident"
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
            // Non-fatal — copy(for:)/residentName(for:) fall back to "A resident".
        }
    }

    private func refresh() async {
        do {
            let rows: [AssistanceRequest] = try await client
                .from("assistance_requests")
                .select()
                .eq("facility_id", value: facilityId)
                .in("status", values: ["open", "acknowledged", "en_route"])
                .order("requested_at", ascending: false)
                .execute()
                .value

            // Diffed against the ids already on screen, not against
            // AlertNotificationService's own dedupe set, so this stays
            // correct even on the very first refresh after launch — same
            // technique as AlertFeedViewModel.refresh().
            let previouslySeenIds = Set(requests.map(\.id))
            let newlyAppeared = rows.filter {
                !previouslySeenIds.contains($0.id) && $0.status == .open
            }

            requests = rows
            errorMessage = nil

            for request in newlyAppeared {
                AlertNotificationService.shared.notifyAssistanceRequest(request, copy: copy(for: request))
            }
        } catch {
            errorMessage = "Couldn't load assistance requests. Pull to retry."
        }
    }

    private func watchRealtime() async {
        let channel = client.channel("assistance-requests-\(facilityId)")
        self.channel = channel
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "assistance_requests",
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
    /// Same reasoning as AlertFeedViewModel.keepSubscribed(_:): Postgres
    /// Changes has no replay, so a request raised while this device was
    /// offline is only recovered by a full fetch on every successful
    /// (re)join, and a join that fails outright leaves the channel
    /// `.unsubscribed` with nothing retrying it without this loop.
    private func keepSubscribed(_ channel: RealtimeChannelV2) async {
        var attempt = 0

        while !Task.isCancelled {
            do {
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
