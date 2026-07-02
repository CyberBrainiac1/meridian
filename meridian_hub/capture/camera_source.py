import time

import cv2


class FrameUnavailableError(Exception):
    """Raised when a camera source has no frame to give (source exhausted
    or a hardware read failure)."""


class CameraSource:
    """Wraps a single cv2.VideoCapture-compatible object with a
    camera_id and a simple (frame, timestamp) read interface. Any object
    exposing isOpened()/read()/release() works here -- including a fake in
    tests, a live webcam, a looped video file, or (later) an HTTP-MJPEG
    client implementing the same three methods.
    """

    def __init__(self, camera_id: str, capture):
        self.camera_id = camera_id
        self._capture = capture

    @classmethod
    def from_source(cls, camera_id: str, source: str) -> "CameraSource":
        """source is a webcam index ("0") or a video file path."""
        index = int(source) if source.isdigit() else source
        return cls(camera_id, cv2.VideoCapture(index))

    def read(self):
        if not self._capture.isOpened():
            raise FrameUnavailableError(f"{self.camera_id}: capture not open")
        ok, frame = self._capture.read()
        if not ok or frame is None:
            raise FrameUnavailableError(f"{self.camera_id}: no frame available")
        return frame, time.time()

    def close(self) -> None:
        self._capture.release()
