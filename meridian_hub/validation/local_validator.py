from dataclasses import dataclass
from enum import Enum, auto

from meridian_hub.features.feature_window import KinematicFeatures

CONFIRM_ASPECT_RATIO = 1.3
CONFIRM_STILLNESS_SECONDS = 1.5
CONFIRM_ANGLE_DEGREES = 60.0

FALSE_POSITIVE_STILLNESS_SECONDS = 0.5
FALSE_POSITIVE_VELOCITY = 50.0


class ValidationOutcome(Enum):
    FALL_CONFIRMED = auto()
    FALSE_POSITIVE_SITTING = auto()
    FALSE_POSITIVE_OBJECT_DROP = auto()
    INCONCLUSIVE = auto()


@dataclass(frozen=True)
class ValidationResult:
    outcome: ValidationOutcome
    confidence: float
    rationale: str


class LocalHeuristicValidator:
    """A second, independent pass over an ambiguous fall candidate's
    feature snapshot -- deliberately uses stricter thresholds than the
    primary state machine's own SUSPECTED band, so it catches different
    mistakes rather than rubber-stamping the same logic twice. Runs
    synchronously, no I/O, in-process (design spec section 2.1's
    real-time guarantee). The "fail open to CONFIRMED on inconclusive"
    policy belongs to the caller (event engine), not this class -- this
    class only classifies, it doesn't decide what to do about it."""

    def validate(self, features: KinematicFeatures) -> ValidationResult:
        if (features.aspect_ratio >= CONFIRM_ASPECT_RATIO
                and features.stillness_duration_seconds >= CONFIRM_STILLNESS_SECONDS
                and features.torso_angle_degrees >= CONFIRM_ANGLE_DEGREES):
            return ValidationResult(
                ValidationOutcome.FALL_CONFIRMED,
                confidence=0.85,
                rationale=(
                    f"Horizontal posture (aspect_ratio={features.aspect_ratio:.2f}) "
                    f"sustained {features.stillness_duration_seconds:.1f}s with torso "
                    f"angle {features.torso_angle_degrees:.0f} degrees."
                ),
            )

        if (features.stillness_duration_seconds < FALSE_POSITIVE_STILLNESS_SECONDS
                and features.hip_vertical_velocity < FALSE_POSITIVE_VELOCITY):
            return ValidationResult(
                ValidationOutcome.FALSE_POSITIVE_SITTING,
                confidence=0.6,
                rationale="Recovery motion shortly after the drop is consistent with controlled sitting, not a fall.",
            )

        return ValidationResult(
            ValidationOutcome.INCONCLUSIVE,
            confidence=0.3,
            rationale="Signals do not clearly match a confirmed-fall or a known false-positive pattern.",
        )
