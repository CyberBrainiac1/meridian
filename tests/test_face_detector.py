import numpy as np

from meridian_hub.face.detector import score_detection, select_best_detection
from meridian_hub.face.face_types import FaceDetection


def _sharp_frame(size=200):
    # a checkerboard has high Laplacian variance -- stands in for a sharp,
    # in-focus real photo without needing an actual JPEG fixture
    frame = np.zeros((size, size, 3), dtype=np.uint8)
    frame[::2, ::2] = 255
    frame[1::2, 1::2] = 255
    return frame


def _blurry_frame(size=200):
    return np.full((size, size, 3), 128, dtype=np.uint8)  # flat gray, zero variance


FRONTAL_LANDMARKS = [(80.0, 90.0), (120.0, 90.0), (100.0, 110.0), (85.0, 130.0), (115.0, 130.0)]
PROFILE_LANDMARKS = [(60.0, 90.0), (120.0, 90.0), (115.0, 110.0), (85.0, 130.0), (115.0, 130.0)]  # nose near right eye


def test_sharp_large_frontal_face_passes():
    frame = _sharp_frame()
    det = FaceDetection(bbox=(50.0, 50.0, 150.0, 150.0), landmarks=FRONTAL_LANDMARKS, embedding=[0.0] * 512, det_score=0.9)
    score = score_detection(frame, det)
    assert score.passes is True


def test_blurry_face_fails():
    frame = _blurry_frame()
    det = FaceDetection(bbox=(50.0, 50.0, 150.0, 150.0), landmarks=FRONTAL_LANDMARKS, embedding=[0.0] * 512, det_score=0.9)
    score = score_detection(frame, det)
    assert score.sharpness < 1.0
    assert score.passes is False


def test_too_small_face_fails():
    frame = _sharp_frame()
    det = FaceDetection(bbox=(90.0, 90.0, 100.0, 100.0), landmarks=FRONTAL_LANDMARKS, embedding=[0.0] * 512, det_score=0.9)
    score = score_detection(frame, det)
    assert score.size_px < 40.0
    assert score.passes is False


def test_profile_face_fails_frontal_check():
    frame = _sharp_frame()
    det = FaceDetection(bbox=(50.0, 50.0, 150.0, 150.0), landmarks=PROFILE_LANDMARKS, embedding=[0.0] * 512, det_score=0.9)
    score = score_detection(frame, det)
    assert score.frontal_ok is False
    assert score.passes is False


def test_select_best_picks_sharpest_passing_detection():
    frame = _sharp_frame()
    good = FaceDetection(bbox=(50.0, 50.0, 150.0, 150.0), landmarks=FRONTAL_LANDMARKS, embedding=[1.0] * 512, det_score=0.9)
    small = FaceDetection(bbox=(90.0, 90.0, 100.0, 100.0), landmarks=FRONTAL_LANDMARKS, embedding=[2.0] * 512, det_score=0.5)
    best = select_best_detection(frame, [small, good])
    assert best is good


def test_select_best_returns_none_when_nothing_passes():
    frame = _blurry_frame()
    det = FaceDetection(bbox=(50.0, 50.0, 150.0, 150.0), landmarks=FRONTAL_LANDMARKS, embedding=[0.0] * 512, det_score=0.9)
    assert select_best_detection(frame, [det]) is None
