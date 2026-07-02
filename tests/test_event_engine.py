from datetime import datetime, timezone

from meridian_hub.events.event_engine import EventEngine
from meridian_hub.events.schemas import MeridianEvent


def _clock_sequence(timestamps):
    it = iter(timestamps)
    return lambda: next(it)


def test_first_alert_for_new_incident_emits_immediately():
    engine = EventEngine(clock=_clock_sequence([datetime(2026, 7, 2, 9, 42, 20, tzinfo=timezone.utc)]))
    event = engine.emit_fall_event(
        camera_id="cam-1", track_id=1, facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-1",
        event_type="fall_confirmed", severity="critical", confidence=0.94,
        detected_at=datetime(2026, 7, 2, 9, 42, 18, tzinfo=timezone.utc),
        reason_codes=["rapid_vertical_drop", "horizontal_torso"],
    )
    assert event is not None
    assert isinstance(event, MeridianEvent)
    assert event.status == "open"
    assert event.event_type == "fall_confirmed"
    assert event.schema_version == "1.0"


def test_duplicate_of_open_incident_is_suppressed():
    engine = EventEngine(clock=_clock_sequence([
        datetime(2026, 7, 2, 9, 42, 20, tzinfo=timezone.utc),
        datetime(2026, 7, 2, 9, 42, 21, tzinfo=timezone.utc),
    ]))
    kwargs = dict(
        camera_id="cam-1", track_id=1, facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-1",
        event_type="fall_confirmed", severity="critical", confidence=0.94,
        detected_at=datetime(2026, 7, 2, 9, 42, 18, tzinfo=timezone.utc),
        reason_codes=["rapid_vertical_drop"],
    )
    first = engine.emit_fall_event(**kwargs)
    second = engine.emit_fall_event(**kwargs)
    assert first is not None
    assert second is None


def test_new_incident_after_resolve_emits_again():
    engine = EventEngine(clock=_clock_sequence([
        datetime(2026, 7, 2, 9, 42, 20, tzinfo=timezone.utc),
        datetime(2026, 7, 2, 10, 0, 0, tzinfo=timezone.utc),
    ]))
    kwargs = dict(
        camera_id="cam-1", track_id=1, facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-1",
        event_type="fall_confirmed", severity="critical", confidence=0.94,
        detected_at=datetime(2026, 7, 2, 9, 42, 18, tzinfo=timezone.utc),
        reason_codes=["rapid_vertical_drop"],
    )
    first = engine.emit_fall_event(**kwargs)
    engine.resolve(camera_id="cam-1", track_id=1, event_type="fall_confirmed")
    second = engine.emit_fall_event(**kwargs)
    assert first is not None
    assert second is not None
    assert first.event_id != second.event_id


def test_event_serializes_to_prd_schema_shape():
    engine = EventEngine(clock=_clock_sequence([datetime(2026, 7, 2, 9, 42, 20, tzinfo=timezone.utc)]))
    event = engine.emit_fall_event(
        camera_id="cam-1", track_id=1, facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-1",
        event_type="fall_confirmed", severity="critical", confidence=0.94,
        detected_at=datetime(2026, 7, 2, 9, 42, 18, tzinfo=timezone.utc),
        reason_codes=["rapid_vertical_drop"],
    )
    payload = event.model_dump(mode="json")
    for key in ["event_id", "schema_version", "facility_id", "building_id", "floor_id",
                "room_id", "resident_id", "camera_id", "event_type", "severity",
                "confidence", "detected_at", "generated_at", "status", "reason_codes", "evidence"]:
        assert key in payload
