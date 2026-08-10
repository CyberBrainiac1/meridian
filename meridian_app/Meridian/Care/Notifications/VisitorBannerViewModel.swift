import Foundation
import Supabase

/// "Someone just walked in" — surfaced like an alert, not buried in a log
/// (api-contract.md: new-visitor push/banner). Same notifications table as
/// Insights' audit-trail banner, filtered client-side to resident_id is
/// null per that doc.
///
/// Lifecycle deliberately mirrors AlertFeedViewModel: initial fetch before
/// watching, a full re-fetch on every successful (re)join, bounded backoff
/// on a failed join, and unsubscribe + removeChannel on stop(). Postgres
/// Changes has no replay, so without the fetch a notification that landed
/// before this app opened (or while the socket was down) would never be
/// seen at all.
@MainActor
final class VisitorBannerViewModel: ObservableObject {
    @Published var latest: CareNotificationRow?
    @Published private(set) var isConnected = false
    private var dismissedId: String?
    private let client = SupabaseManager.client
    private let facilityId: String
    private var watchTask: Task<Void, Never>?
    private var channel: RealtimeChannelV2?

    /// Bounded backoff between re-join attempts, held at 30s rather than
    /// growing without limit — same table and same reasoning as
    /// AlertFeedViewModel.
    private static let retryDelays: [Duration] = [
        .seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(15), .seconds(30)
    ]

    init(facilityId: String) {
        self.facilityId = facilityId
    }

    var isVisible: Bool { latest != nil && latest?.id != dismissedId }

    func start() {
        guard watchTask == nil else { return }
        watchTask = Task {
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

    func dismiss() {
        dismissedId = latest?.id
    }

    /// Newest facility-wide notification (resident_id is null — the same
    /// condition the realtime handler applies client-side). Only one row is
    /// needed: the banner shows one notification at a time, and an older
    /// row can never displace what is already on screen.
    private func refresh() async {
        do {
            let rows: [CareNotificationRow] = try await client
                .from("notifications")
                .select()
                .eq("facility_id", value: facilityId)
                .is("resident_id", value: nil)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let row = rows.first else { return }
            // Never step on a fresher realtime insert that arrived while this
            // fetch was in flight, and never resurrect a banner the caregiver
            // already dismissed (dismissedId still matches the same row id).
            if let current = latest, row.createdAt <= current.createdAt { return }
            latest = row
        } catch {
            // Non-fatal, and deliberately silent: the banner is an ambient
            // courtesy, not an alert path. Realtime inserts still populate it,
            // and the next successful (re)join re-runs this fetch.
        }
    }

    private func watchRealtime() async {
        let channel = client.channel("notifications-\(facilityId)")
        self.channel = channel
        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications",
            filter: .eq("facility_id", value: facilityId)
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await insert in inserts {
                    guard let row = try? insert.decodeRecord(as: CareNotificationRow.self, decoder: AnyJSON.decoder)
                    else { continue }
                    await self?.receive(row)
                }
            }
            group.addTask { [weak self] in
                await self?.keepSubscribed(channel)
            }
            await group.waitForAll()
        }
    }

    private func receive(_ row: CareNotificationRow) {
        // Facility-wide rows only: a notification carrying a resident_id is
        // that family's message, not a care-team banner.
        guard row.residentId == nil else { return }
        latest = row
    }

    /// Keeps the channel joined, and re-reads the newest notification every
    /// time it lands. Same reasoning as AlertFeedViewModel.keepSubscribed(_:):
    /// `subscribe()` cannot report a failed join, so a channel that never
    /// joins would sit `.unsubscribed` forever with nothing retrying it and
    /// no error anywhere — which is exactly how this banner went silent.
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
}
