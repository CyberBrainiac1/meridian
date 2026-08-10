import Foundation

/// Mirrors the resident-safe views from
/// supabase/migrations/20260807000000_meridian_hub_resident_surface.sql and
/// the medication feed added later. Ported from the retired web Hub's
/// lib/types.ts.
///
/// This app deliberately reads only the `resident_hub_*` views, never raw
/// incident or visitor-observation tables. The medication feed in particular
/// exposes no drug name, dose or instructions — a device sitting in a room is
/// not a medication record, and that boundary is enforced in the view, not
/// here.

enum AssistanceKind: String, Codable {
    case assistance, emergency
    case familyContact = "family_contact"

    var label: String {
        switch self {
        case .assistance: return "Assistance"
        case .familyContact: return "Call family"
        case .emergency: return "Emergency help"
        }
    }
}

enum AssistanceSource: String, Codable {
    case residentHub = "resident_hub"
    case autoFallDispatch = "auto_fall_dispatch"
}

enum AssistanceStatus: String, Codable {
    case open, acknowledged, resolved, cancelled
    case enRoute = "en_route"

    /// The three states where a caregiver is still coming. Terminal states
    /// stay on screen briefly so the resident is told the request finished,
    /// rather than the panel silently reverting under them.
    var isActive: Bool {
        self == .open || self == .acknowledged || self == .enRoute
    }
}

enum EtaConfidence: String, Codable {
    case dataDerived = "data_derived"
    case limitedHistory = "limited_history"
    case facilityDefault = "facility_default"
}

enum VisitorPromptStatus: String, Codable {
    case pending, approved, denied
    case noResponse = "no_response"
}

enum MedicationDoseStatus: String, Codable {
    case outstanding, given, refused, held, missed
}

struct HubProfile: Codable, Equatable {
    let facilityId: String
    let residentId: String
    let roomId: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case facilityId = "facility_id"
        case residentId = "resident_id"
        case roomId = "room_id"
        case displayName = "display_name"
    }
}

struct HubAssistanceRequest: Codable, Identifiable, Equatable {
    let id: String
    let requestKind: AssistanceKind
    let source: AssistanceSource
    let status: AssistanceStatus
    let requestedAt: Date
    let acknowledgedAt: Date?
    let enRouteAt: Date?
    let resolvedAt: Date?
    let cancelledAt: Date?
    let etaSeconds: Int
    let etaConfidence: EtaConfidence

    var endedAt: Date? { resolvedAt ?? cancelledAt }

    enum CodingKeys: String, CodingKey {
        case id
        case requestKind = "request_kind"
        case source, status
        case requestedAt = "requested_at"
        case acknowledgedAt = "acknowledged_at"
        case enRouteAt = "en_route_at"
        case resolvedAt = "resolved_at"
        case cancelledAt = "cancelled_at"
        case etaSeconds = "eta_seconds"
        case etaConfidence = "eta_confidence"
    }
}

struct HubVisitorPrompt: Codable, Identifiable, Equatable {
    let id: String
    let status: VisitorPromptStatus
    let promptedAt: Date
    let expiresAt: Date
    let answeredAt: Date?
    let escalationNotifiedAt: Date?
    let cameraId: String?
    let bodyDescription: String?
    let detectedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status
        case promptedAt = "prompted_at"
        case expiresAt = "expires_at"
        case answeredAt = "answered_at"
        case escalationNotifiedAt = "escalation_notified_at"
        case cameraId = "camera_id"
        case bodyDescription = "body_description"
        case detectedAt = "detected_at"
    }
}

/// public.resident_hub_medication_feed — times and status only, by design.
struct HubMedicationDose: Codable, Identifiable, Equatable {
    let medicationId: String
    let scheduledFor: Date
    let status: MedicationDoseStatus

    /// A medication can legitimately recur, so the id has to include the slot.
    var id: String { "\(medicationId)__\(ISO8601DateFormatter().string(from: scheduledFor))" }

    enum CodingKeys: String, CodingKey {
        case medicationId = "medication_id"
        case scheduledFor = "scheduled_for"
        case status
    }
}

enum MeridianFormat {
    static func clockTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "about 5 minutes" — never a bare number, and never false precision.
    static func approxMinutes(_ seconds: Int) -> String {
        let minutes = max(1, Int((Double(seconds) / 60).rounded()))
        return "about \(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}

enum ActivityType: String, Codable {
    case mealBreakfast = "meal_breakfast"
    case mealLunch = "meal_lunch"
    case mealDinner = "meal_dinner"
    case walk, bathing, activity
}

enum ActivityCompletionStatus: String, Codable {
    case outstanding, done, skipped, missed
}

/// public.resident_hub_activity_feed. Unlike HubMedicationDose this DOES
/// carry a label — "Lunch" and "Afternoon walk" have none of the clinical
/// sensitivity a drug name does, so there's no boundary reason to strip it.
struct HubActivity: Codable, Identifiable, Equatable {
    let activityId: String
    let activityType: ActivityType
    let label: String
    let scheduledFor: Date
    let status: ActivityCompletionStatus

    var id: String { "\(activityId)__\(ISO8601DateFormatter().string(from: scheduledFor))" }

    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id"
        case activityType = "activity_type"
        case label
        case scheduledFor = "scheduled_for"
        case status
    }
}

enum MessageSenderRole: String, Codable {
    case resident, family
}

/// public.messages — one shared thread per resident, every linked family
/// member reading and writing the same thread (mirrors the existing "Call
/// family" fan-out, and means the resident never has to choose which
/// relative to talk to). Security tier is TLS in transit + AES-256 at rest +
/// RLS scoping to the linked resident<->family pair — not end-to-end
/// encryption. See supabase/migrations/*_resident_family_messaging.sql for
/// the full reasoning.
struct Message: Codable, Identifiable, Equatable {
    let id: String
    let residentId: String
    let senderRole: MessageSenderRole
    let senderUserId: String
    let senderName: String
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case residentId = "resident_id"
        case senderRole = "sender_role"
        case senderUserId = "sender_user_id"
        case senderName = "sender_name"
        case body
        case createdAt = "created_at"
    }
}
