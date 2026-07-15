import Foundation
import Supabase

struct ResidentDailySummary: Identifiable {
    let resident: FamilyLinkedResident
    let todayIncidents: [FamilyIncidentRow]
    let visitorCountToday: Int

    var id: String { resident.id }

    /// "Maggie had a good day" — warm, specific, never clinical. Real
    /// signals only: incident history + visitor count. Note: the PRD's
    /// "meals attended" and generic "activity level" metrics have no data
    /// source anywhere in meridian_hub today (no meal-tracking pipeline
    /// exists) — deliberately omitted rather than fabricated. Flag if
    /// that capability gets built later.
    var headline: String {
        let seriousToday = todayIncidents.contains { $0.severity != .info }
        if seriousToday {
            return "\(resident.displayName) needed some help today."
        }
        if todayIncidents.isEmpty && visitorCountToday == 0 {
            return "\(resident.displayName) had a quiet, easy day."
        }
        return "\(resident.displayName) had a good day."
    }

    var detailLine: String {
        var parts: [String] = []
        if visitorCountToday > 0 {
            parts.append("\(visitorCountToday) visitor\(visitorCountToday == 1 ? "" : "s") today")
        }
        let resolved = todayIncidents.filter { $0.status.isResolved }.count
        if resolved > 0 {
            parts.append("\(resolved) alert\(resolved == 1 ? "" : "s") handled by staff")
        }
        return parts.isEmpty ? "Nothing to report — all quiet." : parts.joined(separator: " · ")
    }
}

@MainActor
final class DailySummaryViewModel: ObservableObject {
    @Published private(set) var summaries: [ResidentDailySummary] = []
    @Published var errorMessage: String?
    private let residents: [FamilyLinkedResident]
    private var pollTask: Task<Void, Never>?

    init(residents: [FamilyLinkedResident]) {
        self.residents = residents
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task {
            while !Task.isCancelled {
                await load()
                // Family has no realtime access (RLS + Realtime-can't-
                // subscribe-to-views) — poll every 20s per
                // realtime-channels.md's guidance for this role.
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func load() async {
        do {
            let allIncidents: [FamilyIncidentRow] = try await SupabaseManager.client
                .from("family_incident_feed")
                .select()
                .order("detected_at", ascending: false)
                .execute()
                .value

            let allVisitors: [FamilyVisitorRow] = try await SupabaseManager.client
                .from("family_visitor_feed")
                .select()
                .order("detected_at", ascending: false)
                .execute()
                .value

            let calendar = Calendar.current
            let todayVisitorCount = allVisitors.filter { calendar.isDateInToday($0.detectedAt) }.count

            summaries = residents.map { resident in
                let residentIncidents = allIncidents.filter { $0.residentId == resident.residentId }
                let todayIncidents = residentIncidents.filter { calendar.isDateInToday($0.detectedAt) }
                // family_visitor_feed has no resident scoping column beyond
                // RLS (it's facility-wide for consented residents), so a
                // multi-resident family account sees one shared visitor
                // count rather than a per-resident split — matches what
                // the view actually returns.
                return ResidentDailySummary(
                    resident: resident,
                    todayIncidents: todayIncidents,
                    visitorCountToday: todayVisitorCount
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load today's summary."
        }
    }
}
