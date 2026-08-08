from datetime import date, datetime, timezone

import numpy as np

from meridian_hub.capture.camera_registry import CameraRegistry, CameraRecord
from meridian_hub.activity_rollup import ActivityHistorySample, InMemoryActivityHistory, ResidentActivityRollupAggregator
from meridian_hub.events.event_engine import EventEngine
from meridian_hub.hub_daemon import HubDaemon
from meridian_hub.offline_queue.queue_store import QueueStore
from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES


def _standing_detection(t):
    kpts = [Keypoint(50.0, 50.0, 0.9) for _ in range(17)]
    kpts[KEYPOINT_NAMES.index("left_hip")] = Keypoint(45.0, 100.0, 0.9)
    kpts[KEYPOINT_NAMES.index("right_hip")] = Keypoint(55.0, 100.0, 0.9)
    kpts[KEYPOINT_NAMES.index("left_shoulder")] = Keypoint(45.0, 40.0, 0.9)
    kpts[KEYPOINT_NAMES.index("right_shoulder")] = Keypoint(55.0, 40.0, 0.9)
    kpts[KEYPOINT_NAMES.index("left_ankle")] = Keypoint(40.0, 150.0, 0.9)
    kpts[KEYPOINT_NAMES.index("right_ankle")] = Keypoint(60.0, 150.0, 0.9)
    return PersonDetection(keypoints=kpts, bbox=(30, 30, 70, 160), confidence=0.9, timestamp=t)


def _fallen_detection(t):
    kpts = [Keypoint(50.0, 150.0, 0.9) for _ in range(17)]
    # Shoulder and hip centers are offset horizontally (not vertically
    # stacked like standing) with a big hip-height jump from the standing
    # pose -- that's what makes torso_angle_degrees read as horizontal and
    # hip_vertical_velocity clear the fall-candidate threshold. Getting
    # this wrong (e.g. keeping hip/shoulder x-aligned) silently produces
    # torso_angle_degrees=0 ("upright"), which is what caused this test to
    # fail on the first attempt.
    kpts[KEYPOINT_NAMES.index("left_shoulder")] = Keypoint(10.0, 145.0, 0.9)
    kpts[KEYPOINT_NAMES.index("right_shoulder")] = Keypoint(30.0, 145.0, 0.9)
    kpts[KEYPOINT_NAMES.index("left_hip")] = Keypoint(70.0, 165.0, 0.9)
    kpts[KEYPOINT_NAMES.index("right_hip")] = Keypoint(90.0, 165.0, 0.9)
    kpts[KEYPOINT_NAMES.index("left_ankle")] = Keypoint(60.0, 168.0, 0.9)
    kpts[KEYPOINT_NAMES.index("right_ankle")] = Keypoint(100.0, 168.0, 0.9)
    # bbox overlaps the standing bbox enough (IoU ~0.33) for the tracker to
    # keep the same track_id across the fall -- a real person falling
    # doesn't teleport across the frame, their bbox shifts from tall-narrow
    # to short-wide while staying roughly centered in the same spot.
    return PersonDetection(keypoints=kpts, bbox=(10, 90, 90, 165), confidence=0.9, timestamp=t)


class _ScriptedPoseEstimator:
    """Returns pre-scripted detections per call instead of running a real
    model -- lets this test exercise the full daemon wiring (preprocess,
    tracker, features, fall state machine, validator, event engine,
    queue) without any camera or .onnx file."""

    input_height = 256
    input_width = 320

    def __init__(self, detections_per_call):
        self._calls = iter(detections_per_call)

    def estimate(self, preprocessed_frame, timestamp):
        return next(self._calls)


def _build_daemon(detections_per_call, *, activity_rollup=None):
    registry = CameraRegistry(db_path=":memory:")
    registry.register(CameraRecord(
        camera_id="cam-1", facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-1",
        source="0", privacy_state="active",
    ))
    daemon = HubDaemon(
        pose_estimator=_ScriptedPoseEstimator(detections_per_call),
        event_engine=EventEngine(clock=lambda: datetime(2026, 7, 2, 9, 0, 0, tzinfo=timezone.utc)),
        queue_store=QueueStore(db_path=":memory:"),
        camera_registry=registry,
        activity_rollup=activity_rollup,
    )
    return daemon


def test_standing_person_produces_no_events():
    daemon = _build_daemon([[_standing_detection(t)] for t in [0.0, 0.5, 1.0]])
    frame = np.zeros((10, 10, 3), dtype=np.uint8)
    events = []
    for t in [0.0, 0.5, 1.0]:
        events += daemon.process_frame("cam-1", frame, t)
    assert events == []


def test_fall_sequence_produces_confirmed_event_with_correct_mapping():
    frame = np.zeros((10, 10, 3), dtype=np.uint8)
    detections = [
        [_standing_detection(0.0)],
        [_fallen_detection(0.5)],
        [_fallen_detection(2.6)],
    ]
    daemon = _build_daemon(detections)
    events = []
    for t in [0.0, 0.5, 2.6]:
        events += daemon.process_frame("cam-1", frame, t)
    assert len(events) == 1
    event = events[0]
    assert event.event_type == "fall_confirmed"
    assert event.room_id == "room-1"
    assert event.resident_id == "res-1"
    assert event.camera_id == "cam-1"


def test_injected_activity_rollup_queues_only_completed_category_payloads():
    baseline = InMemoryActivityHistory([
        ActivityHistorySample("res-1", date(2026, 7, day), 4, None)
        for day in range(1, 8)
    ])
    aggregator = ResidentActivityRollupAggregator(baseline, timezone_name="UTC")
    day_one = [datetime(2026, 8, 1, 9 + index // 2, (index % 2) * 30, tzinfo=timezone.utc).timestamp() for index in range(8)]
    day_two = datetime(2026, 8, 2, 9, tzinfo=timezone.utc).timestamp()
    daemon = _build_daemon([[_standing_detection(t)] for t in [*day_one, day_two]], activity_rollup=aggregator)
    frame = np.zeros((10, 10, 3), dtype=np.uint8)

    for timestamp in [*day_one, day_two]:
        daemon.process_frame("cam-1", frame, timestamp)

    queued = daemon._queue_store.pending(now=day_two)
    payload = queued[0].payload["_meridian_delivery"]["payload"]
    assert queued[0].payload["_meridian_delivery"]["destination"] == "record-resident-activity-rollup"
    assert payload["p_daytime_pattern"] == "lower_than_usual"
    assert set(payload) == {
        "p_rollup_date", "p_daytime_pattern", "p_nighttime_pattern",
        "p_baseline_status", "p_observation_status",
    }
