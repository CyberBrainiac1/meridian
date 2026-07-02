from meridian_hub.features.feature_window import KinematicFeatures
from meridian_hub.validation.local_validator import LocalHeuristicValidator, ValidationOutcome


def test_confirms_clear_fall_pattern():
    validator = LocalHeuristicValidator()
    features = KinematicFeatures(hip_vertical_velocity=210.0, torso_angle_degrees=72.0, aspect_ratio=1.6, stillness_duration_seconds=2.2)
    result = validator.validate(features)
    assert result.outcome == ValidationOutcome.FALL_CONFIRMED
    assert result.confidence > 0.5
    assert "aspect_ratio" in result.rationale or "Horizontal" in result.rationale


def test_flags_false_positive_for_quick_recovery():
    validator = LocalHeuristicValidator()
    features = KinematicFeatures(hip_vertical_velocity=30.0, torso_angle_degrees=35.0, aspect_ratio=0.7, stillness_duration_seconds=0.2)
    result = validator.validate(features)
    assert result.outcome == ValidationOutcome.FALSE_POSITIVE_SITTING


def test_inconclusive_for_ambiguous_signals():
    validator = LocalHeuristicValidator()
    features = KinematicFeatures(hip_vertical_velocity=90.0, torso_angle_degrees=45.0, aspect_ratio=1.0, stillness_duration_seconds=1.0)
    result = validator.validate(features)
    assert result.outcome == ValidationOutcome.INCONCLUSIVE


def test_validate_has_no_network_or_disk_io():
    import inspect
    source = inspect.getsource(LocalHeuristicValidator.validate)
    for banned in ("requests", "socket", "sqlite3", "urlopen"):
        assert banned not in source
