import Foundation
import Supabase

/// "Someone just walked in" — surfaced like an alert, not buried in a log
/// (api-contract.md: new-visitor push/banner). Same notifications table as
/// Insights' audit-trail banner, filtered client-side to resident_id is
/// null per that doc.
@MainActor
final class VisitorBannerViewModel: ObservableObject {
    @Published var latest: NotificationRow?
    private var dismissedId: String?
    private let client = SupabaseManager.client
    private let facilityId: String
    private var watchTask: Task<Void, Never>?

    init(facilityId: String) {
        self.facilityId = facilityId
    }

    var isVisible: Bool { latest != nil && latest?.id != dismissedId }

    func start() {
        guard watchTask == nil else { return }
        watchTask = Task {
            let channel = client.channel("notifications-\(facilityId)")
            let inserts = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "notifications",
                filter: .eq("facility_id", value: facilityId)
            )
            await channel.subscribe()

            for await insert in inserts {
                guard let row = try? insert.decodeRecord(as: NotificationRow.self, decoder: AnyJSON.decoder)
                else { continue }
                if row.residentId == nil {
                    latest = row
                }
            }
        }
    }

    func stop() {
        watchTask?.cancel()
        watchTask = nil
    }

    func dismiss() {
        dismissedId = latest?.id
    }
}
