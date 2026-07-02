from meridian_hub.risk_scoring.mobility_scorer import MobilityTrendScorer


def test_no_trend_without_samples_in_window():
    scorer = MobilityTrendScorer()
    assert scorer.compute_weekly_trend("res-1", week_start=0.0, week_end=604800.0) is None


def test_neutral_score_when_no_baseline_set():
    scorer = MobilityTrendScorer()
    scorer.record_gait_sample("res-1", gait_speed=50.0, timestamp=100.0)
    trend = scorer.compute_weekly_trend("res-1", week_start=0.0, week_end=604800.0)
    assert trend.score == 50
    assert trend.avg_gait_speed_change_pct == 0.0


def test_gait_speed_decline_raises_risk_score():
    scorer = MobilityTrendScorer()
    scorer.set_baseline("res-1", baseline_gait_speed=100.0)
    scorer.record_gait_sample("res-1", gait_speed=70.0, timestamp=100.0)  # 30% slower than baseline
    trend = scorer.compute_weekly_trend("res-1", week_start=0.0, week_end=604800.0)
    assert trend.avg_gait_speed_change_pct == -30.0
    assert trend.score > 50


def test_gait_speed_improvement_lowers_risk_score():
    scorer = MobilityTrendScorer()
    scorer.set_baseline("res-1", baseline_gait_speed=100.0)
    scorer.record_gait_sample("res-1", gait_speed=120.0, timestamp=100.0)
    trend = scorer.compute_weekly_trend("res-1", week_start=0.0, week_end=604800.0)
    assert trend.score < 50


def test_score_version_always_labeled_heuristic():
    scorer = MobilityTrendScorer()
    scorer.record_gait_sample("res-1", gait_speed=50.0, timestamp=100.0)
    trend = scorer.compute_weekly_trend("res-1", week_start=0.0, week_end=604800.0)
    assert trend.score_version == "v1-heuristic"


def test_nighttime_events_counted_within_window_only():
    scorer = MobilityTrendScorer()
    scorer.record_gait_sample("res-1", gait_speed=50.0, timestamp=100.0)
    scorer.record_nighttime_movement("res-1", timestamp=200.0)
    scorer.record_nighttime_movement("res-1", timestamp=300.0)
    scorer.record_nighttime_movement("res-1", timestamp=700000.0)  # outside window
    trend = scorer.compute_weekly_trend("res-1", week_start=0.0, week_end=604800.0)
    assert trend.nighttime_movement_events == 2
