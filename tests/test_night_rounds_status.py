from meridian_hub.dementia_safety.zone_rules import Zone
from meridian_hub.night_rounds.status_classifier import NightRoundsStatusClassifier, RoomStatus
from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES
from meridian_hub.vision.tracker import TrackedPerson

BED_ZONE = Zone(zone_id="bed-1", zone_type="safe_zone", bbox=(0.0, 0.0, 50.0, 50.0))


def _person_at(hip_x, hip_y):
    kpts = [Keypoint(0.0, 0.0, 0.9) for _ in range(17)]
    kpts[KEYPOINT_NAMES.index("left_hip")] = Keypoint(hip_x - 2, hip_y, 0.9)
    kpts[KEYPOINT_NAMES.index("right_hip")] = Keypoint(hip_x + 2, hip_y, 0.9)
    det = PersonDetection(keypoints=kpts, bbox=(0, 0, 10, 10), confidence=0.9, timestamp=0.0)
    return TrackedPerson(track_id=1, detection=det)


def test_camera_unavailable_takes_priority():
    classifier = NightRoundsStatusClassifier(bed_zone=BED_ZONE)
    status = classifier.classify([_person_at(25, 25)], camera_available=False, fall_suspected=True)
    assert status == RoomStatus.CAMERA_UNAVAILABLE


def test_fall_suspected_reports_possible_distress():
    classifier = NightRoundsStatusClassifier(bed_zone=BED_ZONE)
    status = classifier.classify([_person_at(100, 100)], camera_available=True, fall_suspected=True)
    assert status == RoomStatus.POSSIBLE_DISTRESS


def test_no_one_visible_reports_not_visible():
    classifier = NightRoundsStatusClassifier(bed_zone=BED_ZONE)
    status = classifier.classify([], camera_available=True, fall_suspected=False)
    assert status == RoomStatus.NOT_VISIBLE


def test_person_in_bed_zone_reports_in_bed():
    classifier = NightRoundsStatusClassifier(bed_zone=BED_ZONE)
    status = classifier.classify([_person_at(25, 25)], camera_available=True, fall_suspected=False)
    assert status == RoomStatus.IN_BED


def test_person_outside_bed_moving_reports_moving_normally():
    classifier = NightRoundsStatusClassifier(bed_zone=BED_ZONE)
    status = classifier.classify([_person_at(100, 100)], camera_available=True, fall_suspected=False, movement_speed=30.0)
    assert status == RoomStatus.MOVING_NORMALLY


def test_person_outside_bed_still_reports_out_of_bed():
    classifier = NightRoundsStatusClassifier(bed_zone=BED_ZONE)
    status = classifier.classify([_person_at(100, 100)], camera_available=True, fall_suspected=False, movement_speed=0.0)
    assert status == RoomStatus.OUT_OF_BED
