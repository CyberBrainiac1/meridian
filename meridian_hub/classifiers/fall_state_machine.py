from meridian_hub.classifiers import thresholds as T
from meridian_hub.classifiers.fall_types import FallEvent, FallState
from meridian_hub.features.feature_window import KinematicFeatures


class FallStateMachine:
    """NORMAL -> FALL_CANDIDATE -> {CONFIRMED, SUSPECTED, CLEARED} -> NORMAL.
    One instance per tracked person. CONFIRMED fires immediately on
    crossing thresholds -- no I/O, no network, so it can never be delayed
    by anything external (design spec section 2.1's real-time guarantee)."""

    def __init__(self, track_id: int):
        self.track_id = track_id
        self.state = FallState.NORMAL
        self._candidate_since: float | None = None

    def update(self, features: KinematicFeatures, timestamp: float) -> FallEvent | None:
        if self.state == FallState.NORMAL:
            if (features.hip_vertical_velocity >= T.VELOCITY_CANDIDATE_THRESHOLD
                    and features.torso_angle_degrees >= T.ANGLE_CANDIDATE_THRESHOLD_DEGREES):
                self.state = FallState.FALL_CANDIDATE
                self._candidate_since = timestamp
            return None

        if self.state == FallState.FALL_CANDIDATE:
            elapsed = timestamp - (self._candidate_since or timestamp)

            is_horizontal_and_still = (
                features.aspect_ratio >= T.ASPECT_RATIO_HORIZONTAL_THRESHOLD
                and features.stillness_duration_seconds >= T.STILLNESS_CONFIRM_SECONDS
            )
            high_confidence = (
                features.torso_angle_degrees >= T.ANGLE_CONFIRM_THRESHOLD_DEGREES
                or features.hip_vertical_velocity >= T.VELOCITY_CONFIRM_THRESHOLD
            )
            if is_horizontal_and_still and high_confidence:
                self.state = FallState.CONFIRMED
                return FallEvent(self.track_id, FallState.CONFIRMED, timestamp)

            recovered = (
                features.torso_angle_degrees < T.ANGLE_CANDIDATE_THRESHOLD_DEGREES
                and features.hip_vertical_velocity < T.VELOCITY_CANDIDATE_THRESHOLD
                and features.stillness_duration_seconds == 0.0
            )
            if recovered:
                self.state = FallState.NORMAL
                self._candidate_since = None
                return FallEvent(self.track_id, FallState.CLEARED, timestamp)

            if elapsed >= T.CANDIDATE_WINDOW_SECONDS:
                self.state = FallState.SUSPECTED
                return FallEvent(self.track_id, FallState.SUSPECTED, timestamp)

            if is_horizontal_and_still or (
                features.torso_angle_degrees >= T.ANGLE_CANDIDATE_THRESHOLD_DEGREES
                and features.stillness_duration_seconds > 0.0
                and not high_confidence
            ):
                self.state = FallState.SUSPECTED
                return FallEvent(self.track_id, FallState.SUSPECTED, timestamp)

            return None

        # CONFIRMED/SUSPECTED/CLEARED: caller resets the machine (fresh
        # instance) once an incident is resolved -- this class only owns
        # detection, not incident lifecycle.
        return None
