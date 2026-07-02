from meridian_hub.dementia_safety.zone_rules import Zone
from meridian_hub.medication.visit_verification import MedicationVisitVerifier, MedicationWindow
from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES
from meridian_hub.vision.tracker import TrackedPerson

MED_ZONE = Zone(zone_id="med-cart-1", zone_type="safe_zone", bbox=(0.0, 0.0, 30.0, 30.0))


def _person(track_id, x, y):
    kpts = [Keypoint(0.0, 0.0, 0.9) for _ in range(17)]
    kpts[KEYPOINT_NAMES.index("left_hip")] = Keypoint(x - 2, y, 0.9)
    kpts[KEYPOINT_NAMES.index("right_hip")] = Keypoint(x + 2, y, 0.9)
    det = PersonDetection(keypoints=kpts, bbox=(0, 0, 10, 10), confidence=0.9, timestamp=0.0)
    return TrackedPerson(track_id=track_id, detection=det)


def test_window_not_visited_by_default():
    verifier = MedicationVisitVerifier(zone=MED_ZONE, min_dwell_seconds=5.0)
    window = MedicationWindow("morning", start_timestamp=0.0, end_timestamp=3600.0)
    result = verifier.check_window(window)
    assert result.visited is False


def test_sustained_dwell_confirms_visit():
    verifier = MedicationVisitVerifier(zone=MED_ZONE, min_dwell_seconds=5.0)
    for t in [0.0, 2.0, 4.0, 6.0]:  # 6s of continuous dwell inside the zone
        verifier.update([_person(1, 15, 15)], timestamp=t)
    window = MedicationWindow("morning", start_timestamp=0.0, end_timestamp=3600.0)
    result = verifier.check_window(window)
    assert result.visited is True
    assert result.visit_timestamp == 6.0


def test_brief_pass_through_does_not_confirm_visit():
    verifier = MedicationVisitVerifier(zone=MED_ZONE, min_dwell_seconds=5.0)
    verifier.update([_person(1, 15, 15)], timestamp=0.0)
    verifier.update([_person(1, 15, 15)], timestamp=1.0)  # only 1s dwell, then leaves
    verifier.update([_person(1, 100, 100)], timestamp=2.0)
    window = MedicationWindow("morning", start_timestamp=0.0, end_timestamp=3600.0)
    result = verifier.check_window(window)
    assert result.visited is False


def test_visit_outside_window_not_counted():
    verifier = MedicationVisitVerifier(zone=MED_ZONE, min_dwell_seconds=5.0)
    for t in [10000.0, 10002.0, 10006.0]:
        verifier.update([_person(1, 15, 15)], timestamp=t)
    window = MedicationWindow("morning", start_timestamp=0.0, end_timestamp=3600.0)
    result = verifier.check_window(window)
    assert result.visited is False
