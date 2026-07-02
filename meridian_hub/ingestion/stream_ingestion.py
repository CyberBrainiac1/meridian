from collections import deque

import numpy as np


class StreamHealthTracker:
    """Per-camera FPS measurement and frozen-frame detection (PRD section
    15.2). Frozen-frame detection compares frame content, not just
    presence of new frames, so a stuck camera producing repeated identical
    frames is caught even if reads keep succeeding."""

    def __init__(self, camera_id: str, window_seconds: float = 5.0):
        self.camera_id = camera_id
        self.window_seconds = window_seconds
        self._timestamps: deque[float] = deque()
        self._last_frame: np.ndarray | None = None
        self._last_change_timestamp: float | None = None

    def record_frame(self, frame: np.ndarray, timestamp: float) -> None:
        self._timestamps.append(timestamp)
        cutoff = timestamp - self.window_seconds
        while self._timestamps and self._timestamps[0] < cutoff:
            self._timestamps.popleft()

        if self._last_frame is None or not np.array_equal(frame, self._last_frame):
            self._last_change_timestamp = timestamp
        self._last_frame = frame

    def current_fps(self) -> float:
        if len(self._timestamps) < 2:
            return 0.0
        span = self._timestamps[-1] - self._timestamps[0]
        return (len(self._timestamps) - 1) / span if span > 0 else 0.0

    def is_frozen(self, threshold_seconds: float) -> bool:
        if self._last_change_timestamp is None or not self._timestamps:
            return False
        return (self._timestamps[-1] - self._last_change_timestamp) >= threshold_seconds
