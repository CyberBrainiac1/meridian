# Meridian Sense Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `meridian_sense` Python package — camera capture, ONNX-Runtime pose estimation, fall-detection state machine, local (no-cloud) validation, offline SQLite alert queue, InsightFace visitor logging, v1 risk scoring, and a mock cloud ingestion server — runnable today against a webcam/video file on this dev machine, and validated end-to-end on the real Pi 4B unit reachable over SSH.

**Architecture:** A single real-time pipeline (capture → pose → features → fall state machine → local validator → offline queue → alert dispatch) plus a parallel face-detection/recognition → visitor-log path, both funneling through the same SQLite-backed durable queue and HTTP dispatcher. See `docs/superpowers/specs/2026-07-02-meridian-sense-design.md` (revision c) for the full design and `docs/meridian-sense-integration-prd.md` for the wire contract.

**Tech Stack:** Python 3.11+ (dev machine) / 3.13 (Pi), `onnxruntime`, `opencv-python`, `insightface`, `numpy`, `pydantic`/`pydantic-settings`, `fastapi`+`uvicorn` (mock cloud server), `pytest`. Build-time only (never on the Pi): `ultralytics`, `torch`.

---

## Task 0: Project scaffolding

**Files:**
- Create: `pyproject.toml`
- Create: `.env.example`
- Create: `.gitignore`
- Create: `meridian_sense/__init__.py`
- Create: `tests/__init__.py`
- Create: `tests/fixtures/.gitkeep`

- [ ] **Step 1: Create `pyproject.toml`**

```toml
[project]
name = "meridian-sense"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "onnxruntime>=1.20",
    "opencv-python-headless>=4.10",
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
include = ["meridian_sense*", "mock_cloud*"]
```

- [ ] **Step 2: Create `.env.example`**

```bash
CAMERA_SOURCE=0
TARGET_FPS=10
CAPTURE_WIDTH=320
CAPTURE_HEIGHT=256
POSE_MODEL_PATH=models/yolo11n-pose-320x256.onnx
DEVICE_ROLE=room_camera
SENSE_ALERT_ENDPOINT_URL=http://localhost:8000
FACE_RECOGNITION_ENABLED=true
SUPABASE_URL=
SUPABASE_KEY=
QUEUE_DB_PATH=data/queue.sqlite3
VISITOR_DB_PATH=data/visitors.sqlite3
```

- [ ] **Step 3: Create `.gitignore`**

```
__pycache__/
*.pyc
.venv/
venv/
meridian-venv/
*.sqlite3
*.onnx
*.pt
.env
data/
reports/
*.egg-info/
```

- [ ] **Step 4: Create empty package/test markers**

`meridian_sense/__init__.py`:
```python
```

`tests/__init__.py`:
```python
```

`tests/fixtures/.gitkeep`:
```
```

- [ ] **Step 5: Install the project in editable mode with dev deps and verify**

Run: `cd C:\Users\emmad\Documents\meridian && python3 -m pip install -e ".[dev]"`
Expected: installs cleanly, ends with `Successfully installed meridian-sense-0.1.0 ...`

Run: `python3 -c "import meridian_sense; print('package importable')"`
Expected: `package importable`

- [ ] **Step 6: Commit**

```bash
git add pyproject.toml .env.example .gitignore meridian_sense/__init__.py tests/__init__.py tests/fixtures/.gitkeep
git commit -m "Scaffold meridian_sense package"
```

---

## Task 1: Config module

**Files:**
- Create: `meridian_sense/config.py`
- Test: `tests/test_config.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_config.py
import os
from meridian_sense.config import Settings


def test_defaults_match_measured_benchmark(monkeypatch):
    for key in ["CAPTURE_WIDTH", "CAPTURE_HEIGHT", "TARGET_FPS", "DEVICE_ROLE"]:
        monkeypatch.delenv(key, raising=False)
    settings = Settings(_env_file=None)
    assert settings.capture_width == 320
    assert settings.capture_height == 256
    assert settings.target_fps == 10
    assert settings.device_role == "room_camera"


def test_env_override(monkeypatch):
    monkeypatch.setenv("CAPTURE_WIDTH", "256")
    monkeypatch.setenv("CAPTURE_HEIGHT", "192")
    settings = Settings(_env_file=None)
    assert settings.capture_width == 256
    assert settings.capture_height == 192


def test_device_role_rejects_invalid(monkeypatch):
    monkeypatch.setenv("DEVICE_ROLE", "not_a_role")
    try:
        Settings(_env_file=None)
        assert False, "expected validation error"
    except ValueError:
        pass
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_config.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_sense.config'`

- [ ] **Step 3: Write minimal implementation**

```python
# meridian_sense/config.py
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    camera_source: str = "0"
    target_fps: int = 10
    capture_width: int = 320
    capture_height: int = 256
    pose_model_path: str = "models/yolo11n-pose-320x256.onnx"
    device_role: Literal["room_camera", "entry_camera", "combined"] = "room_camera"
    sense_alert_endpoint_url: str = "http://localhost:8000"
    face_recognition_enabled: bool = True
    supabase_url: str | None = None
    supabase_key: str | None = None
    queue_db_path: str = "data/queue.sqlite3"
    visitor_db_path: str = "data/visitors.sqlite3"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_config.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_sense/config.py tests/test_config.py
git commit -m "Add Settings config with measured-benchmark defaults"
```

---

## Task 2: Pose types

**Files:**
- Create: `meridian_sense/pose/__init__.py`
- Create: `meridian_sense/pose/types.py`
- Test: `tests/test_pose_types.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_pose_types.py
from meridian_sense.pose.types import Keypoint, PoseFrame, KEYPOINT_NAMES


def test_pose_frame_keypoint_lookup():
    kpts = [Keypoint(x=float(i), y=float(i) * 2, confidence=0.9) for i in range(17)]
    frame = PoseFrame(keypoints=kpts, timestamp=1.0)
    left_hip = frame.get("left_hip")
    assert left_hip.x == float(KEYPOINT_NAMES.index("left_hip"))


def test_pose_frame_hip_center():
    kpts = [Keypoint(x=0.0, y=0.0, confidence=0.9) for _ in range(17)]
    left_i = KEYPOINT_NAMES.index("left_hip")
    right_i = KEYPOINT_NAMES.index("right_hip")
    kpts[left_i] = Keypoint(x=10.0, y=20.0, confidence=0.9)
    kpts[right_i] = Keypoint(x=30.0, y=40.0, confidence=0.9)
    frame = PoseFrame(keypoints=kpts, timestamp=1.0)
    cx, cy = frame.hip_center()
    assert cx == 20.0
    assert cy == 30.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_pose_types.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_sense.pose'`

- [ ] **Step 3: Write minimal implementation**

`meridian_sense/pose/__init__.py`:
```python
```

`meridian_sense/pose/types.py`:
```python
from dataclasses import dataclass

# COCO-17 keypoint order, matching YOLO11n-pose's output layout.
KEYPOINT_NAMES = [
    "nose", "left_eye", "right_eye", "left_ear", "right_ear",
    "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
    "left_wrist", "right_wrist", "left_hip", "right_hip",
    "left_knee", "right_knee", "left_ankle", "right_ankle",
]


@dataclass(frozen=True)
class Keypoint:
    x: float
    y: float
    confidence: float


@dataclass(frozen=True)
class PoseFrame:
    keypoints: list[Keypoint]
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

    def body_height_estimate(self) -> float:
        """Vertical distance from shoulder-center to hip-center, used to
        normalize velocity/displacement features so they don't depend on
        how far the resident is from the camera."""
        sx, sy = self.shoulder_center()
        hx, hy = self.hip_center()
        return abs(hy - sy)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_pose_types.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_sense/pose/__init__.py meridian_sense/pose/types.py tests/test_pose_types.py
git commit -m "Add PoseFrame/Keypoint types with COCO-17 layout"
```

---

## Task 3: Pose feature extraction

**Files:**
- Create: `meridian_sense/pose/features.py`
- Test: `tests/test_pose_features.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_pose_features.py
from meridian_sense.pose.types import Keypoint, PoseFrame, KEYPOINT_NAMES
from meridian_sense.pose.features import FeatureWindow


def _frame(t, hip_y, shoulder_y, hip_x=50.0, shoulder_x=50.0, body_width=20.0):
    kpts = [Keypoint(x=0.0, y=0.0, confidence=0.9) for _ in range(17)]
    for name, x, y in [
        ("left_hip", hip_x - 5, hip_y), ("right_hip", hip_x + 5, hip_y),
        ("left_shoulder", shoulder_x - 5, shoulder_y), ("right_shoulder", shoulder_x + 5, shoulder_y),
        ("left_ankle", hip_x - body_width / 2, hip_y + 50), ("right_ankle", hip_x + body_width / 2, hip_y + 50),
    ]:
        kpts[KEYPOINT_NAMES.index(name)] = Keypoint(x=x, y=y, confidence=0.9)
    return PoseFrame(keypoints=kpts, timestamp=t)


def test_standing_still_has_low_velocity_and_upright_angle():
    window = FeatureWindow(window_seconds=3.0)
    for i in range(10):
        window.add(_frame(t=i * 0.1, hip_y=100.0, shoulder_y=40.0))
    features = window.compute()
    assert abs(features.hip_vertical_velocity) < 1.0
    assert features.torso_angle_degrees < 20.0  # near-vertical torso


def test_rapid_drop_produces_high_velocity_and_horizontal_angle():
    window = FeatureWindow(window_seconds=3.0)
    window.add(_frame(t=0.0, hip_y=50.0, shoulder_y=10.0))
    window.add(_frame(t=0.3, hip_y=180.0, shoulder_y=175.0, shoulder_x=90.0))
    features = window.compute()
    assert features.hip_vertical_velocity > 100.0
    assert features.torso_angle_degrees > 45.0


def test_stillness_duration_tracks_low_motion_streak():
    window = FeatureWindow(window_seconds=3.0)
    window.add(_frame(t=0.0, hip_y=180.0, shoulder_y=175.0))
    window.add(_frame(t=1.0, hip_y=180.5, shoulder_y=175.2))
    window.add(_frame(t=2.0, hip_y=180.3, shoulder_y=175.1))
    features = window.compute()
    assert features.stillness_duration_seconds >= 2.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_pose_features.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_sense.pose.features'`

- [ ] **Step 3: Write minimal implementation**

```python
# meridian_sense/pose/features.py
from collections import deque
from dataclasses import dataclass

from meridian_sense.pose.types import PoseFrame

STILLNESS_EPSILON_PX = 3.0


@dataclass(frozen=True)
class KinematicFeatures:
    hip_vertical_velocity: float  # px/sec, positive = moving down
    torso_angle_degrees: float  # 0 = perfectly vertical/upright, 90 = horizontal
    aspect_ratio: float  # body bounding-box width / height
    stillness_duration_seconds: float


class FeatureWindow:
    """Sliding window of PoseFrames used to derive fall-detection kinematics.

    All thresholds elsewhere are expressed in wall-clock seconds against
    frame.timestamp, not frame counts, so this stays correct at any FPS.
    """

    def __init__(self, window_seconds: float = 3.0):
        self.window_seconds = window_seconds
        self._frames: deque[PoseFrame] = deque()

    def add(self, frame: PoseFrame) -> None:
        self._frames.append(frame)
        cutoff = frame.timestamp - self.window_seconds
        while self._frames and self._frames[0].timestamp < cutoff:
            self._frames.popleft()

    def compute(self) -> KinematicFeatures:
        if len(self._frames) < 2:
            return KinematicFeatures(0.0, 0.0, 1.0, 0.0)

        frames = list(self._frames)
        first, last = frames[0], frames[-1]
        dt = last.timestamp - first.timestamp
        _, first_hy = first.hip_center()
        _, last_hy = last.hip_center()
        velocity = (last_hy - first_hy) / dt if dt > 0 else 0.0

        sx, sy = last.shoulder_center()
        hx, hy = last.hip_center()
        import math
        angle = math.degrees(math.atan2(abs(hx - sx), abs(hy - sy) + 1e-6))

        left_ankle = last.get("left_ankle")
        right_ankle = last.get("right_ankle")
        body_width = abs(right_ankle.x - left_ankle.x) + 20.0
        body_height = max(abs(last.get("left_ankle").y - sy), 1.0)
        aspect_ratio = body_width / body_height

        stillness = 0.0
        for i in range(len(frames) - 1, 0, -1):
            _, hy_curr = frames[i].hip_center()
            _, hy_prev = frames[i - 1].hip_center()
            if abs(hy_curr - hy_prev) <= STILLNESS_EPSILON_PX:
                stillness = frames[-1].timestamp - frames[i - 1].timestamp
            else:
                break

        return KinematicFeatures(velocity, angle, aspect_ratio, stillness)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_pose_features.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add meridian_sense/pose/features.py tests/test_pose_features.py
git commit -m "Add sliding-window kinematic feature extraction"
```

---

## Task 4: Fall detection state machine

**Files:**
- Create: `meridian_sense/fall_detection/__init__.py`
- Create: `meridian_sense/fall_detection/thresholds.py`
- Create: `meridian_sense/fall_detection/types.py`
- Create: `meridian_sense/fall_detection/state_machine.py`
- Test: `tests/test_fall_state_machine.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_fall_state_machine.py
from meridian_sense.pose.features import KinematicFeatures
from meridian_sense.fall_detection.state_machine import FallStateMachine
from meridian_sense.fall_detection.types import FallState


def _features(velocity=0.0, angle=5.0, aspect_ratio=0.4, stillness=0.0):
    return KinematicFeatures(velocity, angle, aspect_ratio, stillness)


def test_stays_normal_when_standing_still():
    machine = FallStateMachine()
    for t in [0.0, 0.5, 1.0]:
        event = machine.update(_features(velocity=0.0, angle=5.0), timestamp=t)
    assert machine.state == FallState.NORMAL
    assert event is None


def test_confirms_fall_on_drop_plus_sustained_stillness_horizontal():
    machine = FallStateMachine()
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=0.0)
    machine.update(_features(velocity=250.0, angle=70.0, aspect_ratio=1.8, stillness=0.0), timestamp=0.5)
    event = machine.update(_features(velocity=0.0, angle=75.0, aspect_ratio=1.8, stillness=2.1), timestamp=2.6)
    assert machine.state == FallState.CONFIRMED
    assert event is not None
    assert event.state == FallState.CONFIRMED


def test_suspected_when_signals_borderline():
    machine = FallStateMachine()
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=0.0)
    machine.update(_features(velocity=140.0, angle=40.0, aspect_ratio=0.9, stillness=0.0), timestamp=0.5)
    event = machine.update(_features(velocity=5.0, angle=42.0, aspect_ratio=0.9, stillness=0.6), timestamp=1.5)
    assert machine.state == FallState.SUSPECTED
    assert event is not None
    assert event.state == FallState.SUSPECTED


def test_clears_when_recovers_to_normal_without_crossing_ambiguous_band():
    machine = FallStateMachine()
    machine.update(_features(velocity=0.0, angle=5.0, aspect_ratio=0.4), timestamp=0.0)
    machine.update(_features(velocity=130.0, angle=32.0, aspect_ratio=0.6, stillness=0.0), timestamp=0.3)
    event = machine.update(_features(velocity=0.0, angle=8.0, aspect_ratio=0.4, stillness=0.0), timestamp=0.6)
    assert machine.state == FallState.NORMAL
    assert event is None or event.state == FallState.CLEARED


def test_confirmed_path_never_requires_any_io():
    import inspect
    source = inspect.getsource(FallStateMachine.update)
    assert "requests" not in source
    assert "socket" not in source
    assert "sqlite3" not in source
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_fall_state_machine.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'meridian_sense.fall_detection'`

- [ ] **Step 3: Write minimal implementation**

`meridian_sense/fall_detection/__init__.py`:
```python
```

`meridian_sense/fall_detection/thresholds.py`:
```python
# Tunable against real recorded test clips (tools/record_test_clip.py +
# tools/eval_harness.py) without touching state_machine.py logic.

VELOCITY_CANDIDATE_THRESHOLD = 120.0  # px/sec downward, triggers FALL_CANDIDATE
ANGLE_CANDIDATE_THRESHOLD_DEGREES = 30.0  # torso tilt away from vertical

VELOCITY_CONFIRM_THRESHOLD = 200.0
ANGLE_CONFIRM_THRESHOLD_DEGREES = 55.0
ASPECT_RATIO_HORIZONTAL_THRESHOLD = 1.2  # wider than tall => lying down
STILLNESS_CONFIRM_SECONDS = 2.0

CANDIDATE_WINDOW_SECONDS = 3.0  # how long a FALL_CANDIDATE can stay unresolved

