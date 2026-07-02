from meridian_hub.face.face_types import FaceDetection
from meridian_hub.face.person_description import describe_person


def _detection(age=None, gender=None):
    return FaceDetection(
        bbox=(0.0, 0.0, 10.0, 10.0), landmarks=[], embedding=[0.0], det_score=0.9,
        estimated_age=age, estimated_gender=gender,
    )


def test_describes_age_and_gender_together():
    description = describe_person(_detection(age=45, gender="male"))
    assert description == "estimated male, around 45 years old"


def test_describes_gender_only():
    description = describe_person(_detection(gender="female"))
    assert description == "estimated female"


def test_describes_age_only():
    description = describe_person(_detection(age=30))
    assert description == "around 30 years old"


def test_falls_back_when_nothing_available():
    description = describe_person(_detection())
    assert "unidentified" in description
