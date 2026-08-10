import Foundation
import Supabase

struct HandoffLine: Identifiable {
    let id: String
    let copy: String
    let severity: CareIncidentSeverity
    let status: CareIncidentStatus
    let detectedAt: Date
}

@MainActor
final class ShiftHandoffViewModel: ObservableObject {
    @Published private(set) var lines: [HandoffLine] = []
    @Published private(set) var openCount = 0
    @Published private(set) var resolvedCount = 0
    @Published private(set) var shifts: [CaregiverShift] = []
    @Published private(set) var notes: [HandoffNote] = []
    @Published private(set) var residentsById: [String: ResidentProfile] = [:]
    /// Note ids with an acknowledge RPC in flight. A double-tap on a 44pt
    /// button is a normal occurrence for a caregiver working one-handed, and
    /// two overlapping calls would race the refresh that follows each one.
    @Published private(set) var acknowledging: Set<String> = []
    @Published var errorMessage: String?
    private let facilityId: String

    init(facilityId: String) {
        self.facilityId = facilityId
    }

    func load() async {
        await loadResidents()
        let boardLoaded = await loadHandoffBoard()
        let summaryLoaded = await loadIncidentSummary()

        switch (boardLoaded, summaryLoaded) {
        case (true, true): errorMessage = nil
        case (false, true): errorMessage = "Couldn't load the handoff board. Pull to retry."
        case (true, false): errorMessage = "Couldn't load the shift summary. Pull to retry."
        case (false, false): errorMessage = "Couldn't load the handoff. Pull to retry."
        }
    }

    /// The caregiver currently covering the floor, and whoever takes it next.
    /// `caregiver_shifts` comes back ordered by starts_at, so "next" is simply
    /// the first row that has not begun yet.
    var onNow: CaregiverShift? {
        shifts.first(where: \.isOnNow)
    }

    var onNext: CaregiverShift? {
        let now = Date()
        return shifts.first { $0.startsAt > now }
    }

    /// Newest first, with urgent notes lifted above everything else — an
    /// urgent note written four hours ago still outranks a routine one written
    /// four minutes ago.
    var sortedNotes: [HandoffNote] {
        notes.sorted { lhs, rhs in
            let lhsUrgent = lhs.priority == .urgent
            let rhsUrgent = rhs.priority == .urgent
            if lhsUrgent != rhsUrgent { return lhsUrgent }
            return lhs.createdAt > rhs.createdAt
        }
    }

    /// "Maggie Doyle · Room 101", or "Facility-wide" for a note with no
    /// resident. Never a raw id — the same content rule the alert feed follows.
    func residentLabel(for note: HandoffNote) -> String {
        guard let residentId = note.residentId else { return "Facility-wide" }
        guard let resident = residentsById[residentId] else { return "A resident" }
        guard let room = resident.roomId else { return resident.displayName }
        return "\(resident.displayName) · \(room)"
    }

    func acknowledge(noteId: String) async {
        guard !acknowledging.contains(noteId) else { return }
        acknowledging.insert(noteId)
        defer { acknowledging.remove(noteId) }

        switch await HandoffActionService.acknowledge(noteId: noteId) {
        case .success:
            // Re-read rather than patching the row locally: acknowledged_at is
            // set server-side, and the board is shared with everyone else on
            // shift.
            await load()
        case .failure(let error):
            errorMessage = error.errorDescription
        }
    }

    private func loadResidents() async {
        do {
            let rows: [ResidentProfile] = try await SupabaseManager.client
                .from("resident_profiles")
                .select()
                .eq("facility_id", value: facilityId)
                .execute()
                .value

            // Indexed under both keys: incident_events.resident_id references
            // the person, while a profile row carries its own id, and a handoff
            // note can legitimately have been written against either. Falling
            // back to "A resident" would be a worse failure than one extra
            // dictionary entry per resident.
            var byId: [String: ResidentProfile] = [:]
            for resident in rows {
                byId[resident.personId] = resident
                byId[resident.id] = resident
            }
            residentsById = byId
        } catch {
            // Non-fatal — residentLabel(for:) degrades to "A resident".
        }
    }

    /// Shifts and notes are both RLS-scoped to the caller's facility and expose
    /// no facility_id column of their own, so neither is filtered client-side.
    private func loadHandoffBoard() async -> Bool {
        do {
            let shiftRows: [CaregiverShift] = try await SupabaseManager.client
                .from("caregiver_shifts")
                .select()
                .order("starts_at", ascending: true)
                .execute()
                .value

            let noteRows: [HandoffNote] = try await SupabaseManager.client
                .from("handoff_notes")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            shifts = shiftRows
            notes = noteRows
            return true
        } catch {
            return false
        }
    }

    /// "Auto-generated summary of the last 8 hours, readable in under 30
    /// seconds" — built from incident_events (care-team readable directly)
    /// rather than a new summary endpoint. Not an LLM-generated summary,
    /// a structured readout: this is the smallest reasonable reading of
    /// "auto-generated" that's honest about what's real data vs. synthesis.
    private func loadIncidentSummary() async -> Bool {
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
            return true
        } catch {
            return false
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
