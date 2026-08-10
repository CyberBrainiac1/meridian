import Foundation
import Supabase

/// Polls the facility medication schedule and fires a reminder as each dose
/// comes due.
///
/// Why polling rather than realtime: a dose becoming due is the passage of
/// time, not a database write. There is no row to subscribe to — the
/// `facility_medication_schedule` view derives due slots from the standing
/// order plus the clock, so nothing would ever be pushed. A one-minute tick
/// is the correct granularity for a medication pass.
@MainActor
final class MedicationWatcher: ObservableObject {
    @Published private(set) var dueDoses: [MedicationDose] = []

    private let facilityId: String
    private var task: Task<Void, Never>?

    /// Dose ids already considered on a previous poll. Seeded on the first
    /// poll WITHOUT notifying: at launch there may be many hours of
    /// legitimately outstanding history, and firing all of them at once
    /// would bury the one dose that just came due. The in-app resident
    /// screen still shows every overdue dose — this set only governs the
    /// push, matching how AlertFeedViewModel diffs newly-appeared incidents.
    private var seenDoseIds: Set<String> = []
    private var hasBaseline = false

    /// A dose is "reminder-worthy" from its scheduled minute until this long
    /// after. Past that it stays visible in-app as overdue but stops
    /// generating fresh pushes, so a dose nobody recorded doesn't nag all
    /// night.
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
            let rows: [MedicationDose] = try await SupabaseManager.client
                .from("facility_medication_schedule")
                .select()
                .eq("facility_id", value: facilityId)
                .eq("status", value: "outstanding")
                .order("scheduled_for", ascending: true)
                .execute()
                .value

            let now = Date()
            let due = rows.filter { $0.scheduledFor <= now }
            dueDoses = due

            let withinWindow = due.filter {
                now.timeIntervalSince($0.scheduledFor) <= Self.reminderWindow
            }

            guard hasBaseline else {
                seenDoseIds = Set(due.map(\.id))
                hasBaseline = true
                return
            }

            for dose in withinWindow where !seenDoseIds.contains(dose.id) {
                AlertNotificationService.shared.notifyMedicationDue(dose)
            }
            seenDoseIds.formUnion(due.map(\.id))
        } catch {
            // A failed poll is not surfaced: the resident detail screen is the
            // authoritative medication view and reports its own errors. A
            // transient network blip here should not produce a scary banner
            // on an unrelated screen.
        }
    }
}
