from collections.abc import Callable
from dataclasses import dataclass

import psutil

from meridian_hub.ingestion.stream_ingestion import StreamHealthTracker

FROZEN_THRESHOLD_SECONDS = 10.0


@dataclass(frozen=True)
class HubHealthSnapshot:
    uptime_s: float
    cpu_percent: float
    memory_percent: float
    camera_count: int
    cameras_offline: int
    queue_depth: int


@dataclass(frozen=True)
class CameraHealthSnapshot:
    camera_id: str
    fps: float
    frozen: bool


class DeviceHealthMonitor:
    """PRD sections 19.2/19.3: Hub-level and per-camera health payloads.
    CPU/memory readers are injected so tests don't depend on real system
    load (mirrors the clock-injection pattern in EventEngine)."""

    def __init__(
        self, start_time: float,
        cpu_percent_fn: Callable[[], float] = lambda: psutil.cpu_percent(),
        memory_percent_fn: Callable[[], float] = lambda: psutil.virtual_memory().percent,
    ):
        self._start_time = start_time
        self._cpu_percent_fn = cpu_percent_fn
        self._memory_percent_fn = memory_percent_fn

    def hub_snapshot(
        self, camera_trackers: dict[str, StreamHealthTracker], queue_depth: int, now: float,
    ) -> HubHealthSnapshot:
        offline = sum(
            1 for tracker in camera_trackers.values()
            if tracker.is_frozen(threshold_seconds=FROZEN_THRESHOLD_SECONDS)
        )
        return HubHealthSnapshot(
            uptime_s=now - self._start_time,
            cpu_percent=self._cpu_percent_fn(),
            memory_percent=self._memory_percent_fn(),
            camera_count=len(camera_trackers),
            cameras_offline=offline,
            queue_depth=queue_depth,
        )

    def camera_snapshot(self, camera_id: str, tracker: StreamHealthTracker) -> CameraHealthSnapshot:
        return CameraHealthSnapshot(
            camera_id=camera_id,
            fps=tracker.current_fps(),
            frozen=tracker.is_frozen(threshold_seconds=FROZEN_THRESHOLD_SECONDS),
        )
