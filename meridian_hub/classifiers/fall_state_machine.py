from meridian_hub.classifiers import thresholds as T
from meridian_hub.classifiers.fall_types import FallEvent, FallState
from meridian_hub.features.feature_window import KinematicFeatures


class FallStateMachine:
    """NORMAL -> FALL_CANDIDATE -> {CONFIRMED, SUSPECTED} -> (recovered) -> NORMAL.
    One instance per tracked person. CONFIRMED fires immediately on
    crossing thresholds -- no I/O, no network, so it can never be delayed
    by anything external (design spec section 2.1's real-time guarantee).

    The machine is re-armable: after a CONFIRMED or SUSPECTED fall, once
    the person is clearly back on their feet (upright, vertical envelope,
    not moving downward), it emits CLEARED and returns to NORMAL so a
    *subsequent* fall on the same continuous track is detected fresh. This
    matters both operationally (a resident can fall more than once over a
    shift) and for a live demo (staging the fall twice in a row must work
    without restarting the Hub)."""

    def __init__(self, track_id: int):
        self.track_id = track_id
        self.state = FallState.NORMAL
        self._candidate_since: float | None = None

    def _is_back_on_feet(self, features: KinematicFeatures) -> bool:
        """Unambiguous 'upright and stable again' signal: torso vertical,
        the pose envelope tall rather than wide (not lying down), and no
        active downward motion. Used to re-arm after a terminal state."""
        return (
            features.torso_angle_degrees < T.ANGLE_CANDIDATE_THRESHOLD_DEGREES
            and features.aspect_ratio < T.ASPECT_RATIO_HORIZONTAL_THRESHOLD
            and features.hip_vertical_velocity < T.VELOCITY_CANDIDATE_THRESHOLD
        )

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

        if self.state in (FallState.CONFIRMED, FallState.SUSPECTED):
            # Re-arm once the person is clearly back on their feet: emit
            # CLEARED (which the daemon uses to resolve the open incident,
            # re-arming the event engine's dedup too) and return to NORMAL
            # so the next fall on this same track is detected fresh.
            if self._is_back_on_feet(features):
                self.state = FallState.NORMAL
                self._candidate_since = None
                return FallEvent(self.track_id, FallState.CLEARED, timestamp)
            return None

        return None
