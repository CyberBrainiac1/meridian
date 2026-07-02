from meridian_hub.medication.reminder_scheduler import (
    MedicationReminderScheduler, MedicationSchedule, ReminderStatus,
)


def _schedule(reminder_lead=300.0, missed_grace=1800.0):
    return MedicationSchedule(
        schedule_id="morning-dose", resident_id="res-1", scheduled_time=10000.0,
        reminder_lead_seconds=reminder_lead, missed_grace_seconds=missed_grace,
    )


def test_not_yet_due_well_before_scheduled_time():
    scheduler = MedicationReminderScheduler()
    status = scheduler.evaluate(_schedule(), now=5000.0, visited=False, visit_timestamp=None)
    assert status == ReminderStatus.NOT_YET_DUE


def test_reminder_due_within_lead_window_no_visit():
    scheduler = MedicationReminderScheduler()
    status = scheduler.evaluate(_schedule(), now=9800.0, visited=False, visit_timestamp=None)
    assert status == ReminderStatus.REMINDER_DUE


def test_confirmed_when_visit_occurs_in_window():
    scheduler = MedicationReminderScheduler()
    status = scheduler.evaluate(_schedule(), now=10100.0, visited=True, visit_timestamp=10050.0)
    assert status == ReminderStatus.CONFIRMED


def test_missed_after_grace_period_with_no_visit():
    scheduler = MedicationReminderScheduler()
    status = scheduler.evaluate(_schedule(), now=12000.0, visited=False, visit_timestamp=None)
    assert status == ReminderStatus.MISSED


def test_visit_outside_window_does_not_count_as_confirmed():
    scheduler = MedicationReminderScheduler()
    # visit happened yesterday, not for this dose
    status = scheduler.evaluate(_schedule(), now=12000.0, visited=True, visit_timestamp=100.0)
    assert status == ReminderStatus.MISSED
