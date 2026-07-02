from datetime import datetime, timezone

from meridian_hub.alerting.alert_formatter import format_alert_message
from meridian_hub.events.schemas import MeridianEvent


def _event(event_type="fall_confirmed", resident_id="res-1", room_id="room-12"):
    return MeridianEvent(
        event_id="evt-1", facility_id="fac-1", building_id="bld-1", floor_id="flr-1",
        room_id=room_id, resident_id=resident_id, camera_id="cam-1", event_type=event_type,
        severity="critical", confidence=0.9,
        detected_at=datetime(2026, 7, 2, 9, 0, 0, tzinfo=timezone.utc),
        generated_at=datetime(2026, 7, 2, 9, 0, 1, tzinfo=timezone.utc),
        reason_codes=["rapid_vertical_drop"],
    )


def test_uses_resident_display_name_when_provided():
    message = format_alert_message(_event(), resident_display_name="Maggie")
    assert message == "Maggie may have fallen in room-12. Staff has been alerted."


def test_falls_back_to_resident_id_without_display_name():
    message = format_alert_message(_event())
    assert "res-1" in message
    assert "room-12" in message


def test_no_event_number_or_jargon_in_message():
    message = format_alert_message(_event(), resident_display_name="Maggie")
    assert "evt-1" not in message
    assert "Event #" not in message


def test_unknown_event_type_uses_default_template():
    message = format_alert_message(_event(event_type="fall_suspected"), resident_display_name="Maggie")
    assert message == "Possible fall for Maggie in room-12 -- verifying now."


def test_every_prd_event_type_has_a_template():
    from meridian_hub.alerting.alert_formatter import _EVENT_COPY
    prd_event_types = [
        "fall_suspected", "fall_confirmed", "long_lie", "unusual_inactivity",
        "wandering", "exit_risk", "night_activity", "device_offline",
        "stream_degraded", "medication_visit_missing", "visitor_arrival", "visitor_departure",
    ]
    for event_type in prd_event_types:
        assert event_type in _EVENT_COPY
