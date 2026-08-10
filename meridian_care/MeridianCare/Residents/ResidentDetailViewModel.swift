import Foundation
import Supabase

@MainActor
final class ResidentDetailViewModel: ObservableObject {
    /// Every scheduled dose facility_medication_schedule knows about for this
    /// resident, oldest slot first. The view is deliberately a 48-hour window
    /// (yesterday + today in facility time), not a strict calendar day: a
    /// 22:00 dose still outstanding at 03:00 is exactly the row the night
    /// caregiver most needs to see.
    @Published private(set) var doses: [MedicationDose] = []
    /// PRN standing orders — no slot, so they never appear in the schedule view.
    @Published private(set) var prnMedications: [Medication] = []
    /// Every scheduled activity (meal, walk, and similar) facility_activity_
    /// schedule knows about for this resident, oldest slot first — same
    /// 48-hour-window reasoning as `doses`.
    @Published private(set) var activitySlots: [ActivitySlot] = []
    @Published private(set) var contacts: [EmergencyContact] = []
    @Published private(set) var handoffNotes: [HandoffNote] = []
    /// Dose ids with an RPC in flight. Same guard as AlertFeedView's
    /// submittingIds — a double-tap here would post the dose twice.
    @Published private(set) var recordingDoseIds: Set<String> = []
    /// Activity ids with an RPC in flight — same guard as recordingDoseIds.
    @Published private(set) var recordingActivityIds: Set<String> = []
    @Published var errorMessage: String?
    @Published var actionError: String?

    private let client = SupabaseManager.client
    private let residentId: String

    /// `resident_id` is `people.id` everywhere in this schema — the value
    /// ResidentProfile carries as `personId`, not the profile row's own uuid.
    init(residentId: String) {
        self.residentId = residentId
    }

    func load() async {
        // The medication chart is fetched on its own so a failure reading
        // contacts or handoff notes can't blank out the MAR — the one thing
        // on this screen a caregiver cannot safely guess at.
        do {
            doses = try await client
                .from("facility_medication_schedule")
                .select()
                .eq("resident_id", value: residentId)
                .order("scheduled_for", ascending: true)
                .execute()
                .value

            prnMedications = try await client
                .from("resident_medications")
                .select()
                .eq("resident_id", value: residentId)
                .eq("is_prn", value: true)
                .eq("active", value: true)
                .order("medication_name", ascending: true)
                .execute()
                .value

            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load this resident's medications. Pull to retry."
        }

        // Fetched on its own, same reasoning as the medication chart above:
        // a failure here shouldn't blank out the MAR, and a failure in the
        // MAR shouldn't blank out today's schedule.
        do {
            activitySlots = try await client
                .from("facility_activity_schedule")
                .select()
                .eq("resident_id", value: residentId)
                .order("scheduled_for", ascending: true)
                .execute()
                .value
        } catch {
            if errorMessage == nil {
                errorMessage = "Couldn't load today's schedule. Pull to retry."
            }
        }

        do {
            contacts = try await client
                .from("resident_emergency_contacts")
                .select()
                .eq("resident_id", value: residentId)
                .order("is_primary", ascending: false)
                .order("display_name", ascending: true)
                .execute()
                .value

            handoffNotes = try await client
                .from("handoff_notes")
                .select()
                .eq("resident_id", value: residentId)
                .order("created_at", ascending: false)
                .limit(5)
                .execute()
                .value
        } catch {
            // Non-fatal: the safety banner, care notes and medication chart
            // all still render. Only surface an error if nothing else did.
            if errorMessage == nil {
                errorMessage = "Couldn't load contacts and handoff notes. Pull to retry."
            }
        }
    }

    func isRecording(_ dose: MedicationDose) -> Bool {
        recordingDoseIds.contains(dose.id)
    }

    /// Writes through MedicationActionService (the single write path for the
    /// MAR) and re-reads the chart, so the row's status comes back from the
    /// database rather than being optimistically assumed here.
    func record(_ dose: MedicationDose, as status: MedicationDoseStatus) async {
        guard !recordingDoseIds.contains(dose.id) else { return }
        recordingDoseIds.insert(dose.id)
        defer { recordingDoseIds.remove(dose.id) }

        actionError = nil
        let result = await MedicationActionService.record(
            medicationId: dose.medicationId,
            scheduledFor: dose.scheduledFor,
            status: status,
            note: nil
        )
        switch result {
        case .success:
            await load()
        case .failure(let error):
            actionError = error.errorDescription
        }
    }

    func isRecording(_ slot: ActivitySlot) -> Bool {
        recordingActivityIds.contains(slot.id)
    }

    /// Writes through ActivityActionService (the single write path for the
    /// schedule) and re-reads it, so the row's status comes back from the
    /// database rather than being optimistically assumed here.
    func record(_ slot: ActivitySlot, as status: ActivityCompletionStatus) async {
        guard !recordingActivityIds.contains(slot.id) else { return }
        recordingActivityIds.insert(slot.id)
        defer { recordingActivityIds.remove(slot.id) }

        actionError = nil
        let result = await ActivityActionService.record(
            activityId: slot.activityId,
            scheduledFor: slot.scheduledFor,
            status: status,
            note: nil
        )
        switch result {
        case .success:
            await load()
        case .failure(let error):
            actionError = error.errorDescription
        }
    }
}
