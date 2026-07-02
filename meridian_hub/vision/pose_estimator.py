import logging
from collections.abc import Callable

import numpy as np
import onnxruntime as ort

from meridian_hub.vision.fast_ops import greedy_nms
from meridian_hub.vision.pose_types import Keypoint, PersonDetection

logger = logging.getLogger(__name__)

NUM_KEYPOINTS = 17
DEFAULT_CONF_THRESHOLD = 0.5
DEFAULT_NMS_IOU_THRESHOLD = 0.5

_PROVIDER_MAP = {"directml": "DmlExecutionProvider", "cpu": "CPUExecutionProvider"}


def decode_yolo_pose_output(
    raw_output: np.ndarray, timestamp: float,
    conf_threshold: float = DEFAULT_CONF_THRESHOLD,
    nms_iou_threshold: float = DEFAULT_NMS_IOU_THRESHOLD,
) -> list[PersonDetection]:
    """raw_output: ultralytics' exported-ONNX layout for a single-class
    pose model, (1, 56, N) or (56, N) -- 4 bbox values (cx, cy, w, h in
    input-pixel space) + 1 confidence + 17*3 keypoint (x, y, visibility)
    per of N anchor predictions. Returns one PersonDetection per distinct
    person after confidence filtering and greedy NMS (so two overlapping
    detections of the same person collapse to the higher-confidence one,
    while two genuinely different people both survive).

    Confidence filtering and NMS both run as vectorized numpy ops
    (meridian_hub.vision.fast_ops) against raw arrays -- N is typically
    in the tens to low hundreds per frame (anchor count, not person
    count), so doing this as array broadcasting instead of a per-row
    Python loop matters once you're decoding every frame, every camera."""
    if raw_output.ndim == 3:
        raw_output = raw_output[0]
    predictions = raw_output.T  # (N, 56)

    scores = predictions[:, 4]
    mask = scores >= conf_threshold
    filtered = predictions[mask]
    if filtered.shape[0] == 0:
        return []

    cx, cy, w, h = filtered[:, 0], filtered[:, 1], filtered[:, 2], filtered[:, 3]
    boxes = np.stack([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], axis=1)
    conf_filtered = filtered[:, 4]

    keep_indices = greedy_nms(boxes, conf_filtered, nms_iou_threshold)

    results: list[PersonDetection] = []
    for idx in keep_indices:
        row = filtered[idx]
        bbox = tuple(float(v) for v in boxes[idx])
        kpt_data = row[5:5 + NUM_KEYPOINTS * 3].reshape(NUM_KEYPOINTS, 3)
        keypoints = [Keypoint(x=float(x), y=float(y), confidence=float(v)) for x, y, v in kpt_data]
        results.append(PersonDetection(keypoints=keypoints, bbox=bbox, confidence=float(row[4]), timestamp=timestamp))
    return results


class PoseEstimator:
    """Tries the requested execution provider first (DirectML on Windows
    by default), falls back to CPUExecutionProvider with a loud logged
    warning if that fails to initialize -- never silently degrades
    without a visible signal (design spec section 4.4). session_factory
    is injectable so tests never need a real .onnx file or GPU."""

    def __init__(
        self, model_path: str, preferred_provider: str = "directml",
        session_factory: Callable[[str, list[str]], object] | None = None,
    ):
        self._session_factory = session_factory or (
            lambda path, providers: ort.InferenceSession(path, providers=providers)
        )
        preferred = _PROVIDER_MAP.get(preferred_provider, "CPUExecutionProvider")

        try:
            self.session = self._session_factory(model_path, [preferred, "CPUExecutionProvider"])
            self.active_provider = preferred_provider if preferred != "CPUExecutionProvider" else "cpu"
        except Exception:
            logger.warning(
                "Failed to initialize %s, falling back to CPUExecutionProvider. "
                "Inference will be slower than expected -- investigate this, don't just accept it.",
                preferred,
            )
            self.session = self._session_factory(model_path, ["CPUExecutionProvider"])
            self.active_provider = "CPUExecutionProvider"

        model_input = self.session.get_inputs()[0]
        self._input_name = model_input.name
        # Model input shape is (1, 3, H, W) -- expose H/W so the daemon
        # knows what size to preprocess a raw frame to before calling
        # estimate(). Falls back to the measured-benchmark default if the
        # session reports a dynamic (non-int) dimension.
        shape = list(model_input.shape)
        self.input_height = shape[2] if isinstance(shape[2], int) else 256
        self.input_width = shape[3] if isinstance(shape[3], int) else 320

    def estimate(self, preprocessed_frame: np.ndarray, timestamp: float) -> list[PersonDetection]:
        outputs = self.session.run(None, {self._input_name: preprocessed_frame})
        return decode_yolo_pose_output(outputs[0], timestamp=timestamp)
