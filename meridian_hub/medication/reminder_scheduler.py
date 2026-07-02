from dataclasses import dataclass
from enum import Enum, auto


class ReminderStatus(Enum):
    NOT_YET_DUE = auto()
    REMINDER_DUE = auto()
    CONFIRMED = auto()
    MISSED = auto()


@dataclass(frozen=True)
class MedicationSchedule:
    schedule_id: str
    resident_id: str
    scheduled_time: float
    reminder_lead_seconds: float = 0.0  # how early "due" starts, before scheduled_time
    missed_grace_seconds: float = 1800.0  # how long after scheduled_time before "missed"


class MedicationReminderScheduler:
    """Extends MedicationVisitVerifier's presence confirmation (PRD
    section 8.16) with a time-based reminder/missed state: that class
    answers "did a visit happen," this answers "is one due, overdue, or
    already confirmed" for a specific scheduled dose. Purely a state
    classifier -- delivery (SMS, push) is a separate concern
    (meridian_hub/alerting)."""

    def evaluate(
        self, schedule: MedicationSchedule, now: float,
        visited: bool, visit_timestamp: float | None,
    ) -> ReminderStatus:
        if visited and visit_timestamp is not None:
            window_start = schedule.scheduled_time - schedule.reminder_lead_seconds
            window_end = schedule.scheduled_time + schedule.missed_grace_seconds
            if window_start <= visit_timestamp <= window_end:
                return ReminderStatus.CONFIRMED

        if now < schedule.scheduled_time - schedule.reminder_lead_seconds:
            return ReminderStatus.NOT_YET_DUE
        if now < schedule.scheduled_time + schedule.missed_grace_seconds:
            return ReminderStatus.REMINDER_DUE
        return ReminderStatus.MISSED
