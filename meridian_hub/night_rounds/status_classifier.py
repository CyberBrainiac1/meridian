from enum import Enum, auto

from meridian_hub.dementia_safety.zone_rules import Zone
from meridian_hub.vision.tracker import TrackedPerson

MOVEMENT_THRESHOLD = 15.0  # px/sec -- above this, treat as intentional movement, not just sensor noise


class RoomStatus(Enum):
    IN_BED = auto()
    MOVING_NORMALLY = auto()
    OUT_OF_BED = auto()
    NOT_VISIBLE = auto()
    CAMERA_UNAVAILABLE = auto()
    POSSIBLE_DISTRESS = auto()


class NightRoundsStatusClassifier:
    """PRD section 8.14: passive room-status check that assists overnight
    rounds, never replaces them (explicit PRD requirement). Produces one
    of six states per check -- deliberately simple and explainable, since
    this is meant to reduce unnecessary wake-the-resident checks, not
    introduce a new opaque system staff have to trust blindly."""

    def __init__(self, bed_zone: Zone):
        self.bed_zone = bed_zone

    def classify(
        self, tracked_people: list[TrackedPerson], camera_available: bool,
        fall_suspected: bool, movement_speed: float = 0.0,
    ) -> RoomStatus:
        if not camera_available:
            return RoomStatus.CAMERA_UNAVAILABLE
        if fall_suspected:
            return RoomStatus.POSSIBLE_DISTRESS
        if not tracked_people:
            return RoomStatus.NOT_VISIBLE

        person = tracked_people[0]
        x, y = person.detection.hip_center()
        if self.bed_zone.contains(x, y):
            return RoomStatus.IN_BED
        if movement_speed > MOVEMENT_THRESHOLD:
            return RoomStatus.MOVING_NORMALLY
        return RoomStatus.OUT_OF_BED
