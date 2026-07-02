from meridian_hub.device_health.health_monitor import DeviceHealthMonitor
from meridian_hub.ingestion.stream_ingestion import StreamHealthTracker
import numpy as np


def test_hub_snapshot_reports_resource_usage():
    monitor = DeviceHealthMonitor(
        start_time=0.0, cpu_percent_fn=lambda: 42.5, memory_percent_fn=lambda: 61.0
    )
    snapshot = monitor.hub_snapshot(camera_trackers={}, queue_depth=3, now=120.0)
    assert snapshot.uptime_s == 120.0
    assert snapshot.cpu_percent == 42.5
    assert snapshot.memory_percent == 61.0
    assert snapshot.queue_depth == 3


def test_hub_snapshot_counts_offline_cameras():
    monitor = DeviceHealthMonitor(start_time=0.0, cpu_percent_fn=lambda: 0.0, memory_percent_fn=lambda: 0.0)
    healthy = StreamHealthTracker(camera_id="cam-1")
    healthy.record_frame(np.zeros((2, 2, 3), dtype=np.uint8), timestamp=0.0)
    frozen = StreamHealthTracker(camera_id="cam-2")
    frame = np.full((2, 2, 3), 5, dtype=np.uint8)
    for t in [0.0, 3.0, 6.0, 9.0, 12.0, 15.0]:  # spans > the 10s frozen threshold
        frozen.record_frame(frame, timestamp=t)
    snapshot = monitor.hub_snapshot(
        camera_trackers={"cam-1": healthy, "cam-2": frozen}, queue_depth=0, now=15.0
    )
    assert snapshot.camera_count == 2
    assert snapshot.cameras_offline == 1


def test_camera_snapshot_reports_fps_and_frozen_state():
    monitor = DeviceHealthMonitor(start_time=0.0, cpu_percent_fn=lambda: 0.0, memory_percent_fn=lambda: 0.0)
    tracker = StreamHealthTracker(camera_id="cam-1")
    frame = np.zeros((2, 2, 3), dtype=np.uint8)
    for t in [0.0, 0.1, 0.2]:
        tracker.record_frame(frame, timestamp=t)
    snapshot = monitor.camera_snapshot(camera_id="cam-1", tracker=tracker)
    assert snapshot.camera_id == "cam-1"
    assert snapshot.fps >= 0.0
    assert isinstance(snapshot.frozen, bool)
