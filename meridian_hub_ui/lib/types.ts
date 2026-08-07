// Hand-mirrored from 20260807000000_meridian_hub_resident_surface.sql.
// This app deliberately uses only the resident-safe views, never raw visitor
// observations or their encrypted biometric fields.

export type AssistanceKind = "assistance" | "family_contact" | "emergency";
export type AssistanceSource = "resident_hub" | "auto_fall_dispatch";
export type AssistanceStatus = "open" | "acknowledged" | "en_route" | "resolved" | "cancelled";
export type EtaConfidence = "data_derived" | "limited_history" | "facility_default";
export type VisitorPromptStatus = "pending" | "approved" | "denied" | "no_response";

export interface HubProfile {
  facility_id: string;
  resident_id: string;
  room_id: string;
  display_name: string;
}

export interface HubAssistanceRequest {
  id: string;
  request_kind: AssistanceKind;
  source: AssistanceSource;
  status: AssistanceStatus;
  requested_at: string;
  acknowledged_at: string | null;
  en_route_at: string | null;
  resolved_at: string | null;
  cancelled_at: string | null;
  eta_seconds: number;
  eta_confidence: EtaConfidence;
}

export interface HubVisitorPrompt {
  id: string;
  status: VisitorPromptStatus;
  prompted_at: string;
  expires_at: string;
  answered_at: string | null;
  escalation_notified_at: string | null;
  camera_id: string | null;
  body_description: string | null;
  detected_at: string;
}

export interface HubState {
  profile: HubProfile;
  assistanceRequests: HubAssistanceRequest[];
  visitorPrompts: HubVisitorPrompt[];
}
