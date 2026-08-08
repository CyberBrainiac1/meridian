import Foundation

/// Models for the resident care detail, medication schedule, and structured
/// shift handoff added in
/// supabase/migrations/…_resident_care_detail_medications_handoff.
///
/// Kept in a separate file from Types.swift purely to keep that file's
/// incident-centric models readable — same conventions, same snake_case
/// CodingKeys mapping.

/// public.resident_medications — a standing order, not a dose.
struct Medication: Codable, Identifiable, Equatable {
    let id: String
    let residentId: String
    let medicationName: String
    let dose: String
    let route: String
    let scheduleTimes: [String]
    let instructions: String?
    let isPrn: Bool
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case residentId = "resident_id"
        case medicationName = "medication_name"
        case dose, route
        case scheduleTimes = "schedule_times"
        case instructions
        case isPrn = "is_prn"
        case active
    }
}

enum MedicationDoseStatus: String, Codable {
    case outstanding, given, refused, held, missed

    var label: String {
        switch self {
        case .outstanding: return "Due"
        case .given: return "Given"
        case .refused: return "Refused"
        case .held: return "Held"
        case .missed: return "Missed"
        }
    }
}

/// public.facility_medication_schedule — one row per dose slot, with whatever
/// was actually administered joined on. `status == .outstanding` means no
/// administration row exists for that slot, which is the default state.
struct MedicationDose: Codable, Identifiable, Equatable {
    let medicationId: String
    let residentId: String
    let residentName: String
    let roomId: String?
    let medicationName: String
    let dose: String
    let route: String
    let instructions: String?
    let scheduledFor: Date
    let status: MedicationDoseStatus
    let administeredAt: Date?
    let administrationNote: String?

    /// Stable across refreshes: the view has no synthetic key, and a
    /// medication can legitimately appear twice a day.
    var id: String { "\(medicationId)-\(scheduledFor.timeIntervalSince1970)" }

    /// Past its scheduled time and still not acted on. Drives both the
    /// caregiver's "overdue" styling and the reminder notification.
    var isOverdue: Bool {
        status == .outstanding && scheduledFor < Date()
    }

    enum CodingKeys: String, CodingKey {
        case medicationId = "medication_id"
        case residentId = "resident_id"
        case residentName = "resident_name"
        case roomId = "room_id"
        case medicationName = "medication_name"
        case dose, route, instructions
        case scheduledFor = "scheduled_for"
        case status
        case administeredAt = "administered_at"
        case administrationNote = "administration_note"
    }
}

/// public.resident_emergency_contacts
struct EmergencyContact: Codable, Identifiable, Equatable {
    let id: String
    let residentId: String
    let displayName: String
    let relationship: String
    let phoneE164: String
    let isPrimary: Bool
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case residentId = "resident_id"
        case displayName = "display_name"
        case relationship
        case phoneE164 = "phone_e164"
        case isPrimary = "is_primary"
        case notes
    }
}

/// public.caregiver_shifts
struct CaregiverShift: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let phoneE164: String?
    let roleLabel: String
    let startsAt: Date
    let endsAt: Date

    var isOnNow: Bool {
        let now = Date()
        return startsAt <= now && endsAt > now
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case phoneE164 = "phone_e164"
        case roleLabel = "role_label"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
    }
}

enum HandoffPriority: String, Codable {
    case routine, watch, urgent

    var label: String {
        switch self {
        case .routine: return "Routine"
        case .watch: return "Watch"
        case .urgent: return "Urgent"
        }
    }
}

/// public.handoff_notes
struct HandoffNote: Codable, Identifiable, Equatable {
    let id: String
    let residentId: String?
    let authorName: String
    let body: String
    let priority: HandoffPriority
    let createdAt: Date
    let acknowledgedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case residentId = "resident_id"
        case authorName = "author_name"
        case body, priority
        case createdAt = "created_at"
        case acknowledgedAt = "acknowledged_at"
    }
}

enum CodeStatus: String, Codable {
    case fullCode = "full_code"
    case dnr, dni
    case comfortCare = "comfort_care"

    /// Spelled out rather than abbreviated: a float or agency caregiver
    /// reading this at 03:00 should not have to decode an acronym.
    var label: String {
        switch self {
        case .fullCode: return "Full code"
        case .dnr: return "DNR — do not resuscitate"
        case .dni: return "DNI — do not intubate"
        case .comfortCare: return "Comfort care only"
        }
    }

    var isRestricted: Bool { self != .fullCode }
}

/// Extends the existing formatter in Domain/Format.swift (which already owns
/// relativeTime/clockTime/seconds) rather than redeclaring the enum.
extension MeridianFormat {
    /// Takes the raw Postgres `date` string ("1942-03-14") rather than a
    /// Date — see ResidentProfile.dateOfBirth for why it stays a string.
    static func age(fromISODate raw: String) -> Int? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let birth = formatter.date(from: raw) else { return nil }
        return Calendar.current.dateComponents([.year], from: birth, to: Date()).year
    }

    /// "22:00" / "06:30" from a Postgres `time` column, rendered in the
    /// viewer's locale rather than assuming a 24-hour clock.
    static func scheduleTime(_ raw: String) -> String {
        let parts = raw.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return raw
        }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else { return raw }
        return clockTime(date)
    }
}
