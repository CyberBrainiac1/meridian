from dataclasses import dataclass
from enum import Enum, auto


class FallState(Enum):
    NORMAL = auto()
    FALL_CANDIDATE = auto()
    CONFIRMED = auto()
    SUSPECTED = auto()
    CLEARED = auto()


@dataclass(frozen=True)
class FallEvent:
    track_id: int
    state: FallState
    timestamp: float
