from datetime import date, datetime, timezone

from meridian_hub.activity_rollup import (
    ActivityHistorySample,
    InMemoryActivityHistory,
    ResidentActivityRollupAggregator,
)


DAY = date(2026, 8, 1)


def _timestamp(day: date, hour: int, minute: int = 0) -> float:
    return datetime(day.year, day.month, day.day, hour, minute, tzinfo=timezone.utc).timestamp()


def _observe_day(aggregator, day: date, *, moving_buckets: set[int], visible: bool = True) -> None:
    # Eight observed 30-minute daytime buckets meets the four-hour minimum.
    for index in range(8):
        aggregator.observe(
            "resident-1", _timestamp(day, 9 + index // 2, (index % 2) * 30),
            visible=visible, moving=index in moving_buckets,
        )


def _close_next_day(aggregator, day: date):
    return aggregator.observe("resident-1", _timestamp(date.fromordinal(day.toordinal() + 1), 9), visible=False, moving=False)[0]


def test_no_baseline_is_labeled_building_instead_of_calling_activity_usual():
    aggregator = ResidentActivityRollupAggregator(InMemoryActivityHistory(), timezone_name="UTC")
    _observe_day(aggregator, DAY, moving_buckets={0, 1, 2, 3})

    rollup = _close_next_day(aggregator, DAY)

    assert rollup.baseline_status == "building"
    assert rollup.daytime_pattern == "not_compared"
    assert rollup.observation_status == "sufficient"


def test_sparse_day_is_not_mistaken_for_low_activity():
    history = InMemoryActivityHistory([
        ActivityHistorySample("resident-1", date(2026, 7, day), 8, None)
        for day in range(1, 8)
    ])
    aggregator = ResidentActivityRollupAggregator(history, timezone_name="UTC")
    for hour in (9, 10):
        aggregator.observe("resident-1", _timestamp(DAY, hour), visible=True, moving=False)

    rollup = _close_next_day(aggregator, DAY)

    assert rollup.baseline_status == "ready"
    assert rollup.observation_status == "limited"
    assert rollup.daytime_pattern == "insufficient_observation"


def test_resident_out_of_view_is_not_mistaken_for_low_activity():
    history = InMemoryActivityHistory([
        ActivityHistorySample("resident-1", date(2026, 7, day), 8, None)
        for day in range(1, 8)
    ])
    aggregator = ResidentActivityRollupAggregator(history, timezone_name="UTC")
    _observe_day(aggregator, DAY, moving_buckets=set(), visible=False)

    rollup = _close_next_day(aggregator, DAY)

    assert rollup.observation_status == "limited"
    assert rollup.daytime_pattern == "insufficient_observation"
    assert rollup.daytime_pattern != "lower_than_usual"


def test_day_genuinely_lower_than_personal_baseline_is_categorized_without_a_number():
    history = InMemoryActivityHistory([
        ActivityHistorySample("resident-1", date(2026, 7, day), 12, 2)
        for day in range(1, 8)
    ])
    aggregator = ResidentActivityRollupAggregator(history, timezone_name="UTC")
    _observe_day(aggregator, DAY, moving_buckets={0, 1, 2, 3, 4, 5})

    rollup = _close_next_day(aggregator, DAY)

    assert rollup.baseline_status == "ready"
    assert rollup.daytime_pattern == "lower_than_usual"
    payload = rollup.delivery_payload()
    assert payload == {
        "p_rollup_date": "2026-08-01",
        "p_daytime_pattern": "lower_than_usual",
        "p_nighttime_pattern": "insufficient_observation",
        "p_baseline_status": "ready",
        "p_observation_status": "sufficient",
    }
    assert "bucket" not in str(payload)
    assert "position" not in str(payload)
