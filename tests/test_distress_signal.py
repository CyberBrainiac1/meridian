from meridian_hub.classifiers.distress_signal import DistressSignalDetector
from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES


def _detection(t, arms_raised):
    kpts = [Keypoint(0.0, 100.0, 0.9) for _ in range(17)]
    kpts[KEYPOINT_NAMES.index("left_shoulder")] = Keypoint(40.0, 50.0, 0.9)
    kpts[KEYPOINT_NAMES.index("right_shoulder")] = Keypoint(60.0, 50.0, 0.9)
    wrist_y = 20.0 if arms_raised else 90.0  # above (smaller y) or below shoulders
    kpts[KEYPOINT_NAMES.index("left_wrist")] = Keypoint(35.0, wrist_y, 0.9)
    kpts[KEYPOINT_NAMES.index("right_wrist")] = Keypoint(65.0, wrist_y, 0.9)
    return PersonDetection(keypoints=kpts, bbox=(0, 0, 100, 150), confidence=0.9, timestamp=t)


def test_no_signal_when_arms_down():
    detector = DistressSignalDetector(track_id=1, hold_seconds=2.0)
    event = detector.update(_detection(0.0, arms_raised=False), timestamp=0.0)
    assert event is None


def test_no_signal_for_brief_raise():
    detector = DistressSignalDetector(track_id=1, hold_seconds=2.0)
    detector.update(_detection(0.0, arms_raised=True), timestamp=0.0)
    event = detector.update(_detection(0.5, arms_raised=True), timestamp=0.5)
    assert event is None


def test_fires_after_sustained_raise():
    detector = DistressSignalDetector(track_id=1, hold_seconds=2.0)
    detector.update(_detection(0.0, arms_raised=True), timestamp=0.0)
    event = detector.update(_detection(2.1, arms_raised=True), timestamp=2.1)
    assert event is not None
    assert event.track_id == 1
    assert event.hold_duration_seconds >= 2.0


def test_fires_only_once_per_episode():
    detector = DistressSignalDetector(track_id=1, hold_seconds=1.0)
    events = [
        detector.update(_detection(t, arms_raised=True), timestamp=t)
        for t in [0.0, 0.5, 1.1, 1.5, 2.0]
    ]
    fired = [e for e in events if e is not None]
    assert len(fired) == 1


def test_resets_when_arms_lowered():
    detector = DistressSignalDetector(track_id=1, hold_seconds=1.0)
    detector.update(_detection(0.0, arms_raised=True), timestamp=0.0)
    detector.update(_detection(0.5, arms_raised=False), timestamp=0.5)  # lowered before threshold
    event = detector.update(_detection(1.1, arms_raised=True), timestamp=1.1)  # only 0s since re-raise
    assert event is None
