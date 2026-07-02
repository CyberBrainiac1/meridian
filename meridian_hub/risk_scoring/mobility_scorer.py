from dataclasses import dataclass, field


@dataclass(frozen=True)
class RiskTrend:
    """PRD section 8.13: framed as a trend, never a medical prediction --
    score_version is always 'v1-heuristic' so nothing downstream can
    mistake this for a validated clinical signal (PRD section 22 non-goal:
    no medical claims)."""

    resident_id: str
    score: int  # 0-100, higher = more risk
    avg_gait_speed_change_pct: float
    nighttime_movement_events: int
    score_version: str = "v1-heuristic"


@dataclass
class _ResidentMobilityData:
    gait_samples: list[tuple[float, float]] = field(default_factory=list)  # (speed, timestamp)
    nighttime_events: list[float] = field(default_factory=list)  # timestamps
    baseline_gait_speed: float | None = None


class MobilityTrendScorer:
    """v1 heuristic mobility/fall-risk trend scorer (PRD section 8.13).
    Consumes the same gait-speed signal the fall-detection feature window
    already computes ("almost free" per the PRD's own framing) -- this
    class just accumulates it per-resident and compares against a
    baseline to produce a weekly trend score."""

    def __init__(self):
        self._data: dict[str, _ResidentMobilityData] = {}

    def _get(self, resident_id: str) -> _ResidentMobilityData:
        if resident_id not in self._data:
            self._data[resident_id] = _ResidentMobilityData()
        return self._data[resident_id]

    def set_baseline(self, resident_id: str, baseline_gait_speed: float) -> None:
        self._get(resident_id).baseline_gait_speed = baseline_gait_speed

    def record_gait_sample(self, resident_id: str, gait_speed: float, timestamp: float) -> None:
        self._get(resident_id).gait_samples.append((gait_speed, timestamp))

    def record_nighttime_movement(self, resident_id: str, timestamp: float) -> None:
        self._get(resident_id).nighttime_events.append(timestamp)

    def compute_weekly_trend(self, resident_id: str, week_start: float, week_end: float) -> RiskTrend | None:
        data = self._data.get(resident_id)
        if data is None:
            return None

        week_samples = [speed for speed, t in data.gait_samples if week_start <= t < week_end]
        if not week_samples:
            return None

        avg_speed = sum(week_samples) / len(week_samples)
        baseline = data.baseline_gait_speed if data.baseline_gait_speed is not None else avg_speed
        pct_change = ((avg_speed - baseline) / baseline * 100.0) if baseline > 0 else 0.0

        # 50 is neutral; a gait-speed decline (negative pct_change) pushes
        # the score up toward higher risk, an improvement pushes it down.
        score = max(0, min(100, round(50 - pct_change)))

        night_count = sum(1 for t in data.nighttime_events if week_start <= t < week_end)

        return RiskTrend(
            resident_id=resident_id, score=score,
            avg_gait_speed_change_pct=round(pct_change, 1),
            nighttime_movement_events=night_count,
        )
