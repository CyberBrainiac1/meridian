// Hand-mirrored from meridian_software/shared/types.ts, which is itself
// hand-mirrored from supabase/migrations/*.sql. This app's build root can't
// import across the repo boundary, so this copy must stay in sync with the
// canonical file in the same commit whenever the schema changes.

export type FacilityRole = "owner" | "admin" | "caregiver" | "viewer" | "family";

export type IncidentEventType =
    | "fall_suspected"
    | "fall_confirmed"
    | "long_lie"
    | "unusual_inactivity"
    | "wandering"
    | "exit_risk"
    | "night_activity"
    | "device_offline"
    | "stream_degraded"
    | "medication_visit_missing"
    | "visitor_arrival"
    | "visitor_departure";

export type IncidentSeverity = "info" | "warning" | "critical";

export type IncidentStatus =
    | "open"
    | "acknowledged"
    | "responding"
    | "resolved"
    | "dismissed_false_alarm"
    | "escalated";

export type VisitorMatchStatus = "new_visitor" | "repeat_visitor" | "known_visitor" | "unknown";

export interface ResidentProfile {
    id: string;
    facility_id: string;
    person_id: string;
    room_id: string | null;
    display_name: string;
    risk_flags: string[];
    care_notes: string | null;
    created_at: string;
    updated_at: string;
}

/** public.facility_floor_view — Insights live floor view, one row per resident. */
export interface FloorViewRow {
    facility_id: string;
    resident_id: string;
    display_name: string;
    room_id: string | null;
    risk_flags: string[];
    open_incident_id: string | null;
    open_incident_type: IncidentEventType | null;
    open_incident_severity: IncidentSeverity | null;
    open_incident_status: IncidentStatus | null;
    open_incident_detected_at: string | null;
}

/** public.facility_response_metrics — Insights response-time analytics by shift. */
export interface ResponseMetricRow {
    facility_id: string;
    shift_date: string;
    shift: "night" | "day" | "evening";
    incident_count: number;
    avg_ack_seconds: number | null;
}

/** public.resident_activity_view — Insights resident detail incident history. */
export interface ResidentActivityRow {
    facility_id: string;
    resident_id: string;
    display_name: string;
    incident_id: string;
    event_type: IncidentEventType;
    severity: IncidentSeverity;
    status: IncidentStatus;
    detected_at: string;
    acknowledged_at: string | null;
    resolved_at: string | null;
    resolution_note: string | null;
}

/** public.family_incident_feed — Family app daily summary / alert source. */
export interface FamilyIncidentRow {
    facility_id: string;
    resident_id: string;
    event_type: IncidentEventType;
    severity: IncidentSeverity;
    status: IncidentStatus;
    detected_at: string;
    acknowledged_at: string | null;
    resolved_at: string | null;
    resolution_note: string | null;
    summary: string | null;
}

/** public.family_visitor_feed — Family app visitor log (metadata only). */
export interface FamilyVisitorRow {
    facility_id: string;
    camera_id: string | null;
    match_status: VisitorMatchStatus;
    detected_at: string;
    quality_score: number | null;
}

/** UI-safe projection for care-team visitor review screens. */
export interface VisitorObservationTimelineRow {
    facility_id: string;
    camera_id: string | null;
    match_status: VisitorMatchStatus;
    detected_at: string;
    quality_score: number | null;
    matched_person_id: string | null;
    body_description: string | null;
    body_description_model: string | null;
    body_description_generated_at: string | null;
}

/** public.notifications — audit trail of what a family was told and when. */
export interface NotificationRow {
    id: string;
    facility_id: string;
    resident_id: string | null;
    incident_id: string | null;
    channel: "sms" | "push";
    body: string;
    status: "pending" | "sent" | "failed";
    created_at: string;
    sent_at: string | null;
}

/** Args/return for the public.respond_to_incident RPC. */
export interface RespondToIncidentArgs {
    p_incident_id: string;
    p_new_status: Extract<
        IncidentStatus,
        "acknowledged" | "responding" | "resolved" | "dismissed_false_alarm" | "escalated"
    >;
    p_note?: string | null;
}

/** public.cameras — joined client-side for display_name/location_label lookups. */
export interface CameraRow {
    id: string;
    facility_id: string;
    external_id: string;
    display_name: string | null;
    location_label: string | null;
    status: "provisioning" | "online" | "offline" | "disabled";
    last_seen_at: string | null;
}

/** public.incident_events — raw row, care-team surfaces only (never family). */
export interface IncidentEventRow {
    id: string;
    source_event_id: string;
    facility_id: string;
    room_id: string | null;
    resident_id: string | null;
    camera_id: string | null;
    event_type: IncidentEventType;
    severity: IncidentSeverity;
    status: IncidentStatus;
    confidence: number | null;
    detected_at: string;
    generated_at: string;
    reason_codes: string[];
    summary: string | null;
    acknowledged_by: string | null;
    acknowledged_at: string | null;
    resolved_by: string | null;
    resolved_at: string | null;
    resolution_note: string | null;
}
