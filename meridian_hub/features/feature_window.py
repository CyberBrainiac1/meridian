import math
from collections import deque
from dataclasses import dataclass

from meridian_hub.vision.pose_types import PersonDetection

STILLNESS_EPSILON_PX = 3.0


@dataclass(frozen=True)
class KinematicFeatures:
    hip_vertical_velocity: float  # px/sec, positive = moving down
    torso_angle_degrees: float  # 0 = upright, 90 = horizontal
    aspect_ratio: float
    stillness_duration_seconds: float


class _SingleTrackWindow:
    def __init__(self, window_seconds: float):
        self.window_seconds = window_seconds
        self._detections: deque[PersonDetection] = deque()

    def add(self, detection: PersonDetection) -> None:
        self._detections.append(detection)
        cutoff = detection.timestamp - self.window_seconds
        while self._detections and self._detections[0].timestamp < cutoff:
            self._detections.popleft()

    def compute(self) -> KinematicFeatures:
        if len(self._detections) < 2:
            return KinematicFeatures(0.0, 0.0, 1.0, 0.0)

        dets = list(self._detections)
        first, last = dets[0], dets[-1]
        dt = last.timestamp - first.timestamp
        _, first_hy = first.hip_center()
        _, last_hy = last.hip_center()
        velocity = (last_hy - first_hy) / dt if dt > 0 else 0.0

        sx, sy = last.shoulder_center()
        hx, hy = last.hip_center()
        angle = math.degrees(math.atan2(abs(hx - sx), abs(hy - sy) + 1e-6))

        left_ankle = last.get("left_ankle")
        right_ankle = last.get("right_ankle")
        body_width = abs(right_ankle.x - left_ankle.x) + 20.0
        body_height = max(abs(left_ankle.y - sy), 1.0)
        aspect_ratio = body_width / body_height

        stillness = 0.0
        for i in range(len(dets) - 1, 0, -1):
            _, hy_curr = dets[i].hip_center()
            _, hy_prev = dets[i - 1].hip_center()
            if abs(hy_curr - hy_prev) <= STILLNESS_EPSILON_PX:
                stillness = dets[-1].timestamp - dets[i - 1].timestamp
            else:
                break

        return KinematicFeatures(velocity, angle, aspect_ratio, stillness)


class TrackFeatureManager:
    """Owns one sliding-window feature extractor per track_id. The Hub
    daemon calls update() every tick for every currently-tracked person,
    and prune() with the set of still-active track_ids so windows for
    people who've left frame don't leak memory forever."""

    def __init__(self, window_seconds: float = 3.0):
        self.window_seconds = window_seconds
        self._windows: dict[int, _SingleTrackWindow] = {}

    def update(self, track_id: int, detection: PersonDetection) -> None:
        if track_id not in self._windows:
            self._windows[track_id] = _SingleTrackWindow(self.window_seconds)
        self._windows[track_id].add(detection)

    def compute(self, track_id: int) -> KinematicFeatures:
        window = self._windows.get(track_id)
        if window is None:
            return KinematicFeatures(0.0, 0.0, 1.0, 0.0)
        return window.compute()

    def drop_track(self, track_id: int) -> None:
        self._windows.pop(track_id, None)

    def prune(self, active_track_ids: set[int]) -> None:
        for track_id in list(self._windows.keys()):
            if track_id not in active_track_ids:
                self.drop_track(track_id)
