# Meridian Sense — Edge Software Design

Status: Approved | Date: 2026-07-02 | Owner: Pranav Emmadi

## 1. Purpose

Meridian Sense is the room-level edge unit from the [Meridian PRD](../../../PRD.md) section 7.1: camera + on-device pose estimation for fall detection, a Gemini-powered cloud validation layer for ambiguous events, facial recognition for visitor logging at entry points, and offline-first local queueing. This document is the internal build spec for the software side of Sense, developed and tested on a dev machine (no physical Pi/camera attached to this session) and structured to deploy unmodified to a Raspberry Pi 5 + camera later.

Scope boundary: this covers Sense only (the edge daemon). The caregiver/family apps, Insights dashboard, and real backend are Dhairya's build — Sense talks to them only through the documented alert/visitor-log payload contract (see the companion integration PRD, `docs/meridian-sense-integration-prd.md`).

## 2. Priority

P0 (must work for the pitch, per PRD section 9): camera capture, pose estimation, fall detection state machine, skeleton-only privacy transmission, Gemini validation for ambiguous events, offline queue, alert dispatch, live skeleton-view demo mode.

P1 (build if time allows, per PRD section 9): facial recognition / visitor logging, v1 predictive fall-risk score.

Both are in scope for this build; P0 is sequenced first.

## 3. Architecture

Single Python daemon (`meridian_sense`) running a real-time pipeline:

```
Camera → Pose Estimation → Feature Extraction → Fall State Machine
                                                        │
                                        ┌───────────────┼────────────────┐
                                        │                │                │
                                   CONFIRMED         SUSPECTED         CLEARED
                                        │                │                │
                                        │         Gemini Validator        │
                                        │        (pose-JSON in, not      │
                                        │         video) → confirmed/     │
                                        │         cleared                 │
                                        └───────┬────────┘                │
                                                 ▼                        ▼
                                          Offline Queue (SQLite)      (no-op)
                                                 ▼
                                          Alert Dispatcher → mock/real cloud endpoint
```

A parallel path shares the same camera frames for entry-point deployments:

```
Camera → Face Detection (MediaPipe) → Quality Gate (blur/size/frontal)
       → InsightFace Embedding → Match vs VisitorStore → Visitor Log Queue → Dispatcher
```

Both paths funnel through the same offline queue and dispatcher so delivery guarantees are uniform.

**Privacy invariant:** raw frames are held in memory only for the duration of pose/face extraction on that frame, then discarded. Nothing downstream of extraction ever sees a raw frame. No frame is written to disk or transmitted, by default, under any code path.

## 4. Components

### 4.1 `capture/video_source.py`
`VideoSource` abstraction over `cv2.VideoCapture` (webcam index or video file path — dev/test) and `picamera2` (Pi deployment, import-guarded, auto-selected when `picamera2` is importable and no explicit override is set). Yields `(frame, timestamp)` at a configured target FPS (default 15 — sufficient for pose kinematics, keeps CPU headroom on Pi).

### 4.2 `pose/estimator.py`
Wraps MediaPipe Pose (BlazePose, `model_complexity=1`). Input: a frame. Output: `PoseFrame` — 33 landmarks (x, y, z, visibility) + timestamp, or `None` if no person detected.

### 4.3 `pose/features.py`
Maintains a sliding window (default 3s at target FPS) of `PoseFrame`s and derives kinematic features per tick:
- Hip-center vertical position and velocity (normalized by detected body height, so it's resolution/distance independent)
- Torso-tilt angle (shoulder-center-to-hip-center vector vs. vertical)
- Bounding-box aspect ratio (width/height of the pose envelope — a lying person is wide, a standing person is tall)
- Stillness duration (frames where hip-center displacement stays below a small epsilon)

### 4.4 `fall_detection/state_machine.py`
States: `NORMAL → FALL_CANDIDATE → {CONFIRMED, SUSPECTED, CLEARED} → NORMAL`.

- `NORMAL → FALL_CANDIDATE`: vertical velocity spike exceeds threshold AND torso angle crosses from upright toward horizontal within one window.
- `FALL_CANDIDATE → CONFIRMED`: aspect ratio stays "horizontal" AND stillness duration exceeds a threshold (default 2s) — high-confidence, fires immediately, no cloud round-trip. This path alone must satisfy the <5s detection / <15s alert bar.
- `FALL_CANDIDATE → SUSPECTED`: drop detected but signals are borderline (e.g., partial recovery, ambiguous angle, brief stillness) — routed to validation instead of auto-clearing, since a missed fall is worse than an extra validation call.
- `FALL_CANDIDATE → CLEARED`: signals resolve back to normal within the window (e.g., sat down and stood back up) without ever crossing the ambiguous thresholds.

All thresholds are named constants in one place (`fall_detection/thresholds.py`) so they're tunable against real recorded test clips without touching logic.

### 4.5 `validation/`
`FallValidator` protocol with `validate(event: FallCandidateEvent) -> ValidationResult`.
- `GeminiValidator`: builds a structured JSON description of the event window (feature time-series, not pixels) and prompts Gemini to classify `fall_confirmed | false_positive_sitting | false_positive_object_drop | inconclusive`, with confidence and a one-line rationale (captured for the incident report / demo credibility). Selected automatically when `GEMINI_API_KEY` is set.
- `MockValidator`: same interface, rule-based on the same features (slightly stricter thresholds than the state machine's own ambiguous band), used when no API key is configured — this is the default for this build per your answer.
- If Gemini is configured but unreachable (offline), `SUSPECTED` events are queued and re-validated once connectivity returns, per the offline-first requirement; a suspected event that can't be validated within a timeout (default 20s) auto-escalates to `CONFIRMED` — a missed validation should never suppress a real alert.

### 4.6 `face/`
- `detector.py`: MediaPipe Face Detection finds candidate faces per frame; a quality gate scores each detection on blur (Laplacian variance), face size (min pixel threshold), and frontal-ness (eye/nose landmark symmetry), and only the best frame within a short capture window is passed on — this is the "nice snapshot" behavior.
- `recognizer.py`: InsightFace (`buffalo_s`, ONNX Runtime CPU) computes a 512-d embedding for the gated snapshot, matched by cosine similarity against enrolled embeddings.
- `visitor_store.py`: `VisitorStore` interface (`enroll`, `match`, `log_visit`) with a `SQLiteVisitorStore` implementation (mock, matches the PRD's "Supabase-backed" data shape) and a documented seam for a future `SupabaseVisitorStore`.

### 4.7 `offline_queue/`
SQLite-backed durable queue (`queue_store.py`) for outgoing payloads (alerts, visitor logs). Each item has a UUID idempotency key, retry count, and next-retry-at (exponential backoff, capped). `dispatcher.py` runs a background thread draining the queue against the configured endpoint; items are only removed on a 2xx response.

### 4.8 `alerting/`
`schemas.py` defines the `AlertPayload` and `VisitorLogPayload` contracts (see integration PRD for the full schema — this is the single source of truth Dhairya's backend implements against). `client.py` POSTs to `SENSE_ALERT_ENDPOINT_URL`.

A minimal `mock_cloud/app.py` (FastAPI) implements that same contract so the full loop is demoable today without waiting on the real backend — it accepts the payloads, prints/logs them, and returns 200s, so `offline_queue`/`dispatcher` have something real to talk to in dev and in the demo.

### 4.9 `risk_scoring/`
v1 heuristic: rolling weekly aggregation of gait speed (from hip-center displacement during walking bouts) and nighttime movement frequency per resident session, mapped to a 0-100 trend score. Explicitly labeled `v1-heuristic` in its output so it's never mistaken for a validated clinical signal.

### 4.10 `daemon.py`
Wires the above into one run loop, structured JSON logging throughout (`logging_setup.py`), graceful shutdown, and a `--skeleton-view` flag that opens a debug window rendering only the skeleton overlay on a blank background (shared code with `tools/live_demo.py`).

## 5. Tools

- `tools/live_demo.py` — runs the pipeline live against the webcam with the skeleton-only overlay window. This is the live "privacy moment" for the pitch.
- `tools/record_test_clip.py` — records a labeled webcam clip (`--label fall|sit|object_drop|normal`) into `tests/fixtures/clips/` with a metadata sidecar, for building the 100+ staged-event test set the PRD's success metrics call for.
- `tools/eval_harness.py` — runs the full pipeline over the labeled clip set, computes precision/recall/F1 on fall classification and end-to-end latency (capture → alert-fired), and writes a report (`reports/eval_<timestamp>.json` + a printed summary table). This will not fabricate a number — it only reports on whatever clips exist in `tests/fixtures/clips/`, and the report explicitly states the sample size and methodology so any number it produces is honest and citable in the pitch.

## 6. Testing

Unit tests (no camera required):
- `test_pose_features.py` — feature math against synthetic pose sequences
- `test_fall_state_machine.py` — synthetic sequences for fall / sit-down / object-drop / normal, asserting correct state transitions and that CONFIRMED never requires a network call
- `test_offline_queue.py` — retry/backoff, idempotency, ordering under simulated endpoint failures
- `test_gemini_validation_mock.py` — MockValidator classification correctness, and the fallback-to-CONFIRMED-on-timeout behavior
- `test_face_quality_gate.py` — blur/size/frontal scoring against synthetic/sample images

## 7. Config

`.env`-driven (`config.py`, pydantic-settings): `CAMERA_SOURCE`, `TARGET_FPS`, `GEMINI_API_KEY` (optional), `SENSE_ALERT_ENDPOINT_URL` (defaults to the local mock cloud server), fall-detection thresholds override path, `FACE_RECOGNITION_ENABLED` (bool, defaults true but easy to disable per-camera for non-entry-point rooms), `SUPABASE_URL`/`SUPABASE_KEY` (optional; absent → SQLite mock).

## 8. Non-goals (carried from PRD section 9)

No raw video storage or transmission by default. No medical claims/diagnosis logic. No custom hardware bring-up beyond off-the-shelf Pi + camera + accelerator. No Android/other-platform concerns (out of scope for Sense entirely).

## 9. Open items deferred, not blocking this build

- Real Gemini/Supabase credentials (mocked per your instruction; swapping in real keys is a `.env` change only, no code change)
- Real staged-fall footage for the 100+ event test set and a genuine precision number (harness is ready; footage capture is a team task, `record_test_clip.py` supports it)
- Final hardware pick (Pi 5 + accelerator vs. Jetson) — the `video_source.py`/`picamera2` seam is written to not care which
