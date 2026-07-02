from dataclasses import dataclass


@dataclass(frozen=True)
class LongLieEvent:
    track_id: int
    timestamp: float
    floor_duration_seconds: float


class LongLieDetector:
    """PRD section 8.4: flags sustained floor-level posture beyond what a
    fall-confirmation stillness window already covers. One instance per
    tracked person. Day/night baseline and bed-zone awareness (so normal
    sleep isn't flagged) are layered on in Part 2 via night_rounds/zone
    components -- this is the core duration-tracking primitive they build
    on. Fires once per continuous floor-level episode, not repeatedly,
    since the event engine's own cooldown (Part 2) handles delivery-level
    dedup; this class handles detection-level dedup so it emits a clean
    single signal per real episode."""

    def __init__(self, track_id: int, floor_threshold_seconds: float = 300.0):
        self.track_id = track_id
        self.floor_threshold_seconds = floor_threshold_seconds
        self._floor_since: float | None = None
        self._fired_this_episode = False

    def update(self, floor_level: bool, timestamp: float) -> LongLieEvent | None:
        if not floor_level:
            self._floor_since = None
            self._fired_this_episode = False
            return None

        if self._floor_since is None:
            self._floor_since = timestamp

        duration = timestamp - self._floor_since
        if duration >= self.floor_threshold_seconds and not self._fired_this_episode:
            self._fired_this_episode = True
            return LongLieEvent(self.track_id, timestamp, duration)
        return None
