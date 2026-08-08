"""Privacy-bounded daily movement summaries for resident-room cameras.

This module deliberately aggregates on the Hub.  It retains no pose, track,
coordinate, or per-window timestamps after a local day is closed; the only
outbound values are categorical comparisons with the room's own recent
history.  A room camera cannot establish that an unseen resident left the
room, identify a lone person, or observe meals, so none of those are modeled.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
import sqlite3
from statistics import median
from typing import Literal, Protocol
from zoneinfo import ZoneInfo


MovementPattern = Literal[
    "usual", "lower_than_usual", "higher_than_usual",
    "not_compared", "insufficient_observation",
]
BaselineStatus = Literal["ready", "building"]
ObservationStatus = Literal["sufficient", "limited"]


@dataclass(frozen=True)
class ActivityHistorySample:
    """Hub-local aggregate used solely to establish a personal baseline."""

    resident_id: str
    rollup_date: date
    daytime_active_buckets: int
    nighttime_active_buckets: int | None


class ActivityHistory(Protocol):
    """Injected local history boundary; raw pose data never crosses it."""

    def samples_before(self, resident_id: str, before: date, limit: int) -> list[ActivityHistorySample]: ...

    def save(self, sample: ActivityHistorySample) -> None: ...


class InMemoryActivityHistory:
    """Small deterministic history implementation for tests and demos."""

    def __init__(self, samples: list[ActivityHistorySample] | None = None):
        self._samples = list(samples or [])

    def samples_before(self, resident_id: str, before: date, limit: int) -> list[ActivityHistorySample]:
        matching = [sample for sample in self._samples if sample.resident_id == resident_id and sample.rollup_date < before]
        return sorted(matching, key=lambda sample: sample.rollup_date, reverse=True)[:limit]

    def save(self, sample: ActivityHistorySample) -> None:
        self._samples = [
            existing for existing in self._samples
            if (existing.resident_id, existing.rollup_date) != (sample.resident_id, sample.rollup_date)
        ]
        self._samples.append(sample)


class SqliteActivityHistory:
    """Durable Hub-local baseline store; it never contains pose or location."""

    def __init__(self, db_path: str):
        self._connection = sqlite3.connect(db_path)
        self._connection.execute(
            """create table if not exists resident_activity_baselines (
                resident_id text not null,
                rollup_date text not null,
                daytime_active_buckets integer not null,
                nighttime_active_buckets integer,
                primary key (resident_id, rollup_date)
            )"""
        )
        self._connection.commit()

    def samples_before(self, resident_id: str, before: date, limit: int) -> list[ActivityHistorySample]:
        rows = self._connection.execute(
            """select resident_id, rollup_date, daytime_active_buckets, nighttime_active_buckets
               from resident_activity_baselines
               where resident_id = ? and rollup_date < ?
               order by rollup_date desc limit ?""",
            (resident_id, before.isoformat(), limit),
        ).fetchall()
        return [
            ActivityHistorySample(
                resident_id=row[0], rollup_date=date.fromisoformat(row[1]),
                daytime_active_buckets=row[2], nighttime_active_buckets=row[3],
            )
            for row in rows
        ]

    def save(self, sample: ActivityHistorySample) -> None:
        self._connection.execute(
            """insert into resident_activity_baselines
               (resident_id, rollup_date, daytime_active_buckets, nighttime_active_buckets)
               values (?, ?, ?, ?)
               on conflict(resident_id, rollup_date) do update set
                   daytime_active_buckets = excluded.daytime_active_buckets,
                   nighttime_active_buckets = excluded.nighttime_active_buckets""",
            (sample.resident_id, sample.rollup_date.isoformat(), sample.daytime_active_buckets, sample.nighttime_active_buckets),
        )
        self._connection.commit()

    def close(self) -> None:
        self._connection.close()


@dataclass(frozen=True)
class ResidentActivityRollup:
    """The entire family/cloud-safe daily payload.  No counts are exported."""

    resident_id: str
    rollup_date: date
    daytime_pattern: MovementPattern
    nighttime_pattern: MovementPattern
    baseline_status: BaselineStatus
    observation_status: ObservationStatus

    def delivery_payload(self) -> dict[str, str]:
        """PostgREST RPC arguments; resident/facility come from the Hub JWT."""

        return {
            "p_rollup_date": self.rollup_date.isoformat(),
            "p_daytime_pattern": self.daytime_pattern,
            "p_nighttime_pattern": self.nighttime_pattern,
            "p_baseline_status": self.baseline_status,
            "p_observation_status": self.observation_status,
        }


@dataclass
class _OpenDay:
    observed_daytime_buckets: set[int] = field(default_factory=set)
    active_daytime_buckets: set[int] = field(default_factory=set)
    observed_nighttime_buckets: set[int] = field(default_factory=set)
    active_nighttime_buckets: set[int] = field(default_factory=set)


class ResidentActivityRollupAggregator:
    """Builds a coarse, resident-room movement comparison without a trace.

    An observation is made only when the caller has exactly one tracked person
    in the provisioned room camera.  The caller passes ``visible=False`` for
    zero or multiple tracks, so absence is never interpreted as inactivity.
    Thirty-minute buckets intentionally discard within-day timing; their
    counts remain Hub-local and only category labels leave the device.
    """

    def __init__(
        self,
        history: ActivityHistory,
        *,
        timezone_name: str = "UTC",
        baseline_days: int = 7,
        baseline_window_days: int = 14,
        minimum_daytime_buckets: int = 8,
        minimum_nighttime_buckets: int = 2,
        difference_fraction: float = 0.30,
    ):
        self._history = history
        self._timezone = ZoneInfo(timezone_name)
        self._baseline_days = baseline_days
        self._baseline_window_days = baseline_window_days
        self._minimum_daytime_buckets = minimum_daytime_buckets
        self._minimum_nighttime_buckets = minimum_nighttime_buckets
        self._difference_fraction = difference_fraction
        self._open_days: dict[tuple[str, date], _OpenDay] = {}

    def observe(self, resident_id: str, timestamp: float, *, visible: bool, moving: bool) -> list[ResidentActivityRollup]:
        """Records one local pose-derived observation and closes prior days."""

        local_time = datetime.fromtimestamp(timestamp, tz=self._timezone)
        rollup_date = local_time.date()
        completed = self.close_before(resident_id, rollup_date)
        open_day = self._open_days.setdefault((resident_id, rollup_date), _OpenDay())
        if not visible:
            return completed

        bucket = local_time.hour * 2 + local_time.minute // 30
        is_night = local_time.hour < 8
        observed = open_day.observed_nighttime_buckets if is_night else open_day.observed_daytime_buckets
        active = open_day.active_nighttime_buckets if is_night else open_day.active_daytime_buckets
        observed.add(bucket)
        if moving:
            active.add(bucket)
        return completed

    def close_before(self, resident_id: str, before: date) -> list[ResidentActivityRollup]:
        """Finalizes all locally-held dates before ``before`` for one resident."""

        completed: list[ResidentActivityRollup] = []
        for key in sorted(list(self._open_days), key=lambda item: item[1]):
            candidate_resident, candidate_date = key
            if candidate_resident != resident_id or candidate_date >= before:
                continue
            completed.append(self._close(candidate_resident, candidate_date, self._open_days.pop(key)))
        return completed

    def _close(self, resident_id: str, rollup_date: date, open_day: _OpenDay) -> ResidentActivityRollup:
        day_observation_sufficient = len(open_day.observed_daytime_buckets) >= self._minimum_daytime_buckets
        night_observation_sufficient = len(open_day.observed_nighttime_buckets) >= self._minimum_nighttime_buckets
        history = self._history.samples_before(resident_id, rollup_date, self._baseline_window_days)
        daytime_baseline = [sample.daytime_active_buckets for sample in history]
        nighttime_baseline = [sample.nighttime_active_buckets for sample in history if sample.nighttime_active_buckets is not None]

        baseline_ready = len(daytime_baseline) >= self._baseline_days
        daytime_pattern = self._compare(
            len(open_day.active_daytime_buckets), daytime_baseline,
            observation_sufficient=day_observation_sufficient,
        )
        nighttime_pattern = self._compare(
            len(open_day.active_nighttime_buckets), nighttime_baseline,
            observation_sufficient=night_observation_sufficient,
        )

        # Keep the numeric baseline entirely local.  A limited day is not
        # saved, because it would make "out of view" look like a quieter day.
        if day_observation_sufficient:
            self._history.save(ActivityHistorySample(
                resident_id=resident_id,
                rollup_date=rollup_date,
                daytime_active_buckets=len(open_day.active_daytime_buckets),
                nighttime_active_buckets=(len(open_day.active_nighttime_buckets) if night_observation_sufficient else None),
            ))

        return ResidentActivityRollup(
            resident_id=resident_id,
            rollup_date=rollup_date,
            daytime_pattern=daytime_pattern,
            nighttime_pattern=nighttime_pattern,
            baseline_status="ready" if baseline_ready else "building",
            observation_status="sufficient" if day_observation_sufficient else "limited",
        )

    def _compare(self, current: int, baseline: list[int | None], *, observation_sufficient: bool) -> MovementPattern:
        usable = [value for value in baseline if value is not None]
        if not observation_sufficient:
            return "insufficient_observation"
        if len(usable) < self._baseline_days:
            return "not_compared"
        midpoint = float(median(usable))
        if midpoint == 0:
            return "usual" if current == 0 else "higher_than_usual"
        ratio = (current - midpoint) / midpoint
        if ratio <= -self._difference_fraction:
            return "lower_than_usual"
        if ratio >= self._difference_fraction:
            return "higher_than_usual"
        return "usual"
