from collections import deque
from dataclasses import dataclass
from typing import Literal

from meridian_hub.vision.tracker import TrackedPerson

ZoneType = Literal["exit_door", "restricted", "safe_zone"]
WanderEventType = Literal[
    "door_approach", "door_crossing", "unaccompanied_exit",
    "restricted_zone_entry", "pacing_detected",
]


@dataclass(frozen=True)
class Zone:
    zone_id: str
    zone_type: ZoneType
    bbox: tuple[float, float, float, float]  # x1, y1, x2, y2

    def contains(self, x: float, y: float) -> bool:
        x1, y1, x2, y2 = self.bbox
        return x1 <= x <= x2 and y1 <= y <= y2


@dataclass(frozen=True)
class WanderEvent:
    track_id: int
    zone_id: str
    event_type: WanderEventType
    timestamp: float


class DementiaSafetyMonitor:
    """PRD section 8.12: pacing, door approach/crossing, unaccompanied
    exit, restricted-zone entry -- generates events only, never restricts
    movement or diagnoses cognitive decline (explicit PRD non-goal). Zones
    are simple rectangles for the POC, not polygons -- sufficient to
    demonstrate the rule logic without adding polygon-geometry complexity
    that isn't the point of this feature."""

    def __init__(self, zones: list[Zone], pacing_window_seconds: float = 120.0, pacing_entry_threshold: int = 4):
        self.zones = zones
        self.pacing_window_seconds = pacing_window_seconds
        self.pacing_entry_threshold = pacing_entry_threshold
        self._presence: dict[tuple[int, str], bool] = {}  # (track_id, zone_id) -> currently inside
        self._entry_log: dict[tuple[int, str], deque[float]] = {}

    def update(self, tracked_people: list[TrackedPerson], timestamp: float) -> list[WanderEvent]:
        events: list[WanderEvent] = []
        active_track_ids = {p.track_id for p in tracked_people}

        for zone in self.zones:
            for person in tracked_people:
                x, y = person.detection.hip_center()
                inside_now = zone.contains(x, y)
                key = (person.track_id, zone.zone_id)
                was_inside = self._presence.get(key, False)

                if inside_now and not was_inside:
                    events.extend(self._on_zone_entry(person, zone, tracked_people, timestamp))
                elif not inside_now and was_inside and zone.zone_type == "exit_door":
                    events.append(WanderEvent(person.track_id, zone.zone_id, "door_crossing", timestamp))

                self._presence[key] = inside_now

        self._prune_stale_tracks(active_track_ids)
        return events

    def _on_zone_entry(self, person: TrackedPerson, zone: Zone, tracked_people: list[TrackedPerson], timestamp: float) -> list[WanderEvent]:
        events: list[WanderEvent] = []
        key = (person.track_id, zone.zone_id)

        if zone.zone_type == "exit_door":
            events.append(WanderEvent(person.track_id, zone.zone_id, "door_approach", timestamp))
            accompanied = any(other.track_id != person.track_id for other in tracked_people)
            if not accompanied:
                events.append(WanderEvent(person.track_id, zone.zone_id, "unaccompanied_exit", timestamp))

        if zone.zone_type == "restricted":
            events.append(WanderEvent(person.track_id, zone.zone_id, "restricted_zone_entry", timestamp))

        log = self._entry_log.setdefault(key, deque())
        log.append(timestamp)
        cutoff = timestamp - self.pacing_window_seconds
        while log and log[0] < cutoff:
            log.popleft()
        if len(log) >= self.pacing_entry_threshold:
            events.append(WanderEvent(person.track_id, zone.zone_id, "pacing_detected", timestamp))
            log.clear()  # one pacing signal per accumulation, not one per entry after threshold

        return events

    def _prune_stale_tracks(self, active_track_ids: set[int]) -> None:
        for key in list(self._presence.keys()):
            if key[0] not in active_track_ids:
                del self._presence[key]
