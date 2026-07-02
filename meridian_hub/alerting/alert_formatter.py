from meridian_hub.events.schemas import MeridianEvent

_EVENT_COPY = {
    "fall_confirmed": "{resident} may have fallen in {room}. Staff has been alerted.",
    "fall_suspected": "Possible fall for {resident} in {room} -- verifying now.",
    "long_lie": "{resident} has been on the floor in {room} longer than expected.",
    "unusual_inactivity": "{resident} hasn't moved as expected in {room}.",
    "wandering": "{resident} is pacing near an exit in {room}.",
    "exit_risk": "{resident} is near an exit in {room}, unaccompanied.",
    "night_activity": "{resident} may need attention in {room} overnight.",
    "device_offline": "The camera in {room} has gone offline.",
    "stream_degraded": "The camera stream in {room} has degraded.",
    "medication_visit_missing": "{resident}'s scheduled medication visit in {room} hasn't been confirmed.",
    "visitor_arrival": "A visitor arrived at {room}.",
    "visitor_departure": "A visitor left {room}.",
}

_DEFAULT_TEMPLATE = "{resident}: {event_type} in {room}."


def format_alert_message(event: MeridianEvent, resident_display_name: str | None = None) -> str:
    """PRD's resident-first copy principle: "Maggie needs help in Room
    12," never "Event #4471 triggered." The Hub only knows resident_id,
    not a display name (that's the app/backend's data) -- callers with a
    real name should pass resident_display_name; otherwise this falls
    back to the ID rather than guessing, which is honest about what the
    Hub actually knows."""
    resident = resident_display_name or event.resident_id or "A resident"
    template = _EVENT_COPY.get(event.event_type, _DEFAULT_TEMPLATE)
    return template.format(resident=resident, room=event.room_id, event_type=event.event_type)
