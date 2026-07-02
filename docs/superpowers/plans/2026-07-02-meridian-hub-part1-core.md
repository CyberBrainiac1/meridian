# Meridian Hub Part 1: Core Fall-Detection Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the safety-critical core of the Meridian Hub: camera capture → multi-person pose estimation → tracking → fall/long-lie detection → local validation → canonical event → offline queue, running on this Windows machine's GPU, fully tested without requiring a camera for the test suite.

**Architecture:** See `docs/superpowers/specs/2026-07-02-meridian-hub-poc-design.md` sections 3-4. This plan covers components 4.1 (capture, partial — camera_registry + local sources only, HTTP-MJPEG deferred to separate protocol work), 4.2 (ingestion), 4.3 (scheduler), 4.4 (vision: pose + tracker), 4.5 (features), 4.6 (fall/long-lie classifiers), 4.12 (validation), 4.13 (event engine, PRD §17 schema), 4.14 (offline queue), 4.15 (device health). Components 4.7-4.11 and 4.16 (dementia safety, risk scoring, night-rounds, medication verification, visitor logging, mock backend) are Part 2.

**Tech Stack:** Python 3.11+, `onnxruntime` (DirectML execution provider, CPU fallback), `opencv-python`, `numpy`, `pydantic`/`pydantic-settings`, `pytest`. Build-time only: `ultralytics`, `torch` (for the model export tool, never imported by the Hub itself).

---

## Task 0: Project scaffolding

**Files:**
- Create: `pyproject.toml`
- Create: `.env.example`
- Create: `.gitignore`
- Create: `meridian_hub/__init__.py`
- Create: `meridian_hub/logging_setup.py`
- Create: `tests/__init__.py`
- Create: `tests/fixtures/.gitkeep`

- [ ] **Step 1: Create `pyproject.toml`**

```toml
[project]
name = "meridian-hub"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "onnxruntime-directml>=1.20; platform_system == 'Windows'",
    "onnxruntime>=1.20; platform_system != 'Windows'",
    "opencv-python>=4.10",
    "numpy>=1.26",
    "insightface>=0.7",
    "pydantic>=2.7",
    "pydantic-settings>=2.4",
    "fastapi>=0.115",
    "uvicorn[standard]>=0.30",
    "requests>=2.32",
]

[project.optional-dependencies]
dev = ["pytest>=8.0", "pytest-cov>=5.0"]
export = ["ultralytics>=8.3", "torch>=2.4"]

[tool.pytest.ini_options]
testpaths = ["tests"]

[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[tool.setuptools.packages.find]
include = ["meridian_hub*", "mock_backend*"]
```

- [ ] **Step 2: Create `.env.example`**

```bash
CAMERA_SOURCES=0
TARGET_FPS=15
POSE_MODEL_PATH=models/yolo11s-pose.onnx
INFERENCE_PROVIDER=directml
FACILITY_ID=fac-poc-001
BUILDING_ID=bld-poc-001
QUEUE_DB_PATH=data/queue.sqlite3
REGISTRY_DB_PATH=data/camera_registry.sqlite3
MOCK_BACKEND_URL=http://localhost:8000
```

- [ ] **Step 3: Create `.gitignore`**

```
__pycache__/
*.pyc
.venv/
venv/
*.sqlite3
*.onnx
*.pt
.env
data/
reports/
*.egg-info/
```

- [ ] **Step 4: Create package markers and logging setup**

`meridian_hub/__init__.py`:
```python
```

`meridian_hub/logging_setup.py`:
```python
import logging
import sys


def configure_logging(level: int = logging.INFO) -> None:
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        stream=sys.stdout,
    )
```

`tests/__init__.py`:
```python
```

`tests/fixtures/.gitkeep`:
```
```

- [ ] **Step 5: Install and verify**

Run: `cd C:\Users\emmad\Documents\meridian && python3 -m pip install -e ".[dev]"`
Expected: ends with `Successfully installed meridian-hub-0.1.0 ...`

Run: `python3 -c "import meridian_hub; from meridian_hub.logging_setup import configure_logging; print('ok')"`
Expected: `ok`

- [ ] **Step 6: Commit**

```bash
git add pyproject.toml .env.example .gitignore meridian_hub/__init__.py meridian_hub/logging_setup.py tests/__init__.py tests/fixtures/.gitkeep
git commit -m "Scaffold meridian_hub package"
```

---

## Task 1: Config module

**Files:**
- Create: `meridian_hub/config.py`
- Test: `tests/test_config.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_config.py
from meridian_hub.config import Settings


def test_defaults(monkeypatch):
    for key in ["CAMERA_SOURCES", "TARGET_FPS", "INFERENCE_PROVIDER", "FACILITY_ID"]:
        monkeypatch.delenv(key, raising=False)
    settings = Settings(_env_file=None)
    assert settings.camera_sources == ["0"]
    assert settings.target_fps == 15
    assert settings.inference_provider == "directml"
    assert settings.facility_id == "fac-poc-001"


def test_camera_sources_parses_comma_list(monkeypatch):
    monkeypatch.setenv("CAMERA_SOURCES", "0,videos/room2.mp4,videos/room3.mp4")
    settings = Settings(_env_file=None)
    assert settings.camera_sources == ["0", "videos/room2.mp4", "videos/room3.mp4"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_config.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.config'`

- [ ] **Step 3: Write minimal implementation**

```python
# meridian_hub/config.py
from typing import Literal

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    camera_sources: list[str] = ["0"]
    target_fps: int = 15
    pose_model_path: str = "models/yolo11s-pose.onnx"
    inference_provider: Literal["directml", "cpu"] = "directml"
    facility_id: str = "fac-poc-001"
    building_id: str = "bld-poc-001"
    queue_db_path: str = "data/queue.sqlite3"
    registry_db_path: str = "data/camera_registry.sqlite3"
    mock_backend_url: str = "http://localhost:8000"

    @field_validator("camera_sources", mode="before")
    @classmethod
    def _split_csv(cls, v):
        if isinstance(v, str):
            return [item.strip() for item in v.split(",") if item.strip()]
        return v
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_config.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/config.py tests/test_config.py
git commit -m "Add Settings config with multi-camera support"
```

---

## Task 2: Multi-person pose types

**Files:**
- Create: `meridian_hub/vision/__init__.py`
- Create: `meridian_hub/vision/pose_types.py`
- Test: `tests/test_pose_types.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_pose_types.py
from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES


def _detection(hip_y=100.0, shoulder_y=40.0, confidence=0.9):
    kpts = [Keypoint(x=50.0, y=50.0, confidence=0.9) for _ in range(17)]
    for name, y in [("left_hip", hip_y), ("right_hip", hip_y),
                    ("left_shoulder", shoulder_y), ("right_shoulder", shoulder_y)]:
        i = KEYPOINT_NAMES.index(name)
        kpts[i] = Keypoint(x=kpts[i].x, y=y, confidence=0.9)
    return PersonDetection(keypoints=kpts, bbox=(10.0, shoulder_y - 10, 90.0, hip_y + 60), confidence=confidence, timestamp=1.0)


def test_person_detection_keypoint_lookup():
    det = _detection()
    assert det.get("left_hip").y == 100.0


def test_person_detection_hip_center():
    det = _detection(hip_y=120.0)
    cx, cy = det.hip_center()
    assert cy == 120.0


def test_person_detection_bbox_iou():
    a = PersonDetection(keypoints=[Keypoint(0, 0, 0.9)] * 17, bbox=(0.0, 0.0, 10.0, 10.0), confidence=0.9, timestamp=0.0)
    b = PersonDetection(keypoints=[Keypoint(0, 0, 0.9)] * 17, bbox=(5.0, 5.0, 15.0, 15.0), confidence=0.9, timestamp=0.0)
    c = PersonDetection(keypoints=[Keypoint(0, 0, 0.9)] * 17, bbox=(100.0, 100.0, 110.0, 110.0), confidence=0.9, timestamp=0.0)
    assert a.iou(b) > 0.1
    assert a.iou(c) == 0.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_pose_types.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.vision'`

- [ ] **Step 3: Write minimal implementation**

`meridian_hub/vision/__init__.py`:
```python
```

`meridian_hub/vision/pose_types.py`:
```python
from dataclasses import dataclass

# COCO-17 keypoint order, matching YOLO11-pose's output layout.
KEYPOINT_NAMES = [
    "nose", "left_eye", "right_eye", "left_ear", "right_ear",
    "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
    "left_wrist", "right_wrist", "left_hip", "right_hip",
    "left_knee", "right_knee", "left_ankle", "right_ankle",
]

BBox = tuple[float, float, float, float]  # x1, y1, x2, y2


@dataclass(frozen=True)
class Keypoint:
    x: float
    y: float
    confidence: float


@dataclass(frozen=True)
class PersonDetection:
    """One detected person in one frame -- pre-tracking. A frame with two
    people in it produces two of these."""

    keypoints: list[Keypoint]
    bbox: BBox
    confidence: float
    timestamp: float

    def get(self, name: str) -> Keypoint:
        return self.keypoints[KEYPOINT_NAMES.index(name)]

    def hip_center(self) -> tuple[float, float]:
        left = self.get("left_hip")
        right = self.get("right_hip")
        return (left.x + right.x) / 2.0, (left.y + right.y) / 2.0

    def shoulder_center(self) -> tuple[float, float]:
        left = self.get("left_shoulder")
        right = self.get("right_shoulder")
        return (left.x + right.x) / 2.0, (left.y + right.y) / 2.0

    def iou(self, other: "PersonDetection") -> float:
        ax1, ay1, ax2, ay2 = self.bbox
        bx1, by1, bx2, by2 = other.bbox
        ix1, iy1 = max(ax1, bx1), max(ay1, by1)
        ix2, iy2 = min(ax2, bx2), min(ay2, by2)
        iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
        intersection = iw * ih
        if intersection == 0.0:
            return 0.0
        area_a = (ax2 - ax1) * (ay2 - ay1)
        area_b = (bx2 - bx1) * (by2 - by1)
        union = area_a + area_b - intersection
        return intersection / union if union > 0 else 0.0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_pose_types.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/vision/__init__.py meridian_hub/vision/pose_types.py tests/test_pose_types.py
git commit -m "Add multi-person PersonDetection type with IoU for tracking"
```

---

## Task 3: Camera source abstraction

**Files:**
- Create: `meridian_hub/capture/__init__.py`
- Create: `meridian_hub/capture/camera_source.py`
- Test: `tests/test_camera_source.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_camera_source.py
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_camera_source.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.capture'`

- [ ] **Step 3: Write minimal implementation**

`meridian_hub/capture/__init__.py`:
```python
```

`meridian_hub/capture/camera_source.py`:
```python
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_camera_source.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/capture/__init__.py meridian_hub/capture/camera_source.py tests/test_camera_source.py
git commit -m "Add CameraSource abstraction over cv2.VideoCapture-compatible sources"
```

---

## Task 4: Camera registry

**Files:**
- Create: `meridian_hub/capture/camera_registry.py`
- Test: `tests/test_camera_registry.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_camera_registry.py
import tempfile
from pathlib import Path

from meridian_hub.capture.camera_registry import CameraRegistry, CameraRecord


def _registry():
    db_path = Path(tempfile.mkdtemp()) / "registry.sqlite3"
    return CameraRegistry(db_path=str(db_path))


def test_register_and_lookup():
    registry = _registry()
    record = CameraRecord(
        camera_id="cam-101", facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-101", resident_id="res-9",
        source="0", privacy_state="active",
    )
    registry.register(record)
    fetched = registry.get("cam-101")
    assert fetched.room_id == "room-101"
    assert fetched.resident_id == "res-9"


def test_lookup_missing_returns_none():
    registry = _registry()
    assert registry.get("does-not-exist") is None


def test_register_upserts_existing():
    registry = _registry()
    registry.register(CameraRecord(
        camera_id="cam-1", facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id=None,
        source="0", privacy_state="active",
    ))
    registry.register(CameraRecord(
        camera_id="cam-1", facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-42",
        source="0", privacy_state="active",
    ))
    assert registry.get("cam-1").resident_id == "res-42"
    assert len(registry.list_all()) == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_camera_registry.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.capture.camera_registry'`

- [ ] **Step 3: Write minimal implementation**

```python
# meridian_hub/capture/camera_registry.py
import sqlite3
from dataclasses import dataclass, fields


@dataclass
class CameraRecord:
    camera_id: str
    facility_id: str
    building_id: str
    floor_id: str
    room_id: str
    resident_id: str | None
    source: str
    privacy_state: str


class CameraRegistry:
    """PRD section 15.1: camera_id -> facility/building/floor/room/resident
    mapping. SQLite-backed for the POC."""

    def __init__(self, db_path: str):
        self._conn = sqlite3.connect(db_path)
        self._conn.execute(
            """CREATE TABLE IF NOT EXISTS cameras (
                camera_id TEXT PRIMARY KEY, facility_id TEXT, building_id TEXT,
                floor_id TEXT, room_id TEXT, resident_id TEXT,
                source TEXT, privacy_state TEXT
            )"""
        )
        self._conn.commit()

    def register(self, record: CameraRecord) -> None:
        cols = [f.name for f in fields(CameraRecord)]
        placeholders = ", ".join("?" for _ in cols)
        values = [getattr(record, c) for c in cols]
        self._conn.execute(
            f"INSERT INTO cameras ({', '.join(cols)}) VALUES ({placeholders}) "
            f"ON CONFLICT(camera_id) DO UPDATE SET "
            + ", ".join(f"{c}=excluded.{c}" for c in cols if c != "camera_id"),
            values,
        )
        self._conn.commit()

    def get(self, camera_id: str) -> CameraRecord | None:
        row = self._conn.execute(
            "SELECT camera_id, facility_id, building_id, floor_id, room_id, "
            "resident_id, source, privacy_state FROM cameras WHERE camera_id = ?",
            (camera_id,),
        ).fetchone()
        return CameraRecord(*row) if row else None

    def list_all(self) -> list[CameraRecord]:
        rows = self._conn.execute(
            "SELECT camera_id, facility_id, building_id, floor_id, room_id, "
            "resident_id, source, privacy_state FROM cameras"
        ).fetchall()
        return [CameraRecord(*row) for row in rows]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_camera_registry.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/capture/camera_registry.py tests/test_camera_registry.py
git commit -m "Add SQLite-backed camera registry"
```

---

## Task 5: Stream ingestion (per-camera health tracking)

**Files:**
- Create: `meridian_hub/ingestion/__init__.py`
- Create: `meridian_hub/ingestion/stream_ingestion.py`
- Test: `tests/test_stream_ingestion.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_stream_ingestion.py
import numpy as np

from meridian_hub.ingestion.stream_ingestion import StreamHealthTracker


def test_fps_computed_from_frame_timestamps():
    tracker = StreamHealthTracker(camera_id="cam-1")
    frame = np.zeros((4, 4, 3), dtype=np.uint8)
    for t in [0.0, 0.1, 0.2, 0.3, 0.4]:
        tracker.record_frame(frame, timestamp=t)
    assert 9.0 < tracker.current_fps() < 11.0


def test_detects_frozen_stream():
    tracker = StreamHealthTracker(camera_id="cam-1")
    frame = np.full((4, 4, 3), 7, dtype=np.uint8)
    for t in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]:
        tracker.record_frame(frame, timestamp=t)
    assert tracker.is_frozen(threshold_seconds=3.0) is True


def test_not_frozen_when_frames_change():
    tracker = StreamHealthTracker(camera_id="cam-1")
    for i, t in enumerate([0.0, 1.0, 2.0, 3.0]):
        frame = np.full((4, 4, 3), i, dtype=np.uint8)
        tracker.record_frame(frame, timestamp=t)
    assert tracker.is_frozen(threshold_seconds=3.0) is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_stream_ingestion.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.ingestion'`

- [ ] **Step 3: Write minimal implementation**

`meridian_hub/ingestion/__init__.py`:
```python
```

`meridian_hub/ingestion/stream_ingestion.py`:
```python
from collections import deque

import numpy as np


class StreamHealthTracker:
    """Per-camera FPS measurement and frozen-frame detection (PRD section
    15.2). Frozen-frame detection compares frame content, not just
    presence of new frames, so a stuck camera producing repeated identical
    frames is caught even if reads keep succeeding."""

    def __init__(self, camera_id: str, window_seconds: float = 5.0):
        self.camera_id = camera_id
        self.window_seconds = window_seconds
        self._timestamps: deque[float] = deque()
        self._last_frame: np.ndarray | None = None
        self._last_change_timestamp: float | None = None

    def record_frame(self, frame: np.ndarray, timestamp: float) -> None:
        self._timestamps.append(timestamp)
        cutoff = timestamp - self.window_seconds
        while self._timestamps and self._timestamps[0] < cutoff:
            self._timestamps.popleft()

        if self._last_frame is None or not np.array_equal(frame, self._last_frame):
            self._last_change_timestamp = timestamp
        self._last_frame = frame

    def current_fps(self) -> float:
        if len(self._timestamps) < 2:
            return 0.0
        span = self._timestamps[-1] - self._timestamps[0]
        return (len(self._timestamps) - 1) / span if span > 0 else 0.0

    def is_frozen(self, threshold_seconds: float) -> bool:
        if self._last_change_timestamp is None or not self._timestamps:
            return False
        return (self._timestamps[-1] - self._last_change_timestamp) >= threshold_seconds
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_stream_ingestion.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/ingestion/__init__.py meridian_hub/ingestion/stream_ingestion.py tests/test_stream_ingestion.py
git commit -m "Add per-camera FPS and frozen-frame health tracking"
```

---

## Task 6: IoU-based multi-person tracker

**Files:**
- Create: `meridian_hub/vision/tracker.py`
- Test: `tests/test_tracker.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_tracker.py
from meridian_hub.vision.pose_types import Keypoint, PersonDetection
from meridian_hub.vision.tracker import IouTracker


def _det(bbox, t):
    return PersonDetection(keypoints=[Keypoint(0, 0, 0.9)] * 17, bbox=bbox, confidence=0.9, timestamp=t)


def test_assigns_stable_id_to_moving_person():
    tracker = IouTracker()
    tracks_1 = tracker.update([_det((10, 10, 50, 90), 0.0)])
    tracks_2 = tracker.update([_det((14, 10, 54, 90), 0.1)])  # small shift, same person
    assert tracks_1[0].track_id == tracks_2[0].track_id


def test_assigns_different_ids_to_two_people():
    tracker = IouTracker()
    tracks = tracker.update([
        _det((10, 10, 50, 90), 0.0),
        _det((200, 10, 240, 90), 0.0),
    ])
    ids = {t.track_id for t in tracks}
    assert len(ids) == 2


def test_track_survives_brief_occlusion():
    tracker = IouTracker(max_missed_frames=2)
    first = tracker.update([_det((10, 10, 50, 90), 0.0)])
    track_id = first[0].track_id
    tracker.update([])  # occluded for one tick
    reappeared = tracker.update([_det((12, 10, 52, 90), 0.2)])
    assert reappeared[0].track_id == track_id


def test_track_dropped_after_too_many_missed_frames():
    tracker = IouTracker(max_missed_frames=1)
    first = tracker.update([_det((10, 10, 50, 90), 0.0)])
    track_id = first[0].track_id
    tracker.update([])
    tracker.update([])  # exceeds max_missed_frames
    reappeared = tracker.update([_det((12, 10, 52, 90), 0.3)])
    assert reappeared[0].track_id != track_id
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_tracker.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.vision.tracker'`

- [ ] **Step 3: Write minimal implementation**

```python
# meridian_hub/vision/tracker.py
from dataclasses import dataclass

from meridian_hub.vision.pose_types import PersonDetection

MIN_IOU_TO_MATCH = 0.3


@dataclass(frozen=True)
class TrackedPerson:
    track_id: int
    detection: PersonDetection


class IouTracker:
    """Assigns a stable track_id per person within one camera by matching
    each new detection to the closest prior track by bounding-box IoU.
    Tolerates max_missed_frames of no matching detection (brief occlusion)
    before dropping a track -- PRD section 15.5."""

    def __init__(self, max_missed_frames: int = 5):
        self.max_missed_frames = max_missed_frames
        self._next_id = 1
        self._active: dict[int, PersonDetection] = {}
        self._missed: dict[int, int] = {}

    def update(self, detections: list[PersonDetection]) -> list[TrackedPerson]:
        unmatched_detections = list(detections)
        matched_track_ids: set[int] = set()
        results: list[TrackedPerson] = []

        for track_id, prior in list(self._active.items()):
            best_match, best_iou = None, 0.0
            for det in unmatched_detections:
                iou = prior.iou(det)
                if iou > best_iou:
                    best_match, best_iou = det, iou
            if best_match is not None and best_iou >= MIN_IOU_TO_MATCH:
                self._active[track_id] = best_match
                self._missed[track_id] = 0
                unmatched_detections.remove(best_match)
                matched_track_ids.add(track_id)
                results.append(TrackedPerson(track_id=track_id, detection=best_match))

        for track_id in list(self._active.keys()):
            if track_id not in matched_track_ids:
                self._missed[track_id] = self._missed.get(track_id, 0) + 1
                if self._missed[track_id] > self.max_missed_frames:
                    del self._active[track_id]
                    del self._missed[track_id]

        for det in unmatched_detections:
            track_id = self._next_id
            self._next_id += 1
            self._active[track_id] = det
            self._missed[track_id] = 0
            results.append(TrackedPerson(track_id=track_id, detection=det))

        return results
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_tracker.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/vision/tracker.py tests/test_tracker.py
git commit -m "Add IoU-based multi-person tracker with occlusion tolerance"
```

---

## Task 7: Per-track kinematic feature window

**Files:**
- Create: `meridian_hub/features/__init__.py`
- Create: `meridian_hub/features/feature_window.py`
- Test: `tests/test_feature_window.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_feature_window.py
from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES
from meridian_hub.features.feature_window import TrackFeatureManager


def _detection(t, hip_y, shoulder_y, hip_x=50.0, shoulder_x=50.0):
    kpts = [Keypoint(x=0.0, y=0.0, confidence=0.9) for _ in range(17)]
    for name, x, y in [
        ("left_hip", hip_x - 5, hip_y), ("right_hip", hip_x + 5, hip_y),
        ("left_shoulder", shoulder_x - 5, shoulder_y), ("right_shoulder", shoulder_x + 5, shoulder_y),
        ("left_ankle", hip_x - 10, hip_y + 50), ("right_ankle", hip_x + 10, hip_y + 50),
    ]:
        kpts[KEYPOINT_NAMES.index(name)] = Keypoint(x=x, y=y, confidence=0.9)
    return PersonDetection(keypoints=kpts, bbox=(0, 0, 100, 200), confidence=0.9, timestamp=t)


def test_tracks_are_independent():
    manager = TrackFeatureManager()
    manager.update(track_id=1, detection=_detection(0.0, hip_y=100.0, shoulder_y=40.0))
    manager.update(track_id=2, detection=_detection(0.0, hip_y=180.0, shoulder_y=175.0))
    f1 = manager.compute(track_id=1)
    f2 = manager.compute(track_id=2)
    assert f1.torso_angle_degrees < 20.0
    assert f2.torso_angle_degrees >= 0.0


def test_drop_track_removes_its_window():
    manager = TrackFeatureManager()
    manager.update(track_id=1, detection=_detection(0.0, hip_y=100.0, shoulder_y=40.0))
    manager.drop_track(1)
    assert manager.compute(track_id=1).hip_vertical_velocity == 0.0


def test_prune_removes_stale_tracks():
    manager = TrackFeatureManager()
    manager.update(track_id=1, detection=_detection(0.0, hip_y=100.0, shoulder_y=40.0))
    manager.update(track_id=2, detection=_detection(0.0, hip_y=100.0, shoulder_y=40.0))
    manager.prune(active_track_ids={2})
    assert manager.compute(track_id=1).hip_vertical_velocity == 0.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_feature_window.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.features'`

- [ ] **Step 3: Write minimal implementation**

`meridian_hub/features/__init__.py`:
```python
```

`meridian_hub/features/feature_window.py`:
```python
import math
from collections import deque
from dataclasses import dataclass

from meridian_hub.vision.pose_types import PersonDetection

STILLNESS_EPSILON_PX = 3.0


@dataclass(frozen=True)
class KinematicFeatures:
    hip_vertical_velocity: float  # px/sec, positive = moving down
    torso_angle_degrees: float  # 0 = upright, 90 = horizontal
    aspect_ratio: float
    stillness_duration_seconds: float


class _SingleTrackWindow:
    def __init__(self, window_seconds: float):
        self.window_seconds = window_seconds
        self._detections: deque[PersonDetection] = deque()

    def add(self, detection: PersonDetection) -> None:
        self._detections.append(detection)
        cutoff = detection.timestamp - self.window_seconds
        while self._detections and self._detections[0].timestamp < cutoff:
            self._detections.popleft()

    def compute(self) -> KinematicFeatures:
        if len(self._detections) < 2:
            return KinematicFeatures(0.0, 0.0, 1.0, 0.0)

        dets = list(self._detections)
        first, last = dets[0], dets[-1]
        dt = last.timestamp - first.timestamp
        _, first_hy = first.hip_center()
        _, last_hy = last.hip_center()
        velocity = (last_hy - first_hy) / dt if dt > 0 else 0.0

        sx, sy = last.shoulder_center()
        hx, hy = last.hip_center()
        angle = math.degrees(math.atan2(abs(hx - sx), abs(hy - sy) + 1e-6))

        left_ankle = last.get("left_ankle")
        right_ankle = last.get("right_ankle")
        body_width = abs(right_ankle.x - left_ankle.x) + 20.0
        body_height = max(abs(left_ankle.y - sy), 1.0)
        aspect_ratio = body_width / body_height

        stillness = 0.0
        for i in range(len(dets) - 1, 0, -1):
            _, hy_curr = dets[i].hip_center()
            _, hy_prev = dets[i - 1].hip_center()
            if abs(hy_curr - hy_prev) <= STILLNESS_EPSILON_PX:
                stillness = dets[-1].timestamp - dets[i - 1].timestamp
            else:
                break

        return KinematicFeatures(velocity, angle, aspect_ratio, stillness)


class TrackFeatureManager:
    """Owns one sliding-window feature extractor per track_id. The Hub
    daemon calls update() every tick for every currently-tracked person,
    and prune() with the set of still-active track_ids so windows for
    people who've left frame don't leak memory forever."""

    def __init__(self, window_seconds: float = 3.0):
        self.window_seconds = window_seconds
        self._windows: dict[int, _SingleTrackWindow] = {}

    def update(self, track_id: int, detection: PersonDetection) -> None:
        if track_id not in self._windows:
            self._windows[track_id] = _SingleTrackWindow(self.window_seconds)
        self._windows[track_id].add(detection)

    def compute(self, track_id: int) -> KinematicFeatures:
        window = self._windows.get(track_id)
        if window is None:
            return KinematicFeatures(0.0, 0.0, 1.0, 0.0)
        return window.compute()

    def drop_track(self, track_id: int) -> None:
        self._windows.pop(track_id, None)

    def prune(self, active_track_ids: set[int]) -> None:
        for track_id in list(self._windows.keys()):
            if track_id not in active_track_ids:
                self.drop_track(track_id)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_feature_window.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/features/__init__.py meridian_hub/features/feature_window.py tests/test_feature_window.py
git commit -m "Add per-track kinematic feature window manager"
```

---

## Task 8: Fall detection state machine

**Files:**
- Create: `meridian_hub/classifiers/__init__.py`
- Create: `meridian_hub/classifiers/thresholds.py`
- Create: `meridian_hub/classifiers/fall_types.py`
- Create: `meridian_hub/classifiers/fall_state_machine.py`
- Test: `tests/test_fall_state_machine.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_fall_state_machine.py
from meridian_hub.features.feature_window import KinematicFeatures
from meridian_hub.classifiers.fall_state_machine import FallStateMachine
from meridian_hub.classifiers.fall_types import FallState


def _features(velocity=0.0, angle=5.0, aspect_ratio=0.4, stillness=0.0):
    return KinematicFeatures(velocity, angle, aspect_ratio, stillness)


def test_stays_normal_when_standing_still():
    machine = FallStateMachine(track_id=1)
    event = None
    for t in [0.0, 0.5, 1.0]:
        event = machine.update(_features(velocity=0.0, angle=5.0), timestamp=t)
    assert machine.state == FallState.NORMAL
    assert event is None


def test_confirms_fall_on_drop_plus_sustained_stillness_horizontal():
    machine = FallStateMachine(track_id=1)
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=0.0)
    machine.update(_features(velocity=250.0, angle=70.0, aspect_ratio=1.8, stillness=0.0), timestamp=0.5)
    event = machine.update(_features(velocity=0.0, angle=75.0, aspect_ratio=1.8, stillness=2.1), timestamp=2.6)
    assert machine.state == FallState.CONFIRMED
    assert event is not None
    assert event.state == FallState.CONFIRMED
    assert event.track_id == 1


def test_suspected_when_signals_borderline():
    machine = FallStateMachine(track_id=1)
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=0.0)
    machine.update(_features(velocity=140.0, angle=40.0, aspect_ratio=0.9, stillness=0.0), timestamp=0.5)
    event = machine.update(_features(velocity=5.0, angle=42.0, aspect_ratio=0.9, stillness=0.6), timestamp=1.5)
    assert machine.state == FallState.SUSPECTED
    assert event is not None
    assert event.state == FallState.SUSPECTED


def test_clears_when_recovers_without_crossing_ambiguous_band():
    machine = FallStateMachine(track_id=1)
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=0.0)
    machine.update(_features(velocity=130.0, angle=32.0, aspect_ratio=0.6, stillness=0.0), timestamp=0.3)
    event = machine.update(_features(velocity=0.0, angle=8.0, aspect_ratio=0.4, stillness=0.0), timestamp=0.6)
    assert machine.state == FallState.NORMAL
    assert event is None or event.state == FallState.CLEARED


def test_confirmed_path_never_requires_any_io():
    import inspect
    source = inspect.getsource(FallStateMachine.update)
    for banned in ("requests", "socket", "sqlite3", "open("):
        assert banned not in source
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_fall_state_machine.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.classifiers'`

- [ ] **Step 3: Write minimal implementation**

`meridian_hub/classifiers/__init__.py`:
```python
```

`meridian_hub/classifiers/thresholds.py`:
```python
# Tunable against real recorded test clips without touching state-machine
# logic (PRD section 28.1's staged-event validation protocol).

VELOCITY_CANDIDATE_THRESHOLD = 120.0  # px/sec downward, triggers FALL_CANDIDATE
ANGLE_CANDIDATE_THRESHOLD_DEGREES = 30.0

VELOCITY_CONFIRM_THRESHOLD = 200.0
ANGLE_CONFIRM_THRESHOLD_DEGREES = 55.0
ASPECT_RATIO_HORIZONTAL_THRESHOLD = 1.2
STILLNESS_CONFIRM_SECONDS = 2.0

CANDIDATE_WINDOW_SECONDS = 3.0
```

`meridian_hub/classifiers/fall_types.py`:
```python
from dataclasses import dataclass
from enum import Enum, auto


class FallState(Enum):
    NORMAL = auto()
    FALL_CANDIDATE = auto()
    CONFIRMED = auto()
    SUSPECTED = auto()
    CLEARED = auto()


@dataclass(frozen=True)
class FallEvent:
    track_id: int
    state: FallState
    timestamp: float
```

`meridian_hub/classifiers/fall_state_machine.py`:
```python
from meridian_hub.classifiers import thresholds as T
from meridian_hub.classifiers.fall_types import FallEvent, FallState
from meridian_hub.features.feature_window import KinematicFeatures


class FallStateMachine:
    """NORMAL -> FALL_CANDIDATE -> {CONFIRMED, SUSPECTED, CLEARED} -> NORMAL.
    One instance per tracked person. CONFIRMED fires immediately on
    crossing thresholds -- no I/O, no network, so it can never be delayed
    by anything external (design spec section 2.1's real-time guarantee)."""

    def __init__(self, track_id: int):
        self.track_id = track_id
        self.state = FallState.NORMAL
        self._candidate_since: float | None = None

    def update(self, features: KinematicFeatures, timestamp: float) -> FallEvent | None:
        if self.state == FallState.NORMAL:
            if (features.hip_vertical_velocity >= T.VELOCITY_CANDIDATE_THRESHOLD
                    and features.torso_angle_degrees >= T.ANGLE_CANDIDATE_THRESHOLD_DEGREES):
                self.state = FallState.FALL_CANDIDATE
                self._candidate_since = timestamp
            return None

        if self.state == FallState.FALL_CANDIDATE:
            elapsed = timestamp - (self._candidate_since or timestamp)

            is_horizontal_and_still = (
                features.aspect_ratio >= T.ASPECT_RATIO_HORIZONTAL_THRESHOLD
                and features.stillness_duration_seconds >= T.STILLNESS_CONFIRM_SECONDS
            )
            high_confidence = (
                features.torso_angle_degrees >= T.ANGLE_CONFIRM_THRESHOLD_DEGREES
                or features.hip_vertical_velocity >= T.VELOCITY_CONFIRM_THRESHOLD
            )
            if is_horizontal_and_still and high_confidence:
                self.state = FallState.CONFIRMED
                return FallEvent(self.track_id, FallState.CONFIRMED, timestamp)

            recovered = (
                features.torso_angle_degrees < T.ANGLE_CANDIDATE_THRESHOLD_DEGREES
                and features.hip_vertical_velocity < T.VELOCITY_CANDIDATE_THRESHOLD
                and features.stillness_duration_seconds == 0.0
            )
            if recovered:
                self.state = FallState.NORMAL
                self._candidate_since = None
                return FallEvent(self.track_id, FallState.CLEARED, timestamp)

            if elapsed >= T.CANDIDATE_WINDOW_SECONDS:
                self.state = FallState.SUSPECTED
                return FallEvent(self.track_id, FallState.SUSPECTED, timestamp)

            if is_horizontal_and_still or (
                features.torso_angle_degrees >= T.ANGLE_CANDIDATE_THRESHOLD_DEGREES
                and features.stillness_duration_seconds > 0.0
                and not high_confidence
            ):
                self.state = FallState.SUSPECTED
                return FallEvent(self.track_id, FallState.SUSPECTED, timestamp)

            return None

        # CONFIRMED/SUSPECTED/CLEARED: caller resets the machine (fresh
        # instance) once an incident is resolved -- this class only owns
        # detection, not incident lifecycle.
        return None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_fall_state_machine.py -v`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/classifiers/__init__.py meridian_hub/classifiers/thresholds.py meridian_hub/classifiers/fall_types.py meridian_hub/classifiers/fall_state_machine.py tests/test_fall_state_machine.py
git commit -m "Add per-track fall detection state machine"
```

---

## Task 9: Long-lie / unusual-inactivity detector

**Files:**
- Create: `meridian_hub/classifiers/long_lie.py`
- Test: `tests/test_long_lie.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_long_lie.py
from meridian_hub.classifiers.long_lie import LongLieDetector


def test_no_event_for_brief_floor_time():
    detector = LongLieDetector(track_id=1, floor_threshold_seconds=300.0)
    event = None
    for t in [0.0, 60.0, 120.0]:
        event = detector.update(floor_level=True, timestamp=t)
    assert event is None


def test_fires_after_sustained_floor_level_duration():
    detector = LongLieDetector(track_id=1, floor_threshold_seconds=300.0)
    event = None
    for t in [0.0, 100.0, 200.0, 301.0]:
        event = detector.update(floor_level=True, timestamp=t)
    assert event is not None
    assert event.track_id == 1


def test_fires_only_once_per_episode():
    detector = LongLieDetector(track_id=1, floor_threshold_seconds=100.0)
    events = [detector.update(floor_level=True, timestamp=t) for t in [0.0, 50.0, 101.0, 150.0, 200.0]]
    fired = [e for e in events if e is not None]
    assert len(fired) == 1


def test_resets_when_person_gets_up():
    detector = LongLieDetector(track_id=1, floor_threshold_seconds=100.0)
    detector.update(floor_level=True, timestamp=0.0)
    detector.update(floor_level=True, timestamp=50.0)
    detector.update(floor_level=False, timestamp=60.0)  # got up
    event = detector.update(floor_level=True, timestamp=161.0)  # back down, but only 101s since getting up
    assert event is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_long_lie.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.classifiers.long_lie'`

- [ ] **Step 3: Write minimal implementation**

```python
# meridian_hub/classifiers/long_lie.py
from dataclasses import dataclass


@dataclass(frozen=True)
class LongLieEvent:
    track_id: int
    timestamp: float
    floor_duration_seconds: float


class LongLieDetector:
    """PRD section 8.4: flags sustained floor-level posture beyond what a
    fall-confirmation stillness window already covers. One instance per
    tracked person. Day/night baseline and bed-zone awareness (so normal
    sleep isn't flagged) are layered on in Part 2 via night_rounds/zone
    components -- this is the core duration-tracking primitive they build
    on. Fires once per continuous floor-level episode, not repeatedly,
    since the event engine's own cooldown (Part 2) handles delivery-level
    dedup; this class handles detection-level dedup so it emits a clean
    single signal per real episode."""

    def __init__(self, track_id: int, floor_threshold_seconds: float = 300.0):
        self.track_id = track_id
        self.floor_threshold_seconds = floor_threshold_seconds
        self._floor_since: float | None = None
        self._fired_this_episode = False

    def update(self, floor_level: bool, timestamp: float) -> LongLieEvent | None:
        if not floor_level:
            self._floor_since = None
            self._fired_this_episode = False
            return None

        if self._floor_since is None:
            self._floor_since = timestamp

        duration = timestamp - self._floor_since
        if duration >= self.floor_threshold_seconds and not self._fired_this_episode:
            self._fired_this_episode = True
            return LongLieEvent(self.track_id, timestamp, duration)
        return None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_long_lie.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/classifiers/long_lie.py tests/test_long_lie.py
git commit -m "Add long-lie/unusual-inactivity duration detector"
```

---

## Task 10: Local heuristic fall validator

**Files:**
- Create: `meridian_hub/validation/__init__.py`
- Create: `meridian_hub/validation/local_validator.py`
- Test: `tests/test_local_validator.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_local_validator.py
from meridian_hub.features.feature_window import KinematicFeatures
from meridian_hub.validation.local_validator import LocalHeuristicValidator, ValidationOutcome


def test_confirms_clear_fall_pattern():
    validator = LocalHeuristicValidator()
    features = KinematicFeatures(hip_vertical_velocity=210.0, torso_angle_degrees=72.0, aspect_ratio=1.6, stillness_duration_seconds=2.2)
    result = validator.validate(features)
    assert result.outcome == ValidationOutcome.FALL_CONFIRMED
    assert result.confidence > 0.5
    assert "aspect_ratio" in result.rationale or "Horizontal" in result.rationale


def test_flags_false_positive_for_quick_recovery():
    validator = LocalHeuristicValidator()
    features = KinematicFeatures(hip_vertical_velocity=30.0, torso_angle_degrees=35.0, aspect_ratio=0.7, stillness_duration_seconds=0.2)
    result = validator.validate(features)
    assert result.outcome == ValidationOutcome.FALSE_POSITIVE_SITTING


def test_inconclusive_for_ambiguous_signals():
    validator = LocalHeuristicValidator()
    features = KinematicFeatures(hip_vertical_velocity=90.0, torso_angle_degrees=45.0, aspect_ratio=1.0, stillness_duration_seconds=1.0)
    result = validator.validate(features)
    assert result.outcome == ValidationOutcome.INCONCLUSIVE


def test_validate_has_no_network_or_disk_io():
    import inspect
    source = inspect.getsource(LocalHeuristicValidator.validate)
    for banned in ("requests", "socket", "sqlite3", "urlopen"):
        assert banned not in source
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_local_validator.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.validation'`

- [ ] **Step 3: Write minimal implementation**

`meridian_hub/validation/__init__.py`:
```python
```

`meridian_hub/validation/local_validator.py`:
```python
from dataclasses import dataclass
from enum import Enum, auto

from meridian_hub.features.feature_window import KinematicFeatures

CONFIRM_ASPECT_RATIO = 1.3
CONFIRM_STILLNESS_SECONDS = 1.5
CONFIRM_ANGLE_DEGREES = 60.0

FALSE_POSITIVE_STILLNESS_SECONDS = 0.5
FALSE_POSITIVE_VELOCITY = 50.0


class ValidationOutcome(Enum):
    FALL_CONFIRMED = auto()
    FALSE_POSITIVE_SITTING = auto()
    FALSE_POSITIVE_OBJECT_DROP = auto()
    INCONCLUSIVE = auto()


@dataclass(frozen=True)
class ValidationResult:
    outcome: ValidationOutcome
    confidence: float
    rationale: str


class LocalHeuristicValidator:
    """A second, independent pass over an ambiguous fall candidate's
    feature snapshot -- deliberately uses stricter thresholds than the
    primary state machine's own SUSPECTED band, so it catches different
    mistakes rather than rubber-stamping the same logic twice. Runs
    synchronously, no I/O, in-process (design spec section 2.1's
    real-time guarantee). The "fail open to CONFIRMED on inconclusive"
    policy belongs to the caller (event engine), not this class -- this
    class only classifies, it doesn't decide what to do about it."""

    def validate(self, features: KinematicFeatures) -> ValidationResult:
        if (features.aspect_ratio >= CONFIRM_ASPECT_RATIO
                and features.stillness_duration_seconds >= CONFIRM_STILLNESS_SECONDS
                and features.torso_angle_degrees >= CONFIRM_ANGLE_DEGREES):
            return ValidationResult(
                ValidationOutcome.FALL_CONFIRMED,
                confidence=0.85,
                rationale=(
                    f"Horizontal posture (aspect_ratio={features.aspect_ratio:.2f}) "
                    f"sustained {features.stillness_duration_seconds:.1f}s with torso "
                    f"angle {features.torso_angle_degrees:.0f} degrees."
                ),
            )

        if (features.stillness_duration_seconds < FALSE_POSITIVE_STILLNESS_SECONDS
                and features.hip_vertical_velocity < FALSE_POSITIVE_VELOCITY):
            return ValidationResult(
                ValidationOutcome.FALSE_POSITIVE_SITTING,
                confidence=0.6,
                rationale="Recovery motion shortly after the drop is consistent with controlled sitting, not a fall.",
            )

        return ValidationResult(
            ValidationOutcome.INCONCLUSIVE,
            confidence=0.3,
            rationale="Signals do not clearly match a confirmed-fall or a known false-positive pattern.",
        )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_local_validator.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/validation/__init__.py meridian_hub/validation/local_validator.py tests/test_local_validator.py
git commit -m "Add local heuristic fall validator (no cloud AI)"
```

---

## Task 11: Canonical event schema and event engine

**Files:**
- Create: `meridian_hub/events/__init__.py`
- Create: `meridian_hub/events/schemas.py`
- Create: `meridian_hub/events/event_engine.py`
- Test: `tests/test_event_engine.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_event_engine.py
from datetime import datetime, timezone

from meridian_hub.events.event_engine import EventEngine
from meridian_hub.events.schemas import MeridianEvent


def _clock_sequence(timestamps):
    it = iter(timestamps)
    return lambda: next(it)


def test_first_alert_for_new_incident_emits_immediately():
    engine = EventEngine(clock=_clock_sequence([datetime(2026, 7, 2, 9, 42, 20, tzinfo=timezone.utc)]))
    event = engine.emit_fall_event(
        camera_id="cam-1", track_id=1, facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-1",
        event_type="fall_confirmed", severity="critical", confidence=0.94,
        detected_at=datetime(2026, 7, 2, 9, 42, 18, tzinfo=timezone.utc),
        reason_codes=["rapid_vertical_drop", "horizontal_torso"],
    )
    assert event is not None
    assert isinstance(event, MeridianEvent)
    assert event.status == "open"
    assert event.event_type == "fall_confirmed"
    assert event.schema_version == "1.0"


def test_duplicate_of_open_incident_is_suppressed():
    engine = EventEngine(clock=_clock_sequence([
        datetime(2026, 7, 2, 9, 42, 20, tzinfo=timezone.utc),
        datetime(2026, 7, 2, 9, 42, 21, tzinfo=timezone.utc),
    ]))
    kwargs = dict(
        camera_id="cam-1", track_id=1, facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-1",
        event_type="fall_confirmed", severity="critical", confidence=0.94,
        detected_at=datetime(2026, 7, 2, 9, 42, 18, tzinfo=timezone.utc),
        reason_codes=["rapid_vertical_drop"],
    )
    first = engine.emit_fall_event(**kwargs)
    second = engine.emit_fall_event(**kwargs)
    assert first is not None
    assert second is None


def test_new_incident_after_resolve_emits_again():
    engine = EventEngine(clock=_clock_sequence([
        datetime(2026, 7, 2, 9, 42, 20, tzinfo=timezone.utc),
        datetime(2026, 7, 2, 10, 0, 0, tzinfo=timezone.utc),
    ]))
    kwargs = dict(
        camera_id="cam-1", track_id=1, facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-1",
        event_type="fall_confirmed", severity="critical", confidence=0.94,
        detected_at=datetime(2026, 7, 2, 9, 42, 18, tzinfo=timezone.utc),
        reason_codes=["rapid_vertical_drop"],
    )
    first = engine.emit_fall_event(**kwargs)
    engine.resolve(camera_id="cam-1", track_id=1, event_type="fall_confirmed")
    second = engine.emit_fall_event(**kwargs)
    assert first is not None
    assert second is not None
    assert first.event_id != second.event_id


def test_event_serializes_to_prd_schema_shape():
    engine = EventEngine(clock=_clock_sequence([datetime(2026, 7, 2, 9, 42, 20, tzinfo=timezone.utc)]))
    event = engine.emit_fall_event(
        camera_id="cam-1", track_id=1, facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-1",
        event_type="fall_confirmed", severity="critical", confidence=0.94,
        detected_at=datetime(2026, 7, 2, 9, 42, 18, tzinfo=timezone.utc),
        reason_codes=["rapid_vertical_drop"],
    )
    payload = event.model_dump(mode="json")
    for key in ["event_id", "schema_version", "facility_id", "building_id", "floor_id",
                "room_id", "resident_id", "camera_id", "event_type", "severity",
                "confidence", "detected_at", "generated_at", "status", "reason_codes", "evidence"]:
        assert key in payload
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_event_engine.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.events'`

- [ ] **Step 3: Write minimal implementation**

`meridian_hub/events/__init__.py`:
```python
```

`meridian_hub/events/schemas.py`:
```python
from datetime import datetime
from typing import Literal

from pydantic import BaseModel

EventType = Literal[
    "fall_suspected", "fall_confirmed", "long_lie", "unusual_inactivity",
    "wandering", "exit_risk", "night_activity", "device_offline",
    "stream_degraded", "medication_visit_missing", "visitor_arrival",
    "visitor_departure",
]
Severity = Literal["info", "warning", "critical"]
EventStatus = Literal["open", "acknowledged", "responding", "resolved", "dismissed_false_alarm", "escalated"]


class Evidence(BaseModel):
    skeleton_available: bool = True
    incident_clip_available_locally: bool = False
    cloud_video_available: bool = False


class DeviceHealthSnapshot(BaseModel):
    stream_fps: float | None = None
    wifi_rssi: int | None = None


class MeridianEvent(BaseModel):
    """PRD section 17's canonical event schema, implemented field-for-field."""

    event_id: str
    schema_version: str = "1.0"
    facility_id: str
    building_id: str
    floor_id: str
    room_id: str
    resident_id: str | None
    camera_id: str
    event_type: EventType
    severity: Severity
    confidence: float
    detected_at: datetime
    generated_at: datetime
    status: EventStatus = "open"
    reason_codes: list[str]
    evidence: Evidence = Evidence()
    device_health: DeviceHealthSnapshot = DeviceHealthSnapshot()
```

`meridian_hub/events/event_engine.py`:
```python
import uuid
from collections.abc import Callable
from datetime import datetime, timezone

from meridian_hub.events.schemas import Evidence, MeridianEvent


class EventEngine:
    """Builds canonical events and suppresses duplicate notifications of
    an already-open incident. Critically: dedup only ever suppresses a
    *repeat* of an incident that's already open -- the first event for
    any (camera_id, track_id, event_type) key always emits immediately,
    with zero added latency. This distinction is what design spec section
    2.1 calls the non-negotiable real-time guarantee, and it's exercised
    directly by test_first_alert_for_new_incident_emits_immediately."""

    def __init__(self, clock: Callable[[], datetime] = lambda: datetime.now(timezone.utc)):
        self._clock = clock
        self._open_incidents: set[tuple[str, int, str]] = set()

    def emit_fall_event(
        self, *, camera_id: str, track_id: int, facility_id: str, building_id: str,
        floor_id: str, room_id: str, resident_id: str | None, event_type: str,
        severity: str, confidence: float, detected_at: datetime, reason_codes: list[str],
    ) -> MeridianEvent | None:
        key = (camera_id, track_id, event_type)
        if key in self._open_incidents:
            return None
        self._open_incidents.add(key)

        return MeridianEvent(
            event_id=f"evt_{uuid.uuid4().hex[:20]}",
            facility_id=facility_id, building_id=building_id, floor_id=floor_id,
            room_id=room_id, resident_id=resident_id, camera_id=camera_id,
            event_type=event_type, severity=severity, confidence=confidence,
            detected_at=detected_at, generated_at=self._clock(), status="open",
            reason_codes=reason_codes, evidence=Evidence(skeleton_available=True),
        )

    def resolve(self, *, camera_id: str, track_id: int, event_type: str) -> None:
        self._open_incidents.discard((camera_id, track_id, event_type))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_event_engine.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/events/__init__.py meridian_hub/events/schemas.py meridian_hub/events/event_engine.py tests/test_event_engine.py
git commit -m "Add canonical PRD-schema event model and dedup-safe event engine"
```

---

## Task 12: Offline durable queue

**Files:**
- Create: `meridian_hub/offline_queue/__init__.py`
- Create: `meridian_hub/offline_queue/queue_store.py`
- Test: `tests/test_offline_queue.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_offline_queue.py
import tempfile
from pathlib import Path

from meridian_hub.offline_queue.queue_store import QueueStore


def _store():
    db_path = Path(tempfile.mkdtemp()) / "queue.sqlite3"
    return QueueStore(db_path=str(db_path))


def test_enqueue_then_pending_returns_item_immediately():
    store = _store()
    item_id = store.enqueue(payload={"event_id": "evt-1", "kind": "fall_confirmed"})
    pending = store.pending(now=0.0)
    assert len(pending) == 1
    assert pending[0].id == item_id
    assert pending[0].payload["event_id"] == "evt-1"


def test_ack_removes_item():
    store = _store()
    item_id = store.enqueue(payload={"event_id": "evt-1"})
    store.ack(item_id)
    assert store.pending(now=0.0) == []


def test_nack_schedules_retry_with_backoff_not_immediate_requeue():
    store = _store()
    item_id = store.enqueue(payload={"event_id": "evt-1"})
    store.nack(item_id, now=0.0)
    assert store.pending(now=0.0) == []  # not immediately retryable
    later = store.pending(now=5.0)
    assert len(later) == 1
    assert later[0].retry_count == 1


def test_idempotency_key_prevents_duplicate_enqueue():
    store = _store()
    first_id = store.enqueue(payload={"event_id": "evt-1"}, idempotency_key="evt-1")
    second_id = store.enqueue(payload={"event_id": "evt-1"}, idempotency_key="evt-1")
    assert first_id == second_id
    assert len(store.pending(now=0.0)) == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_offline_queue.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.offline_queue'`

- [ ] **Step 3: Write minimal implementation**

`meridian_hub/offline_queue/__init__.py`:
```python
```

`meridian_hub/offline_queue/queue_store.py`:
```python
import json
import sqlite3
import uuid
from dataclasses import dataclass

BASE_BACKOFF_SECONDS = 2.0
MAX_BACKOFF_SECONDS = 300.0


@dataclass(frozen=True)
class QueueItem:
    id: str
    payload: dict
    retry_count: int


class QueueStore:
    """SQLite-backed durable queue for outgoing event/health payloads.
    Survives a process restart or a network drop -- items are only
    removed on ack() (a confirmed 2xx delivery). The first enqueue of any
    item is always immediately pending (retry_count 0, next_retry_at =
    enqueue time) -- delivery is only ever delayed after a failed
    attempt, never on the happy path."""

    def __init__(self, db_path: str):
        self._conn = sqlite3.connect(db_path)
        self._conn.execute(
            """CREATE TABLE IF NOT EXISTS queue (
                id TEXT PRIMARY KEY, idempotency_key TEXT UNIQUE,
                payload TEXT, retry_count INTEGER DEFAULT 0,
                next_retry_at REAL
            )"""
        )
        self._conn.commit()

    def enqueue(self, payload: dict, idempotency_key: str | None = None, now: float = 0.0) -> str:
        if idempotency_key is not None:
            existing = self._conn.execute(
                "SELECT id FROM queue WHERE idempotency_key = ?", (idempotency_key,)
            ).fetchone()
            if existing:
                return existing[0]

        item_id = str(uuid.uuid4())
        self._conn.execute(
            "INSERT INTO queue (id, idempotency_key, payload, retry_count, next_retry_at) VALUES (?, ?, ?, 0, ?)",
            (item_id, idempotency_key, json.dumps(payload), now),
        )
        self._conn.commit()
        return item_id

    def pending(self, now: float) -> list[QueueItem]:
        rows = self._conn.execute(
            "SELECT id, payload, retry_count FROM queue WHERE next_retry_at <= ? ORDER BY next_retry_at",
            (now,),
        ).fetchall()
        return [QueueItem(id=r[0], payload=json.loads(r[1]), retry_count=r[2]) for r in rows]

    def ack(self, item_id: str) -> None:
        self._conn.execute("DELETE FROM queue WHERE id = ?", (item_id,))
        self._conn.commit()

    def nack(self, item_id: str, now: float) -> None:
        row = self._conn.execute("SELECT retry_count FROM queue WHERE id = ?", (item_id,)).fetchone()
        if row is None:
            return
        retry_count = row[0] + 1
        backoff = min(BASE_BACKOFF_SECONDS * (2 ** (retry_count - 1)), MAX_BACKOFF_SECONDS)
        self._conn.execute(
            "UPDATE queue SET retry_count = ?, next_retry_at = ? WHERE id = ?",
            (retry_count, now + backoff, item_id),
        )
        self._conn.commit()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_offline_queue.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_hub/offline_queue/__init__.py meridian_hub/offline_queue/queue_store.py tests/test_offline_queue.py
git commit -m "Add SQLite-backed offline queue with idempotency and backoff"
```

---

## Task 13: Device health aggregation

**Files:**
- Modify: `pyproject.toml` (add `psutil`)
- Create: `meridian_hub/device_health/__init__.py`
- Create: `meridian_hub/device_health/health_monitor.py`
- Test: `tests/test_device_health.py`

- [ ] **Step 1: Add `psutil` to `pyproject.toml` dependencies**

In `pyproject.toml`, add `"psutil>=6.0",` to the `dependencies` list (alongside `onnxruntime-directml`, `opencv-python`, etc.).

Run: `python3 -m pip install -e ".[dev]"`
Expected: installs `psutil` without error.

- [ ] **Step 2: Write the failing test**

```python
# tests/test_device_health.py
from meridian_hub.device_health.health_monitor import DeviceHealthMonitor
from meridian_hub.ingestion.stream_ingestion import StreamHealthTracker
import numpy as np


def test_hub_snapshot_reports_resource_usage():
    monitor = DeviceHealthMonitor(
        start_time=0.0, cpu_percent_fn=lambda: 42.5, memory_percent_fn=lambda: 61.0
    )
    snapshot = monitor.hub_snapshot(camera_trackers={}, queue_depth=3, now=120.0)
    assert snapshot.uptime_s == 120.0
    assert snapshot.cpu_percent == 42.5
    assert snapshot.memory_percent == 61.0
    assert snapshot.queue_depth == 3


def test_hub_snapshot_counts_offline_cameras():
    monitor = DeviceHealthMonitor(start_time=0.0, cpu_percent_fn=lambda: 0.0, memory_percent_fn=lambda: 0.0)
    healthy = StreamHealthTracker(camera_id="cam-1")
    healthy.record_frame(np.zeros((2, 2, 3), dtype=np.uint8), timestamp=0.0)
    frozen = StreamHealthTracker(camera_id="cam-2")
    frame = np.full((2, 2, 3), 5, dtype=np.uint8)
    for t in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]:
        frozen.record_frame(frame, timestamp=t)
    snapshot = monitor.hub_snapshot(
        camera_trackers={"cam-1": healthy, "cam-2": frozen}, queue_depth=0, now=5.0
    )
    assert snapshot.camera_count == 2
    assert snapshot.cameras_offline == 1


def test_camera_snapshot_reports_fps_and_frozen_state():
    monitor = DeviceHealthMonitor(start_time=0.0, cpu_percent_fn=lambda: 0.0, memory_percent_fn=lambda: 0.0)
    tracker = StreamHealthTracker(camera_id="cam-1")
    frame = np.zeros((2, 2, 3), dtype=np.uint8)
    for t in [0.0, 0.1, 0.2]:
        tracker.record_frame(frame, timestamp=t)
    snapshot = monitor.camera_snapshot(camera_id="cam-1", tracker=tracker)
    assert snapshot.camera_id == "cam-1"
    assert snapshot.fps >= 0.0
    assert isinstance(snapshot.frozen, bool)
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pytest tests/test_device_health.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_hub.device_health'`

- [ ] **Step 4: Write minimal implementation**

`meridian_hub/device_health/__init__.py`:
```python
```

`meridian_hub/device_health/health_monitor.py`:
```python
from collections.abc import Callable
from dataclasses import dataclass

import psutil

from meridian_hub.ingestion.stream_ingestion import StreamHealthTracker

FROZEN_THRESHOLD_SECONDS = 10.0


@dataclass(frozen=True)
class HubHealthSnapshot:
    uptime_s: float
    cpu_percent: float
    memory_percent: float
    camera_count: int
    cameras_offline: int
    queue_depth: int


@dataclass(frozen=True)
class CameraHealthSnapshot:
    camera_id: str
    fps: float
    frozen: bool


class DeviceHealthMonitor:
    """PRD sections 19.2/19.3: Hub-level and per-camera health payloads.
    CPU/memory readers are injected so tests don't depend on real system
    load (mirrors the clock-injection pattern in EventEngine)."""

    def __init__(
        self, start_time: float,
        cpu_percent_fn: Callable[[], float] = lambda: psutil.cpu_percent(),
        memory_percent_fn: Callable[[], float] = lambda: psutil.virtual_memory().percent,
    ):
        self._start_time = start_time
        self._cpu_percent_fn = cpu_percent_fn
        self._memory_percent_fn = memory_percent_fn

    def hub_snapshot(
        self, camera_trackers: dict[str, StreamHealthTracker], queue_depth: int, now: float,
    ) -> HubHealthSnapshot:
        offline = sum(
            1 for tracker in camera_trackers.values()
            if tracker.is_frozen(threshold_seconds=FROZEN_THRESHOLD_SECONDS)
        )
        return HubHealthSnapshot(
            uptime_s=now - self._start_time,
            cpu_percent=self._cpu_percent_fn(),
            memory_percent=self._memory_percent_fn(),
            camera_count=len(camera_trackers),
            cameras_offline=offline,
            queue_depth=queue_depth,
        )

    def camera_snapshot(self, camera_id: str, tracker: StreamHealthTracker) -> CameraHealthSnapshot:
        return CameraHealthSnapshot(
            camera_id=camera_id,
            fps=tracker.current_fps(),
            frozen=tracker.is_frozen(threshold_seconds=FROZEN_THRESHOLD_SECONDS),
        )
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pytest tests/test_device_health.py -v`
Expected: PASS (3 passed)

- [ ] **Step 6: Commit**

```bash
git add pyproject.toml meridian_hub/device_health/__init__.py meridian_hub/device_health/health_monitor.py tests/test_device_health.py
git commit -m "Add Hub and per-camera device health aggregation"
```

---
