from meridian_hub.vision.pose_types import Keypoint, PersonDetection
from meridian_hub.vision.tracker import IouTracker


def _det(bbox, t):
    return PersonDetection(keypoints=[Keypoint(0, 0, 0.9)] * 17, bbox=bbox, confidence=0.9, timestamp=t)


def test_assigns_stable_id_to_moving_person():
    tracker = IouTracker()
    tracks_1 = tracker.update([_det((10, 10, 50, 90), 0.0)])
    tracks_2 = tracker.update([_det((14, 10, 54, 90), 0.1)])  # small shift, same person
    assert tracks_1[0].track_id == tracks_2[0].track_id


def test_assigns_different_ids_to_two_people():
    tracker = IouTracker()
    tracks = tracker.update([
        _det((10, 10, 50, 90), 0.0),
        _det((200, 10, 240, 90), 0.0),
    ])
    ids = {t.track_id for t in tracks}
    assert len(ids) == 2


def test_track_survives_brief_occlusion():
    tracker = IouTracker(max_missed_frames=2)
    first = tracker.update([_det((10, 10, 50, 90), 0.0)])
    track_id = first[0].track_id
    tracker.update([])  # occluded for one tick
    reappeared = tracker.update([_det((12, 10, 52, 90), 0.2)])
    assert reappeared[0].track_id == track_id


def test_track_dropped_after_too_many_missed_frames():
    tracker = IouTracker(max_missed_frames=1)
    first = tracker.update([_det((10, 10, 50, 90), 0.0)])
    track_id = first[0].track_id
    tracker.update([])
    tracker.update([])  # exceeds max_missed_frames
    reappeared = tracker.update([_det((12, 10, 52, 90), 0.3)])
    assert reappeared[0].track_id != track_id
