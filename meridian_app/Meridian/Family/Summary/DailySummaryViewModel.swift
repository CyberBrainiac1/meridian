import Foundation
import Supabase

struct ResidentDailySummary: Identifiable {
    let resident: FamilyLinkedResident
    let todayIncidents: [FamilyIncidentRow]
    let visitorCountToday: Int
    let activityRollup: FamilyActivityRollupRow?

    var id: String { resident.id }

    /// "Maggie had a good day" — warm, specific, never clinical. Real
    /// signals only: incident history, visitor count, and a privacy-bounded
    /// comparison of observed movement in the resident's room with that
    /// room's own recent baseline. The rollup has no pose, location trace,
    /// or within-day timestamps, and it says "not enough to compare" when
    /// coverage or history is insufficient. Meals still have no data source:
    /// a skeleton camera cannot verify breakfast, so meals remain omitted.
    var headline: String {
        let seriousToday = todayIncidents.contains { $0.severity != .info }
        if seriousToday {
            return "\(resident.displayName) needed some help today."
        }
        if let activityHeadline {
            return activityHeadline
        }
        return "Here’s \(resident.displayName)’s update for today."
    }

    var detailLine: String {
        var parts: [String] = []
        if let activityDetail {
            parts.append(activityDetail)
        }
        if visitorCountToday > 0 {
            parts.append("\(visitorCountToday) visitor\(visitorCountToday == 1 ? "" : "s") today")
        }
        let resolved = todayIncidents.filter { $0.isResolved }.count
        if resolved > 0 {
            parts.append("\(resolved) alert\(resolved == 1 ? "" : "s") handled by staff")
        }
        return parts.isEmpty ? "No new updates to share." : parts.joined(separator: " · ")
    }

    private var activityHeadline: String? {
        guard let activityRollup else { return nil }
        guard activityRollup.rollupDate == Self.localDayString(for: .now) else { return nil }
        switch activityRollup.daytimePattern {
        case .usual:
            return "The movement we saw in \(resident.displayName)’s room followed its usual rhythm today."
        case .lowerThanUsual:
            return "\(resident.displayName)’s room was a little quieter than its usual rhythm today."
        case .higherThanUsual:
            return "\(resident.displayName)’s room was a little more active than usual today."
        case .notCompared, .insufficientObservation:
            return nil
        }
    }

    private var activityDetail: String? {
        guard let activityRollup else { return nil }
        let dayLabel = Self.activityDayLabel(activityRollup.rollupDate)
        if activityRollup.baselineStatus == .building {
            return "We’re getting to know the usual rhythm in \(resident.displayName)’s room (\(dayLabel.lowercased()))."
        }
        if activityRollup.observationStatus == .limited {
            return "We didn’t see enough on \(dayLabel.lowercased()) to compare the room’s movement pattern."
        }
        if activityRollup.rollupDate != Self.localDayString(for: .now) {
            switch activityRollup.daytimePattern {
            case .usual:
                return "\(dayLabel)’s room movement followed the usual pattern."
            case .lowerThanUsual:
                return "\(dayLabel)’s room movement was a little quieter than usual."
            case .higherThanUsual:
                return "\(dayLabel)’s room movement was a little more active than usual."
            case .notCompared, .insufficientObservation:
                return nil
            }
        }
        switch activityRollup.nighttimePattern {
        case .usual:
            return "Overnight movement followed its usual pattern."
        case .lowerThanUsual:
            return "Overnight movement was lower than the usual pattern."
        case .higherThanUsual:
            return "Overnight movement was higher than the usual pattern."
        case .notCompared, .insufficientObservation:
            return nil
        }
    }

    private static func localDayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func activityDayLabel(_ rollupDate: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .current
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: rollupDate) else { return "That day" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
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

            let allActivityRollups: [FamilyActivityRollupRow] = try await SupabaseManager.client
                .from("family_activity_rollup_feed")
                .select()
                .order("rollup_date", ascending: false)
                .execute()
                .value

            let calendar = Calendar.current
            let todayVisitorCount = allVisitors.filter { calendar.isDateInToday($0.detectedAt) }.count
            var latestActivityByResident: [String: FamilyActivityRollupRow] = [:]
            for rollup in allActivityRollups {
                if latestActivityByResident[rollup.residentId] == nil {
                    latestActivityByResident[rollup.residentId] = rollup
                }
            }

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
                    visitorCountToday: todayVisitorCount,
                    activityRollup: latestActivityByResident[resident.residentId]
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load today's summary."
        }
    }
}
