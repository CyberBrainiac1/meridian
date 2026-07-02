from meridian_hub.dementia_safety.zone_rules import DementiaSafetyMonitor, Zone
from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES
from meridian_hub.vision.tracker import TrackedPerson


def _person(track_id, hip_x, hip_y, t):
    kpts = [Keypoint(0.0, 0.0, 0.9) for _ in range(17)]
    kpts[KEYPOINT_NAMES.index("left_hip")] = Keypoint(hip_x - 2, hip_y, 0.9)
    kpts[KEYPOINT_NAMES.index("right_hip")] = Keypoint(hip_x + 2, hip_y, 0.9)
    det = PersonDetection(keypoints=kpts, bbox=(hip_x - 10, hip_y - 10, hip_x + 10, hip_y + 10), confidence=0.9, timestamp=t)
    return TrackedPerson(track_id=track_id, detection=det)


DOOR = Zone(zone_id="exit-1", zone_type="exit_door", bbox=(0.0, 0.0, 20.0, 20.0))
RESTRICTED = Zone(zone_id="restricted-1", zone_type="restricted", bbox=(100.0, 100.0, 120.0, 120.0))


def test_door_approach_fires_on_entry():
    monitor = DementiaSafetyMonitor(zones=[DOOR])
    outside = [_person(1, 50, 50, 0.0)]
    inside = [_person(1, 10, 10, 1.0)]
    monitor.update(outside, timestamp=0.0)
    events = monitor.update(inside, timestamp=1.0)
    assert any(e.event_type == "door_approach" for e in events)


def test_unaccompanied_exit_fires_when_alone():
    monitor = DementiaSafetyMonitor(zones=[DOOR])
    monitor.update([_person(1, 50, 50, 0.0)], timestamp=0.0)
    events = monitor.update([_person(1, 10, 10, 1.0)], timestamp=1.0)
    assert any(e.event_type == "unaccompanied_exit" for e in events)


def test_no_unaccompanied_exit_when_caregiver_present():
    monitor = DementiaSafetyMonitor(zones=[DOOR])
    monitor.update([_person(1, 50, 50, 0.0), _person(2, 60, 60, 0.0)], timestamp=0.0)
    events = monitor.update([_person(1, 10, 10, 1.0), _person(2, 15, 60, 1.0)], timestamp=1.0)
    assert any(e.event_type == "door_approach" for e in events)
    assert not any(e.event_type == "unaccompanied_exit" for e in events)


def test_door_crossing_fires_on_exit():
    monitor = DementiaSafetyMonitor(zones=[DOOR])
    monitor.update([_person(1, 50, 50, 0.0)], timestamp=0.0)
    monitor.update([_person(1, 10, 10, 1.0)], timestamp=1.0)  # enters
    events = monitor.update([_person(1, 50, 50, 2.0)], timestamp=2.0)  # leaves
    assert any(e.event_type == "door_crossing" for e in events)


def test_restricted_zone_entry_fires():
    monitor = DementiaSafetyMonitor(zones=[RESTRICTED])
    monitor.update([_person(1, 50, 50, 0.0)], timestamp=0.0)
    events = monitor.update([_person(1, 110, 110, 1.0)], timestamp=1.0)
    assert any(e.event_type == "restricted_zone_entry" for e in events)


def test_pacing_detected_after_repeated_entries():
    monitor = DementiaSafetyMonitor(zones=[DOOR], pacing_window_seconds=60.0, pacing_entry_threshold=3)
    events = []
    # enter, leave, enter, leave, enter -- 3 entries within the window
    for t, (x, y) in enumerate([(10, 10), (50, 50), (10, 10), (50, 50), (10, 10)]):
        events += monitor.update([_person(1, x, y, float(t))], timestamp=float(t))
    assert any(e.event_type == "pacing_detected" for e in events)
