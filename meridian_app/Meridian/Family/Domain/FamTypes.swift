import Foundation

// Hand-mirrored from meridian_software/shared/types.ts, which is itself
// hand-mirrored from supabase/migrations/*.sql. Keep in sync with that file
// in the same commit whenever the schema changes.

// `FacilityRole` used to be declared here. It was never referenced anywhere
// in this interface — the family role gate is the `family_linked_residents`
// lookup in AuthViewModel, not a role enum — so it was dropped in the merge
// rather than renamed alongside Care's `CareFacilityRole`.
//
// `IncidentEventType`, `IncidentSeverity` and `IncidentStatus` also used to
// be declared here. Care's copies (Care/Domain/Types.swift) carry the same
// cases and the same raw values, so these are the same types read through a
// narrower view, not parallel ones — Care's now serve both. Care's copies
// are supersets in members only (CaseIterable, `label`, `nextStatuses`);
// the one member Family had and Care does not, `IncidentStatus.isResolved`,
// moved onto `FamilyIncidentRow` below rather than becoming an extension on
// a type this interface does not own.

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

    /// Was `IncidentStatus.isResolved` before the three apps became one
    /// module. Same rule, same two statuses — held here, on a type this
    /// interface owns, so it cannot collide with anything Care adds to the
    /// shared enum.
    var isResolved: Bool { status == .resolved || status == .dismissedFalseAlarm }

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
struct FamNotificationRow: Codable, Identifiable, Equatable {
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

// `MessageSenderRole` and `Message` used to be declared here, identically to
// Shared/SharedTypes.swift, which now owns both — the Hub writes the same
// rows this interface reads, so a per-interface copy was never right.
//
// Their doc comment is kept here because it records the messaging privacy
// boundary and nothing else does: public.messages is one shared thread per
// resident; every linked family member reads and writes the same thread
// (mirroring the existing "Call family" fan-out to every linked relative,
// not a 1:1 conversation). Security tier is TLS in transit + AES-256 at
// rest + RLS scoping to the linked resident<->family pair — NOT end-to-end
// encryption. See supabase/migrations/*_resident_family_messaging.sql for
// the full reasoning behind that boundary.
//
// `FamilyMemberLink` (public.family_member_links, described by the stray
// doc comment that used to sit above `MessageSenderRole`) was declared here
// and referenced nowhere, so it was dropped in the merge. The family role
// gate it was written for is the `family_linked_residents` lookup in
// AuthViewModel.
