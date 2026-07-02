from meridian_hub.classifiers.long_lie import LongLieDetector


def test_no_event_for_brief_floor_time():
    detector = LongLieDetector(track_id=1, floor_threshold_seconds=300.0)
    event = None
    for t in [0.0, 60.0, 120.0]:
        event = detector.update(floor_level=True, timestamp=t)
    assert event is None


def test_fires_after_sustained_floor_level_duration():
    detector = LongLieDetector(track_id=1, floor_threshold_seconds=300.0)
    event = None
    for t in [0.0, 100.0, 200.0, 301.0]:
        event = detector.update(floor_level=True, timestamp=t)
    assert event is not None
    assert event.track_id == 1


def test_fires_only_once_per_episode():
    detector = LongLieDetector(track_id=1, floor_threshold_seconds=100.0)
    events = [detector.update(floor_level=True, timestamp=t) for t in [0.0, 50.0, 101.0, 150.0, 200.0]]
    fired = [e for e in events if e is not None]
    assert len(fired) == 1


def test_resets_when_person_gets_up():
    detector = LongLieDetector(track_id=1, floor_threshold_seconds=100.0)
    detector.update(floor_level=True, timestamp=0.0)
    detector.update(floor_level=True, timestamp=50.0)
    detector.update(floor_level=False, timestamp=60.0)  # got up
    event = detector.update(floor_level=True, timestamp=161.0)  # back down, but only 101s since getting up
    assert event is None
