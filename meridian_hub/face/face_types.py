from dataclasses import dataclass

BBox = tuple[float, float, float, float]
Point = tuple[float, float]


@dataclass(frozen=True)
class FaceDetection:
    """InsightFace's own Face object converted to a plain dataclass
    immediately on detection -- keeps everything downstream (quality
    gating, matching) testable with synthetic data instead of needing a
    real InsightFace model loaded."""

    bbox: BBox
    landmarks: list[Point]  # 5 points: left_eye, right_eye, nose, mouth_left, mouth_right
    embedding: list[float]  # 512-d ArcFace embedding
    det_score: float
