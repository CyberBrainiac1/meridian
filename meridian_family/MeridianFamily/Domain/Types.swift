import Foundation

// Hand-mirrored from meridian_software/shared/types.ts, which is itself
// hand-mirrored from supabase/migrations/*.sql. Keep in sync with that file
// in the same commit whenever the schema changes.

enum FacilityRole: String, Codable {
    case owner, admin, caregiver, viewer, family
}

enum IncidentEventType: String, Codable {
    case fallSuspected = "fall_suspected"
    case fallConfirmed = "fall_confirmed"
    case longLie = "long_lie"
    case unusualInactivity = "unusual_inactivity"
    case wandering
    case exitRisk = "exit_risk"
    case nightActivity = "night_activity"
    case deviceOffline = "device_offline"
    case streamDegraded = "stream_degraded"
    case medicationVisitMissing = "medication_visit_missing"
    case visitorArrival = "visitor_arrival"
    case visitorDeparture = "visitor_departure"

    var label: String {
        switch self {
        case .fallSuspected: return "Fall suspected"
        case .fallConfirmed: return "Fall confirmed"
        case .longLie: return "Long lie"
        case .unusualInactivity: return "Unusual inactivity"
        case .wandering: return "Wandering"
        case .exitRisk: return "Exit risk"
        case .nightActivity: return "Night activity"
        case .deviceOffline: return "Device offline"
        case .streamDegraded: return "Stream degraded"
        case .medicationVisitMissing: return "Medication visit missing"
        case .visitorArrival: return "Visitor arrival"
        case .visitorDeparture: return "Visitor departure"
        }
    }
}

enum IncidentSeverity: String, Codable {
    case info, warning, critical
}

enum IncidentStatus: String, Codable {
    case open, acknowledged, responding, resolved
    case dismissedFalseAlarm = "dismissed_false_alarm"
    case escalated

    var isResolved: Bool { self == .resolved || self == .dismissedFalseAlarm }
}

enum VisitorMatchStatus: String, Codable {
    case newVisitor = "new_visitor"
    case repeatVisitor = "repeat_visitor"
    case knownVisitor = "known_visitor"
    case unknown
}

/// public.family_incident_feed — daily summary / alert source. Already
/// scoped server-side to the caller's linked resident(s).
struct FamilyIncidentRow: Codable, Identifiable, Equatable {
    let residentId: String
    let eventType: IncidentEventType
    let severity: IncidentSeverity
    let status: IncidentStatus
    let detectedAt: Date
    let acknowledgedAt: Date?
    let resolvedAt: Date?
    let resolutionNote: String?
    let summary: String?

    var id: String { "\(residentId)-\(detectedAt.timeIntervalSince1970)-\(eventType.rawValue)" }

    enum CodingKeys: String, CodingKey {
        case residentId = "resident_id"
        case eventType = "event_type"
        case severity, status
        case detectedAt = "detected_at"
        case acknowledgedAt = "acknowledged_at"
        case resolvedAt = "resolved_at"
        case resolutionNote = "resolution_note"
        case summary
    }
}

/// public.family_visitor_feed — metadata only, no name column (structurally
/// enforced — there is nothing to bind an identity to even by accident).
struct FamilyVisitorRow: Codable, Equatable {
    let matchStatus: VisitorMatchStatus
    let detectedAt: Date

    enum CodingKeys: String, CodingKey {
        case matchStatus = "match_status"
        case detectedAt = "detected_at"
    }
}

/// public.family_activity_rollup_feed — category-only daily room-camera
/// comparison. The database deliberately exposes no counts, room/camera IDs,
/// pose, tracks, or timestamps within the day.
enum FamilyMovementPattern: String, Codable {
    case usual
    case lowerThanUsual = "lower_than_usual"
    case higherThanUsual = "higher_than_usual"
    case notCompared = "not_compared"
    case insufficientObservation = "insufficient_observation"
}

enum FamilyActivityBaselineStatus: String, Codable {
    case ready
    case building
}

enum FamilyActivityObservationStatus: String, Codable {
    case sufficient
    case limited
}

struct FamilyActivityRollupRow: Codable, Equatable {
    let residentId: String
    let rollupDate: String
    let daytimePattern: FamilyMovementPattern
    let nighttimePattern: FamilyMovementPattern
    let baselineStatus: FamilyActivityBaselineStatus
    let observationStatus: FamilyActivityObservationStatus

    enum CodingKeys: String, CodingKey {
        case residentId = "resident_id"
        case rollupDate = "rollup_date"
        case daytimePattern = "daytime_pattern"
        case nighttimePattern = "nighttime_pattern"
        case baselineStatus = "baseline_status"
        case observationStatus = "observation_status"
    }
}

/// public.notifications — RLS already scopes this to the caller's linked
/// resident(s); mixes incident-response updates (incident_id set) and
/// new-visitor alerts (incident_id null).
struct NotificationRow: Codable, Identifiable, Equatable {
    let id: String
    let residentId: String?
    let incidentId: String?
    let body: String
    let createdAt: Date
    let sentAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case residentId = "resident_id"
        case incidentId = "incident_id"
        case body
        case createdAt = "created_at"
        case sentAt = "sent_at"
    }
}

/// public.family_linked_residents — name-only projection, added because no
/// other family-accessible source carries a display name. See
/// supabase/migrations/20260703000300_family_linked_resident_names.sql.
struct FamilyLinkedResident: Codable, Identifiable, Equatable {
    let residentId: String
    let displayName: String

    var id: String { residentId }

    enum CodingKeys: String, CodingKey {
        case residentId = "resident_id"
        case displayName = "display_name"
    }
}

/// public.family_member_links row for the signed-in user (role gate: at
/// least one row means this is a legitimate family account).
enum MessageSenderRole: String, Codable {
    case resident, family
}

/// public.messages — one shared thread per resident; every linked family
/// member reads and writes the same thread (mirrors the existing "Call
/// family" fan-out to every linked relative, not a 1:1 conversation).
/// Security tier is TLS in transit + AES-256 at rest + RLS scoping to the
/// linked resident<->family pair — not end-to-end encryption. See
/// supabase/migrations/*_resident_family_messaging.sql for the full
/// reasoning behind that boundary.
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

struct FamilyMemberLink: Codable {
    let facilityId: String
    let residentId: String

    enum CodingKeys: String, CodingKey {
        case facilityId = "facility_id"
        case residentId = "resident_id"
    }
}
