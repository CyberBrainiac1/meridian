import numpy as np

from meridian_hub.ingestion.stream_ingestion import StreamHealthTracker


def test_fps_computed_from_frame_timestamps():
    tracker = StreamHealthTracker(camera_id="cam-1")
    frame = np.zeros((4, 4, 3), dtype=np.uint8)
    for t in [0.0, 0.1, 0.2, 0.3, 0.4]:
        tracker.record_frame(frame, timestamp=t)
    assert 9.0 < tracker.current_fps() < 11.0


def test_detects_frozen_stream():
    tracker = StreamHealthTracker(camera_id="cam-1")
    frame = np.full((4, 4, 3), 7, dtype=np.uint8)
    for t in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]:
        tracker.record_frame(frame, timestamp=t)
    assert tracker.is_frozen(threshold_seconds=3.0) is True


def test_not_frozen_when_frames_change():
    tracker = StreamHealthTracker(camera_id="cam-1")
    for i, t in enumerate([0.0, 1.0, 2.0, 3.0]):
        frame = np.full((4, 4, 3), i, dtype=np.uint8)
        tracker.record_frame(frame, timestamp=t)
    assert tracker.is_frozen(threshold_seconds=3.0) is False
