import numpy as np

from meridian_hub.vision.preprocessing import preprocess_frame


def test_output_shape_matches_target_and_is_nchw():
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    result = preprocess_frame(frame, target_height=256, target_width=320)
    assert result.shape == (1, 3, 256, 320)


def test_output_is_normalized_float32():
    frame = np.full((100, 100, 3), 255, dtype=np.uint8)
    result = preprocess_frame(frame, target_height=64, target_width=64)
    assert result.dtype == np.float32
    assert result.max() <= 1.0
    assert result.min() >= 0.0
