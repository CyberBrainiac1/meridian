import type { IncidentEventType, IncidentStatus, VisitorMatchStatus } from "@/lib/types";

const VISITOR_MATCH_LABEL: Record<VisitorMatchStatus, string> = {
  new_visitor: "New visitor",
  unknown: "New visitor",
  repeat_visitor: "Repeat visitor",
  known_visitor: "Known visitor",
};

/** Hard constraint: never a name, never "unknown person identified", never
 *  a confidence score presented as identity. Only "New/Repeat/Known
 *  visitor detected at [camera]" — camera falls back to a generic phrase
 *  when the observation has no camera_id or the camera lookup misses. */
export function visitorArrivalCopy(
  matchStatus: VisitorMatchStatus,
  cameraName: string | null
): string {
  const label = VISITOR_MATCH_LABEL[matchStatus] ?? "New visitor";
  return `${label} detected at ${cameraName ?? "an entry camera"}`;
}

const EVENT_TYPE_LABEL: Record<IncidentEventType, string> = {
  fall_suspected: "Fall suspected",
  fall_confirmed: "Fall confirmed",
  long_lie: "Long lie",
  unusual_inactivity: "Unusual inactivity",
  wandering: "Wandering",
  exit_risk: "Exit risk",
  night_activity: "Night activity",
  device_offline: "Device offline",
  stream_degraded: "Stream degraded",
  medication_visit_missing: "Medication visit missing",
  visitor_arrival: "Visitor arrival",
  visitor_departure: "Visitor departure",
};

export function formatEventType(type: IncidentEventType): string {
  return EVENT_TYPE_LABEL[type] ?? type;
}

const STATUS_LABEL: Record<IncidentStatus, string> = {
  open: "Open",
  acknowledged: "Acknowledged",
  responding: "Responding",
  resolved: "Resolved",
  dismissed_false_alarm: "Dismissed (false alarm)",
  escalated: "Escalated",
};

export function formatStatus(status: IncidentStatus): string {
  return STATUS_LABEL[status] ?? status;
}

/** Room-level status derived from facility_floor_view. device_offline /
 *  stream_degraded on an otherwise-open incident means the camera/hub
 *  needs attention, not the resident — kept as a distinct "offline" tier
 *  from a real "alert" so care staff don't confuse hardware issues with
 *  emergencies. This mapping isn't specified verbatim in the API contract;
 *  it's the smallest reasonable derivation from the existing event_type
 *  enum, not a new backend field. */
export type RoomStatus = "normal" | "alert" | "offline";

export function roomStatus(
  openIncidentType: IncidentEventType | null
): RoomStatus {
  if (!openIncidentType) return "normal";
  if (openIncidentType === "device_offline" || openIncidentType === "stream_degraded") {
    return "offline";
  }
  return "alert";
}

export function formatRelativeTime(iso: string): string {
  const date = new Date(iso);
  const diffMs = Date.now() - date.getTime();
  const diffSec = Math.round(diffMs / 1000);

  if (diffSec < 5) return "just now";
  if (diffSec < 60) return `${diffSec}s ago`;
  const diffMin = Math.round(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.round(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  const diffDay = Math.round(diffHr / 24);
  return `${diffDay}d ago`;
}

export function formatClockTime(iso: string): string {
  return new Date(iso).toLocaleTimeString(undefined, {
    hour: "numeric",
    minute: "2-digit",
  });
}

export function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export function formatSeconds(seconds: number): string {
  if (seconds < 60) return `${Math.round(seconds)}s`;
  const minutes = Math.floor(seconds / 60);
  const remaining = Math.round(seconds % 60);
  return remaining > 0 ? `${minutes}m ${remaining}s` : `${minutes}m`;
}
