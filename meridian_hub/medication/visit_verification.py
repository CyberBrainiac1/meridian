from dataclasses import dataclass

from meridian_hub.dementia_safety.zone_rules import Zone
from meridian_hub.vision.tracker import TrackedPerson


@dataclass(frozen=True)
class MedicationWindow:
    window_id: str
    start_timestamp: float
    end_timestamp: float


@dataclass(frozen=True)
class MedicationVisitResult:
    window_id: str
    visited: bool
    visit_timestamp: float | None


class MedicationVisitVerifier:
    """PRD section 8.16: confirms a caregiver or med-cart reached the
    resident's room during a configured window -- a presence check, not
    clinical verification (explicit PRD non-goal: does not verify
    ingestion or administration). Anyone dwelling in the configured zone
    long enough counts as a visit; this class doesn't distinguish who,
    since that's outside this build's scope (no consented face recognition
    tied in here -- see meridian_hub/face for that, separately)."""

    def __init__(self, zone: Zone, min_dwell_seconds: float = 5.0):
        self.zone = zone
        self.min_dwell_seconds = min_dwell_seconds
        self._dwell_start: dict[int, float] = {}
        self._confirmed_this_dwell: set[int] = set()
        self._confirmed_visits: list[float] = []

    def update(self, tracked_people: list[TrackedPerson], timestamp: float) -> None:
        currently_inside_ids: set[int] = set()

        for person in tracked_people:
            x, y = person.detection.hip_center()
            if not self.zone.contains(x, y):
                continue
            currently_inside_ids.add(person.track_id)
            if person.track_id not in self._dwell_start:
                self._dwell_start[person.track_id] = timestamp

            dwell = timestamp - self._dwell_start[person.track_id]
            if dwell >= self.min_dwell_seconds and person.track_id not in self._confirmed_this_dwell:
                self._confirmed_visits.append(timestamp)
                self._confirmed_this_dwell.add(person.track_id)

        for track_id in list(self._dwell_start.keys()):
            if track_id not in currently_inside_ids:
                del self._dwell_start[track_id]
                self._confirmed_this_dwell.discard(track_id)

    def check_window(self, window: MedicationWindow) -> MedicationVisitResult:
        visits = [t for t in self._confirmed_visits if window.start_timestamp <= t <= window.end_timestamp]
        if visits:
            return MedicationVisitResult(window.window_id, visited=True, visit_timestamp=visits[0])
        return MedicationVisitResult(window.window_id, visited=False, visit_timestamp=None)
