from meridian_hub.features.feature_window import KinematicFeatures
from meridian_hub.classifiers.fall_state_machine import FallStateMachine
from meridian_hub.classifiers.fall_types import FallState


def _features(velocity=0.0, angle=5.0, aspect_ratio=0.4, stillness=0.0):
    return KinematicFeatures(velocity, angle, aspect_ratio, stillness)


def test_stays_normal_when_standing_still():
    machine = FallStateMachine(track_id=1)
    event = None
    for t in [0.0, 0.5, 1.0]:
        event = machine.update(_features(velocity=0.0, angle=5.0), timestamp=t)
    assert machine.state == FallState.NORMAL
    assert event is None


def test_confirms_fall_on_drop_plus_sustained_stillness_horizontal():
    machine = FallStateMachine(track_id=1)
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=0.0)
    machine.update(_features(velocity=250.0, angle=70.0, aspect_ratio=1.8, stillness=0.0), timestamp=0.5)
    event = machine.update(_features(velocity=0.0, angle=75.0, aspect_ratio=1.8, stillness=2.1), timestamp=2.6)
    assert machine.state == FallState.CONFIRMED
    assert event is not None
    assert event.state == FallState.CONFIRMED
    assert event.track_id == 1


def test_suspected_when_signals_borderline():
    machine = FallStateMachine(track_id=1)
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=0.0)
    machine.update(_features(velocity=140.0, angle=40.0, aspect_ratio=0.9, stillness=0.0), timestamp=0.5)
    event = machine.update(_features(velocity=5.0, angle=42.0, aspect_ratio=0.9, stillness=0.6), timestamp=1.5)
    assert machine.state == FallState.SUSPECTED
    assert event is not None
    assert event.state == FallState.SUSPECTED


def test_clears_when_recovers_without_crossing_ambiguous_band():
    machine = FallStateMachine(track_id=1)
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=0.0)
    machine.update(_features(velocity=130.0, angle=32.0, aspect_ratio=0.6, stillness=0.0), timestamp=0.3)
    event = machine.update(_features(velocity=0.0, angle=8.0, aspect_ratio=0.4, stillness=0.0), timestamp=0.6)
    assert machine.state == FallState.NORMAL
    assert event is None or event.state == FallState.CLEARED


def test_confirmed_path_never_requires_any_io():
    import inspect
    source = inspect.getsource(FallStateMachine.update)
    for banned in ("requests", "socket", "sqlite3", "open("):
        assert banned not in source


def _confirm_a_fall(machine, t0=0.0):
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=t0)
    machine.update(_features(velocity=250.0, angle=70.0, aspect_ratio=1.8, stillness=0.0), timestamp=t0 + 0.5)
    event = machine.update(_features(velocity=0.0, angle=75.0, aspect_ratio=1.8, stillness=2.1), timestamp=t0 + 2.6)
    assert event is not None and event.state == FallState.CONFIRMED


def test_rearms_after_confirmed_when_person_gets_back_on_feet():
    machine = FallStateMachine(track_id=1)
    _confirm_a_fall(machine, t0=0.0)
    assert machine.state == FallState.CONFIRMED

    # still on the floor -> stays CONFIRMED, no new event (no alert spam)
    assert machine.update(_features(velocity=0.0, angle=75.0, aspect_ratio=1.8, stillness=3.0), timestamp=4.0) is None
    assert machine.state == FallState.CONFIRMED

    # back on their feet -> CLEARED + returns to NORMAL (re-armed)
    cleared = machine.update(_features(velocity=-10.0, angle=6.0, aspect_ratio=0.4, stillness=0.0), timestamp=6.0)
    assert cleared is not None and cleared.state == FallState.CLEARED
    assert machine.state == FallState.NORMAL


def test_second_fall_is_detected_after_recovery():
    machine = FallStateMachine(track_id=1)
    _confirm_a_fall(machine, t0=0.0)
    machine.update(_features(velocity=-10.0, angle=6.0, aspect_ratio=0.4, stillness=0.0), timestamp=6.0)  # recover
    assert machine.state == FallState.NORMAL

    # a genuinely separate second fall must confirm again, not stay silent
    _confirm_a_fall(machine, t0=10.0)
    assert machine.state == FallState.CONFIRMED


def test_suspected_also_rearms_on_recovery():
    machine = FallStateMachine(track_id=1)
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=0.0)
    machine.update(_features(velocity=140.0, angle=40.0, aspect_ratio=0.9, stillness=0.0), timestamp=0.5)
    machine.update(_features(velocity=5.0, angle=42.0, aspect_ratio=0.9, stillness=0.6), timestamp=1.5)
    assert machine.state == FallState.SUSPECTED
    cleared = machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4, stillness=0.0), timestamp=4.0)
    assert cleared is not None and cleared.state == FallState.CLEARED
    assert machine.state == FallState.NORMAL
