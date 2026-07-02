import numpy as np
import pytest

from meridian_hub.vision.pose_estimator import PoseEstimator, decode_yolo_pose_output


def _build_raw_output(predictions):
    """predictions: list of (cx, cy, w, h, conf) in the ultralytics
    exported-ONNX channel-first layout (1, 56, N)."""
    n = len(predictions)
    raw = np.zeros((1, 56, n), dtype=np.float32)
    for i, (cx, cy, w, h, conf) in enumerate(predictions):
        raw[0, 0, i], raw[0, 1, i], raw[0, 2, i], raw[0, 3, i], raw[0, 4, i] = cx, cy, w, h, conf
    return raw


def test_decode_filters_low_confidence():
    raw = _build_raw_output([(100, 100, 50, 100, 0.9), (300, 300, 50, 100, 0.1)])
    detections = decode_yolo_pose_output(raw, timestamp=1.0, conf_threshold=0.5)
    assert len(detections) == 1
    assert detections[0].confidence == pytest.approx(0.9)


def test_decode_suppresses_overlapping_duplicate_via_nms():
    raw = _build_raw_output([
        (100, 100, 50, 100, 0.9),
        (105, 102, 50, 100, 0.7),  # heavily overlaps the first -- same person, lower-confidence dup
        (500, 500, 50, 100, 0.85),  # far away -- a distinct second person
    ])
    detections = decode_yolo_pose_output(raw, timestamp=1.0, conf_threshold=0.5, nms_iou_threshold=0.5)
    assert len(detections) == 2
    assert sorted(d.confidence for d in detections) == pytest.approx([0.85, 0.9])


def test_decode_returns_correct_bbox_from_cxcywh():
    raw = _build_raw_output([(100, 100, 50, 100, 0.9)])
    detections = decode_yolo_pose_output(raw, timestamp=1.0, conf_threshold=0.5)
    x1, y1, x2, y2 = detections[0].bbox
    assert (x1, y1, x2, y2) == (75.0, 50.0, 125.0, 150.0)


class _FakeInput:
    name = "images"
    shape = [1, 3, 256, 320]


class _FakeSession:
    def get_inputs(self):
        return [_FakeInput()]


def test_falls_back_to_cpu_when_preferred_provider_fails(caplog):
    def fake_session_factory(path, providers):
        if providers[0] != "CPUExecutionProvider":
            raise RuntimeError("no DirectML device present")
        return _FakeSession()

    with caplog.at_level("WARNING"):
        estimator = PoseEstimator(
            model_path="unused.onnx", preferred_provider="directml", session_factory=fake_session_factory
        )
    assert estimator.active_provider == "CPUExecutionProvider"
    assert "falling back to CPUExecutionProvider" in caplog.text


def test_uses_preferred_provider_when_available():
    def fake_session_factory(path, providers):
        return _FakeSession()

    estimator = PoseEstimator(
        model_path="unused.onnx", preferred_provider="directml", session_factory=fake_session_factory
    )
    assert estimator.active_provider == "directml"


def test_exposes_input_dimensions_from_session():
    def fake_session_factory(path, providers):
        return _FakeSession()

    estimator = PoseEstimator(
        model_path="unused.onnx", preferred_provider="directml", session_factory=fake_session_factory
    )
    assert estimator.input_height == 256
    assert estimator.input_width == 320
