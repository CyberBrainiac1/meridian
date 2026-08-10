import Foundation

// Hand-mirrored from meridian_software/shared/types.ts, which is itself
// hand-mirrored from supabase/migrations/*.sql. Keep in sync with that file
// in the same commit whenever the schema changes.

enum CareFacilityRole: String, Codable {
    case owner, admin, caregiver, viewer, family
    /// Staff, as opposed to a relative. A family account also carries a
    /// facility_members row, so this is what keeps relatives out of the
    /// caregiver interface.
    var isCareTeam: Bool { self != .family }
}

enum CareIncidentEventType: String, Codable, CaseIterable {
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

    /// Care-app-facing label. Deliberately not a resident-first sentence
    /// (that's `summary` on the incident, per the PRD copy rule) — this is
    /// a short category tag shown alongside the summary.
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

enum CareIncidentSeverity: String, Codable {
    case info, warning, critical

    var label: String {
        switch self {
        case .info: return "Info"
        case .warning: return "Needs attention"
        case .critical: return "Emergency"
        }
    }
}

enum CareIncidentStatus: String, Codable, CaseIterable {
    case open, acknowledged, responding, resolved
    case dismissedFalseAlarm = "dismissed_false_alarm"
    case escalated

    var label: String {
        switch self {
        case .open: return "Open"
        case .acknowledged: return "Acknowledged"
        case .responding: return "Responding"
        case .resolved: return "Resolved"
        case .dismissedFalseAlarm: return "Dismissed (false alarm)"
        case .escalated: return "Escalated"
        }
    }

    /// Mirrors respond_to_incident's allowed-transition table
    /// (supabase/migrations/20260703000100_incident_rpc_and_views.sql) so
    /// the UI only offers actions the RPC will actually accept.
    var nextStatuses: [CareIncidentStatus] {
        switch self {
        case .open: return [.acknowledged, .responding, .resolved, .dismissedFalseAlarm, .escalated]
        case .acknowledged: return [.responding, .resolved, .dismissedFalseAlarm, .escalated]
        case .responding: return [.resolved, .dismissedFalseAlarm, .escalated]
        case .resolved, .dismissedFalseAlarm, .escalated: return []
        }
    }
}

/// public.incident_events — raw row. Care-team surfaces only.
struct IncidentEvent: Codable, Identifiable, Equatable {
    let id: String
    let sourceEventId: String
    let facilityId: String
    let roomId: String?
    let residentId: String?
    let cameraId: String?
    let eventType: CareIncidentEventType
    let severity: CareIncidentSeverity
    let status: CareIncidentStatus
    let confidence: Double?
    let detectedAt: Date
    let generatedAt: Date
    let summary: String?
    let acknowledgedBy: String?
    let acknowledgedAt: Date?
    let resolvedBy: String?
    let resolvedAt: Date?
    let resolutionNote: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sourceEventId = "source_event_id"
        case facilityId = "facility_id"
        case roomId = "room_id"
        case residentId = "resident_id"
        case cameraId = "camera_id"
        case eventType = "event_type"
        case severity, status, confidence
        case detectedAt = "detected_at"
        case generatedAt = "generated_at"
        case summary
        case acknowledgedBy = "acknowledged_by"
        case acknowledgedAt = "acknowledged_at"
        case resolvedBy = "resolved_by"
        case resolvedAt = "resolved_at"
        case resolutionNote = "resolution_note"
    }
}

enum CareAssistanceKind: String, Codable {
    case assistance, emergency
    case familyContact = "family_contact"

    var label: String {
        switch self {
        case .assistance: return "Assistance"
        case .familyContact: return "Family call"
        case .emergency: return "Emergency"
        }
    }
}

enum CareAssistanceSource: String, Codable {
    case residentHub = "resident_hub"
    case autoFallDispatch = "auto_fall_dispatch"
}

enum CareAssistanceStatus: String, Codable {
    case open, acknowledged, resolved, cancelled
    case enRoute = "en_route"

    var isActive: Bool { self == .open || self == .acknowledged || self == .enRoute }
}

/// public.assistance_requests — a resident-initiated (or auto-fall-dispatch)
/// call for help, distinct from incident_events: this is "someone asked",
/// not "the system detected something". Kept as its own model and its own
/// watcher/notification tier rather than merged into the incident feed, so
/// "AI flagged a possible fall" and "resident pressed Emergency" stay
/// honestly distinguishable in the UI and in the data.
struct AssistanceRequest: Codable, Identifiable, Equatable {
    let id: String
    let facilityId: String
    let residentId: String
    let roomId: String
    let requestKind: CareAssistanceKind
    let source: CareAssistanceSource
    let status: CareAssistanceStatus
    let requestedAt: Date
    let acknowledgedAt: Date?
    let resolvedAt: Date?
    let cancelledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case facilityId = "facility_id"
        case residentId = "resident_id"
        case roomId = "room_id"
        case requestKind = "request_kind"
        case source, status
        case requestedAt = "requested_at"
        case acknowledgedAt = "acknowledged_at"
        case resolvedAt = "resolved_at"
        case cancelledAt = "cancelled_at"
    }
}

/// public.resident_profiles
struct ResidentProfile: Codable, Identifiable, Equatable {
    let id: String
    let facilityId: String
    let personId: String
    let roomId: String?
    let displayName: String
    let riskFlags: [String]
    let careNotes: String?
    /// Clinical detail added alongside the medication/handoff work. All
    /// optional: these columns are nullable, and a facility part-way through
    /// onboarding will legitimately have residents without them — decoding
    /// must not fail just because a profile is incomplete.
    /// Held as the raw "YYYY-MM-DD" string, not a Date: Postgres `date` has
    /// no time or zone component, so it does not parse with the ISO8601
    /// datetime strategy the rest of these models decode under.
    let dateOfBirth: String?
    let dietaryNeeds: String?
    let allergies: [String]?
    let codeStatus: CodeStatus?
    let mobilityStatus: String?
    let communicationNotes: String?

    var age: Int? { dateOfBirth.flatMap(MeridianFormat.age(fromISODate:)) }

    enum CodingKeys: String, CodingKey {
        case id
        case facilityId = "facility_id"
        case personId = "person_id"
        case roomId = "room_id"
        case displayName = "display_name"
        case riskFlags = "risk_flags"
        case careNotes = "care_notes"
        case dateOfBirth = "date_of_birth"
        case dietaryNeeds = "dietary_needs"
        case allergies
        case codeStatus = "code_status"
        case mobilityStatus = "mobility_status"
        case communicationNotes = "communication_notes"
    }
}

/// public.notifications
struct CareNotificationRow: Codable, Identifiable, Equatable {
    let id: String
    let facilityId: String
    let residentId: String?
    let incidentId: String?
    let channel: String
    let body: String
    let status: String
    let createdAt: Date
    let sentAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case facilityId = "facility_id"
        case residentId = "resident_id"
        case incidentId = "incident_id"
        case channel, body, status
        case createdAt = "created_at"
        case sentAt = "sent_at"
    }
}

/// facility_members row for the signed-in user (role resolution).
struct FacilityMembership: Codable {
    let facilityId: String
    let role: CareFacilityRole

    enum CodingKeys: String, CodingKey {
        case facilityId = "facility_id"
        case role
    }
}

/// RPC args for public.respond_to_incident.
struct RespondToIncidentArgs: Encodable {
    let pIncidentId: String
    let pNewStatus: String
    let pNote: String?

    enum CodingKeys: String, CodingKey {
        case pIncidentId = "p_incident_id"
        case pNewStatus = "p_new_status"
        case pNote = "p_note"
    }
}
