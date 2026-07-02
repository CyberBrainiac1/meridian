from meridian_hub.face.face_types import FaceDetection


def describe_person(detection: FaceDetection) -> str:
    """Human-readable, caregiver-facing description of a detected person
    for a visitor-arrival notification (e.g. "An unrecognized visitor
    arrived: estimated male, around 45 years old"). Always framed as an
    estimate from a population-level model, never as identity or a
    medical/demographic claim -- same "trend, not diagnosis" discipline
    used by risk_scoring elsewhere in this codebase."""
    parts = []
    if detection.estimated_gender:
        parts.append(f"estimated {detection.estimated_gender}")
    if detection.estimated_age is not None:
        parts.append(f"around {detection.estimated_age} years old")
    if not parts:
        return "an unidentified person (insufficient detail for a description)"
    return ", ".join(parts)
