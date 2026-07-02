from dataclasses import dataclass

from meridian_hub.vision.pose_types import PersonDetection

RAISED_ARM_HOLD_SECONDS = 2.0


@dataclass(frozen=True)
class DistressSignalEvent:
    track_id: int
    timestamp: float
    hold_duration_seconds: float


class DistressSignalDetector:
    """Voluntary distress call: both wrists held above shoulder height
    for a sustained duration. A simple, reliable gesture a resident can
    use to proactively signal "I need help" without a wearable or a
    verbal command -- this build has no audio pipeline, so a gesture is
    the practical option. One instance per tracked person, mirrors
    LongLieDetector's single-fire-per-episode pattern."""

    def __init__(self, track_id: int, hold_seconds: float = RAISED_ARM_HOLD_SECONDS):
        self.track_id = track_id
        self.hold_seconds = hold_seconds
        self._raised_since: float | None = None
        self._fired_this_episode = False

    def update(self, detection: PersonDetection, timestamp: float) -> DistressSignalEvent | None:
        left_wrist = detection.get("left_wrist")
        right_wrist = detection.get("right_wrist")
        left_shoulder = detection.get("left_shoulder")
        right_shoulder = detection.get("right_shoulder")
        # Image y increases downward, so "raised above the shoulder" means
        # a smaller y value than the shoulder's.
        both_raised = left_wrist.y < left_shoulder.y and right_wrist.y < right_shoulder.y

        if not both_raised:
            self._raised_since = None
            self._fired_this_episode = False
            return None

        if self._raised_since is None:
            self._raised_since = timestamp

        duration = timestamp - self._raised_since
        if duration >= self.hold_seconds and not self._fired_this_episode:
            self._fired_this_episode = True
            return DistressSignalEvent(self.track_id, timestamp, duration)
        return None
