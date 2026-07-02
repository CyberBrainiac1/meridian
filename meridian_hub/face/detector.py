from dataclasses import dataclass

import cv2
import numpy as np

from meridian_hub.face.face_types import FaceDetection

MIN_FACE_SIZE_PX = 40.0
MIN_SHARPNESS = 30.0  # Laplacian variance -- tunable against real footage
MAX_ASYMMETRY_RATIO = 1.6  # eye-to-nose horizontal distance ratio; ~1.0 is dead-frontal


@dataclass(frozen=True)
class QualityScore:
    sharpness: float
    size_px: float
    frontal_ok: bool
    passes: bool


def _is_frontal(landmarks: list[tuple[float, float]]) -> bool:
    if len(landmarks) < 3:
        return False
    left_eye, right_eye, nose = landmarks[0], landmarks[1], landmarks[2]
    dist_left = abs(nose[0] - left_eye[0])
    dist_right = abs(right_eye[0] - nose[0])
    smaller = min(dist_left, dist_right)
    larger = max(dist_left, dist_right)
    if smaller < 1e-6:
        return False
    return (larger / smaller) <= MAX_ASYMMETRY_RATIO


def score_detection(frame: np.ndarray, detection: FaceDetection) -> QualityScore:
    x1, y1, x2, y2 = detection.bbox
    x1i, y1i, x2i, y2i = int(max(x1, 0)), int(max(y1, 0)), int(x2), int(y2)
    crop = frame[y1i:y2i, x1i:x2i]
    if crop.size == 0:
        return QualityScore(sharpness=0.0, size_px=0.0, frontal_ok=False, passes=False)

    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY) if crop.ndim == 3 else crop
    sharpness = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    size_px = min(x2 - x1, y2 - y1)
    frontal_ok = _is_frontal(detection.landmarks)
    passes = sharpness >= MIN_SHARPNESS and size_px >= MIN_FACE_SIZE_PX and frontal_ok
    return QualityScore(sharpness=sharpness, size_px=size_px, frontal_ok=frontal_ok, passes=passes)


def select_best_detection(frame: np.ndarray, detections: list[FaceDetection]) -> FaceDetection | None:
    """The 'nice snapshot' behavior: of everything detected in this
    frame, keep only the one clean, sharp, frontal, large-enough face --
    or none, if nothing clears the bar. Sharper wins among passing
    candidates, since a sharper frontal crop makes a better embedding."""
    scored = [(d, score_detection(frame, d)) for d in detections]
    passing = [(d, s) for d, s in scored if s.passes]
    if not passing:
        return None
    return max(passing, key=lambda pair: pair[1].sharpness)[0]
