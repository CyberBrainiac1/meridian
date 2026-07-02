from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES
from meridian_hub.features.feature_window import TrackFeatureManager


def _detection(t, hip_y, shoulder_y, hip_x=50.0, shoulder_x=50.0):
    kpts = [Keypoint(x=0.0, y=0.0, confidence=0.9) for _ in range(17)]
    for name, x, y in [
        ("left_hip", hip_x - 5, hip_y), ("right_hip", hip_x + 5, hip_y),
        ("left_shoulder", shoulder_x - 5, shoulder_y), ("right_shoulder", shoulder_x + 5, shoulder_y),
        ("left_ankle", hip_x - 10, hip_y + 50), ("right_ankle", hip_x + 10, hip_y + 50),
    ]:
        kpts[KEYPOINT_NAMES.index(name)] = Keypoint(x=x, y=y, confidence=0.9)
    return PersonDetection(keypoints=kpts, bbox=(0, 0, 100, 200), confidence=0.9, timestamp=t)


def test_tracks_are_independent():
    manager = TrackFeatureManager()
    manager.update(track_id=1, detection=_detection(0.0, hip_y=100.0, shoulder_y=40.0))
    manager.update(track_id=2, detection=_detection(0.0, hip_y=180.0, shoulder_y=175.0))
    f1 = manager.compute(track_id=1)
    f2 = manager.compute(track_id=2)
    assert f1.torso_angle_degrees < 20.0
    assert f2.torso_angle_degrees >= 0.0


def test_drop_track_removes_its_window():
    manager = TrackFeatureManager()
    manager.update(track_id=1, detection=_detection(0.0, hip_y=100.0, shoulder_y=40.0))
    manager.drop_track(1)
    assert manager.compute(track_id=1).hip_vertical_velocity == 0.0


def test_prune_removes_stale_tracks():
    manager = TrackFeatureManager()
    manager.update(track_id=1, detection=_detection(0.0, hip_y=100.0, shoulder_y=40.0))
    manager.update(track_id=2, detection=_detection(0.0, hip_y=100.0, shoulder_y=40.0))
    manager.prune(active_track_ids={2})
    assert manager.compute(track_id=1).hip_vertical_velocity == 0.0
