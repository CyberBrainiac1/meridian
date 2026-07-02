import numpy as np
import pytest

from meridian_hub.capture.camera_source import CameraSource, FrameUnavailableError


class _FakeCapture:
    """Stands in for cv2.VideoCapture so this test needs no real camera."""

    def __init__(self, frames):
        self._frames = list(frames)
        self._opened = True

    def isOpened(self):
        return self._opened

    def read(self):
        if not self._frames:
            return False, None
        return True, self._frames.pop(0)

    def release(self):
        self._opened = False


def test_reads_frames_in_order():
    frames = [np.full((4, 4, 3), i, dtype=np.uint8) for i in range(3)]
    source = CameraSource(camera_id="cam-1", capture=_FakeCapture(list(frames)))
    for expected in frames:
        frame, ts = source.read()
        assert np.array_equal(frame, expected)
        assert isinstance(ts, float)


def test_raises_when_capture_exhausted():
    source = CameraSource(camera_id="cam-1", capture=_FakeCapture([]))
    with pytest.raises(FrameUnavailableError):
        source.read()


def test_close_releases_capture():
    fake = _FakeCapture([np.zeros((2, 2, 3), dtype=np.uint8)])
    source = CameraSource(camera_id="cam-1", capture=fake)
    source.close()
    assert fake.isOpened() is False
