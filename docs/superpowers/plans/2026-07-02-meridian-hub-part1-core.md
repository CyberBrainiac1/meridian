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
