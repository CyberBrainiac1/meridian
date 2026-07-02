// Hand-mirrored from supabase/migrations/*.sql. If you change a table or
// view's shape in a migration, update the matching type here in the same
// commit — this file (not the raw SQL) is what the app code should import.

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
