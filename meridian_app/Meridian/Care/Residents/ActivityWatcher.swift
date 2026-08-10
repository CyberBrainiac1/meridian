import Foundation
import Supabase

/// Polls the facility activity schedule and fires a reminder as each slot
/// (meal, walk, and similar daily care activity) comes due.
///
/// Why polling rather than realtime: an activity becoming due is the passage
/// of time, not a database write. There is no row to subscribe to — the
/// `facility_activity_schedule` view derives due slots from the standing
/// schedule plus the clock, so nothing would ever be pushed. A one-minute
/// tick is the correct granularity here, same as MedicationWatcher.
@MainActor
final class ActivityWatcher: ObservableObject {
    @Published private(set) var dueActivities: [ActivitySlot] = []

    private let facilityId: String
    private var task: Task<Void, Never>?

    /// Activity ids already considered on a previous poll. Seeded on the
    /// first poll WITHOUT notifying: at launch there may be many hours of
    /// legitimately outstanding history, and firing all of them at once
    /// would bury the one activity that just came due. The in-app resident
    /// screen still shows every overdue activity — this set only governs the
    /// push, matching MedicationWatcher.
    private var seenActivityIds: Set<String> = []
    private var hasBaseline = false

    /// An activity is "reminder-worthy" from its scheduled minute until this
    /// long after. Past that it stays visible in-app as overdue but stops
    /// generating fresh pushes, so an activity nobody recorded doesn't nag
    /// all night.
    private static let reminderWindow: TimeInterval = 60 * 60

    private static let pollInterval: Duration = .seconds(60)

    init(facilityId: String) {
        self.facilityId = facilityId
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func poll() async {
        do {
            let rows: [ActivitySlot] = try await SupabaseManager.client
                .from("facility_activity_schedule")
                .select()
                .eq("facility_id", value: facilityId)
                .eq("status", value: "outstanding")
                .order("scheduled_for", ascending: true)
                .execute()
                .value

            let now = Date()
            let due = rows.filter { $0.scheduledFor <= now }
            dueActivities = due

            let withinWindow = due.filter {
                now.timeIntervalSince($0.scheduledFor) <= Self.reminderWindow
            }

            guard hasBaseline else {
                seenActivityIds = Set(due.map(\.id))
                hasBaseline = true
                return
            }

            for slot in withinWindow where !seenActivityIds.contains(slot.id) {
                AlertNotificationService.shared.notifyActivityDue(slot)
            }
            seenActivityIds.formUnion(due.map(\.id))
        } catch {
            // A failed poll is not surfaced: the resident detail screen is the
            // authoritative schedule view and reports its own errors. A
            // transient network blip here should not produce a scary banner
            // on an unrelated screen.
        }
    }
}
