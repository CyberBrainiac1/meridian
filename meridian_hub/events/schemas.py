from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

EventType = Literal[
    "fall_suspected", "fall_confirmed", "long_lie", "unusual_inactivity",
    "wandering", "exit_risk", "night_activity", "device_offline",
    "stream_degraded", "medication_visit_missing", "visitor_arrival",
    "visitor_departure",
]
Severity = Literal["info", "warning", "critical"]
EventStatus = Literal["open", "acknowledged", "responding", "resolved", "dismissed_false_alarm", "escalated"]


class Evidence(BaseModel):
    skeleton_available: bool = True
    incident_clip_available_locally: bool = False
    cloud_video_available: bool = False


class DeviceHealthSnapshot(BaseModel):
    stream_fps: float | None = None
    wifi_rssi: int | None = None


class MeridianEvent(BaseModel):
    """PRD section 17's canonical event schema, implemented field-for-field."""

    event_id: str
    schema_version: str = "1.0"
    facility_id: str
    building_id: str
    floor_id: str
    room_id: str
    resident_id: str | None
    camera_id: str
    event_type: EventType
    severity: Severity
    confidence: float
    detected_at: datetime
    generated_at: datetime
    status: EventStatus = "open"
    reason_codes: list[str]
    evidence: Evidence = Field(default_factory=Evidence)
    device_health: DeviceHealthSnapshot = Field(default_factory=DeviceHealthSnapshot)
