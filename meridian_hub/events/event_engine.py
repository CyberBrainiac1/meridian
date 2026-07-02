import uuid
from collections.abc import Callable
from datetime import datetime, timezone

from meridian_hub.events.schemas import Evidence, MeridianEvent


class EventEngine:
    """Builds canonical events and suppresses duplicate notifications of
    an already-open incident. Critically: dedup only ever suppresses a
    *repeat* of an incident that's already open -- the first event for
    any (camera_id, track_id, event_type) key always emits immediately,
    with zero added latency. This distinction is what design spec section
    2.1 calls the non-negotiable real-time guarantee."""

    def __init__(self, clock: Callable[[], datetime] = lambda: datetime.now(timezone.utc)):
        self._clock = clock
        self._open_incidents: set[tuple[str, int, str]] = set()

    def emit_fall_event(
        self, *, camera_id: str, track_id: int, facility_id: str, building_id: str,
        floor_id: str, room_id: str, resident_id: str | None, event_type: str,
        severity: str, confidence: float, detected_at: datetime, reason_codes: list[str],
    ) -> MeridianEvent | None:
        key = (camera_id, track_id, event_type)
        if key in self._open_incidents:
            return None
        self._open_incidents.add(key)

        return MeridianEvent(
            event_id=f"evt_{uuid.uuid4().hex[:20]}",
            facility_id=facility_id, building_id=building_id, floor_id=floor_id,
            room_id=room_id, resident_id=resident_id, camera_id=camera_id,
            event_type=event_type, severity=severity, confidence=confidence,
            detected_at=detected_at, generated_at=self._clock(), status="open",
            reason_codes=reason_codes, evidence=Evidence(skeleton_available=True),
        )

    def resolve(self, *, camera_id: str, track_id: int, event_type: str) -> None:
        self._open_incidents.discard((camera_id, track_id, event_type))
