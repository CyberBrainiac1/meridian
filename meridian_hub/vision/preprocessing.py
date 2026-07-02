import cv2
import numpy as np


def preprocess_frame(frame: np.ndarray, target_height: int, target_width: int) -> np.ndarray:
    """BGR uint8 HWC frame -> normalized float32 NCHW batch-of-1, resized
    to the model's expected input size. Plain resize (not letterbox) --
    acceptable distortion for a fixed-aspect-ratio camera feed matched to
    a fixed-aspect-ratio model input, and simpler than letterboxing plus
    having to un-letterbox keypoint coordinates afterward."""
    resized = cv2.resize(frame, (target_width, target_height))
    rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
    normalized = rgb.astype(np.float32) / 255.0
    chw = normalized.transpose(2, 0, 1)
    return np.expand_dims(chw, axis=0)
