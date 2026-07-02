from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES


def _detection(hip_y=100.0, shoulder_y=40.0, confidence=0.9):
    kpts = [Keypoint(x=50.0, y=50.0, confidence=0.9) for _ in range(17)]
    for name, y in [("left_hip", hip_y), ("right_hip", hip_y),
                    ("left_shoulder", shoulder_y), ("right_shoulder", shoulder_y)]:
        i = KEYPOINT_NAMES.index(name)
        kpts[i] = Keypoint(x=kpts[i].x, y=y, confidence=0.9)
    return PersonDetection(keypoints=kpts, bbox=(10.0, shoulder_y - 10, 90.0, hip_y + 60), confidence=confidence, timestamp=1.0)


def test_person_detection_keypoint_lookup():
    det = _detection()
    assert det.get("left_hip").y == 100.0


def test_person_detection_hip_center():
    det = _detection(hip_y=120.0)
    cx, cy = det.hip_center()
    assert cy == 120.0


def test_person_detection_bbox_iou():
    a = PersonDetection(keypoints=[Keypoint(0, 0, 0.9)] * 17, bbox=(0.0, 0.0, 10.0, 10.0), confidence=0.9, timestamp=0.0)
    b = PersonDetection(keypoints=[Keypoint(0, 0, 0.9)] * 17, bbox=(5.0, 5.0, 15.0, 15.0), confidence=0.9, timestamp=0.0)
    c = PersonDetection(keypoints=[Keypoint(0, 0, 0.9)] * 17, bbox=(100.0, 100.0, 110.0, 110.0), confidence=0.9, timestamp=0.0)
    assert a.iou(b) > 0.1
    assert a.iou(c) == 0.0
