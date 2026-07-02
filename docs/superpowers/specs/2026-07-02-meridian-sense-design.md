# Meridian Sense — Edge Software Design

Status: Approved (rev. 2026-07-02c — real Pi 4 hardware in hand, MediaPipe replaced with ONNX Runtime, fully local, no cloud AI) | Date: 2026-07-02 | Owner: Pranav Emmadi

**Revision note (b):** the original draft assumed Pi 5/Jetson-class hardware and a Gemini cloud validation layer with a local mock standing in until real API keys arrived. That's changed: **the target device is a Raspberry Pi 4B (no accelerator), and there are no AI API keys available at all — the system must run fully local**, not "local until keys show up." The `FallValidator` interface is still designed to accept a cloud validator later if the team decides to add one, but no cloud validator is implemented or planned in this build.

**Revision note (c):** a real Pi 4B is now connected (via USB RNDIS gadget networking) and reachable over SSH, so hardware assumptions below are measured, not guessed. Confirmed specs: Raspberry Pi 4 Model B Rev 1.4, quad-core Cortex-A72 up to 1.8GHz, 8GB RAM, Debian 13 (trixie) aarch64, Python 3.13.5, an imx219 camera module already attached (native 3280×2464, up to 200fps at 640×480 via the sensor's binned modes), a GPIO-based PWM fan (controllable, defaults to automatic temperature-tiered control). Empirical package testing on this exact device turned up a real constraint: **MediaPipe has no published wheel for Python 3.13 on linux/aarch64** — it is not installable here without downgrading the system Python, which we're not doing. Section 4.2/4.6 below now specify **ONNX Runtime** (confirmed installable) as the inference backend instead, running a YOLO11n-pose model exported at build time — this was a plan-invalidating finding, not a preference change, so it's called out explicitly rather than silently substituted.

## 1. Purpose

Meridian Sense is the room-level edge unit from the [Meridian PRD](../../../PRD.md) section 7.1: camera + on-device pose estimation for fall detection, a second on-device validation pass for ambiguous events, facial recognition for visitor logging at entry points, and offline-first local queueing. This document is the internal build spec for the software side of Sense, developed against a real Raspberry Pi 4B (SSH-reachable, camera attached) reserved for this project, and structured to run identically on additional Pi 4B units the team deploys per room/entrance. Everything — pose estimation, fall validation, and face recognition — runs on-device with no cloud AI dependency; there are no AI API keys for this build, and the architecture treats "fully local" as the permanent default, not a temporary stand-in.

Scope boundary: this covers Sense only (the edge daemon). The caregiver/family apps, Insights dashboard, and real backend are Dhairya's build — Sense talks to them only through the documented alert/visitor-log payload contract (see the companion integration PRD, `docs/meridian-sense-integration-prd.md`).

## 2. Priority

P0 (must work for the pitch, per PRD section 9): camera capture, pose estimation, fall detection state machine, skeleton-only privacy transmission, local secondary validation for ambiguous events, offline queue, alert dispatch, live skeleton-view demo mode.

P1 (build if time allows, per PRD section 9): facial recognition / visitor logging, v1 predictive fall-risk score.

Both are in scope for this build; P0 is sequenced first.

## 2.1 Pi 4B resource budget and device roles

The Pi 4B (quad-core Cortex-A72, 1.8GHz max per the actual unit's `vcgencmd`, no GPU/NPU acceleration) is materially weaker than the Pi 5/Jetson-class hardware the PRD originally floated, and it now has to do everything on-device. Several changes follow from that:

- **Lite models, lower FPS, lower resolution.** Pose estimation runs a nano-class model at a reduced target FPS and capture resolution (see 4.1/4.2) — tuned for "detect a fall within budget," not maximum visual fidelity.
- **One pipeline per unit in production.** A single Pi 4B is not expected to run pose-based fall detection *and* face recognition concurrently at production quality — that's too much concurrent CPU load on this hardware. Each Sense unit is configured with a `DEVICE_ROLE`: `room_camera` (pose + fall detection only — the P0 safety-critical path) or `entry_camera` (face recognition only — the P1 visitor-logging path). A `combined` role exists for dev/demo convenience on beefier hardware, but is explicitly not the recommended Pi 4B production configuration. This is a deployment reality, not a code limitation — a facility runs several Pi 4B units (one per room, a couple at entrances), matching how the PRD already describes room units vs. entry points.
- **Active cooling matters for sustained inference.** The dev unit has a GPIO PWM fan (`dtoverlay=pwm-gpio-fan`) under automatic temperature-tiered control by default (kernel `step_wise` governor, 4 tiers keyed to 30/45/55/65°C). Sustained CPU-bound inference is exactly the workload that trips thermal throttling on a Pi 4B; production units should ship with active cooling and the automatic tiering left on (it's the sane default — max-permanently is a benchmarking convenience, not a production setting, since it shortens fan life and adds noise for no benefit once thermal headroom is confirmed).
- **Defaults are measured, not assumed.** FPS/resolution/model-size defaults below (section 4.2.1) were benchmarked directly on this unit — the original 640×480 assumption turned out to be 3x too slow (2.89 FPS), which only surfaced by actually running inference on real hardware. Thresholds and config remain tunable without touching pipeline logic either way.

## 3. Architecture

Single Python daemon (`meridian_sense`) running a real-time pipeline:

```
Camera → Pose Estimation → Feature Extraction → Fall State Machine
                                                        │
                                        ┌───────────────┼────────────────┐
                                        │                │                │
                                   CONFIRMED         SUSPECTED         CLEARED
                                        │                │                │
                                        │      Local Secondary Validator  │
                                        │      (on-device, no network    │
                                        │       call — different/        │
                                        │       stricter feature pass)   │
                                        │       → confirmed/cleared      │
                                        └───────┬────────┘                │
                                                 ▼                        ▼
                                          Offline Queue (SQLite)      (no-op)
                                                 ▼
                                          Alert Dispatcher → mock/real cloud endpoint
```

A parallel path shares the same camera frames for entry-point deployments:

```
Camera → InsightFace Detection (SCRFD/RetinaFace, via ONNX Runtime) → Quality Gate (blur/size/frontal)
       → InsightFace Embedding (ArcFace) → Match vs VisitorStore → Visitor Log Queue → Dispatcher
```

Both paths funnel through the same offline queue and dispatcher so delivery guarantees are uniform.

**Privacy invariant:** raw frames are held in memory only for the duration of pose/face extraction on that frame, then discarded. Nothing downstream of extraction ever sees a raw frame. No frame is written to disk or transmitted, by default, under any code path.

## 4. Components

### 4.1 `capture/video_source.py`
`VideoSource` abstraction over `cv2.VideoCapture` (webcam index or video file path — dev/test) and `picamera2` (Pi 4B deployment, import-guarded, auto-selected when `picamera2` is importable and no explicit override is set). Yields `(frame, timestamp)` at a configured target FPS and resolution — **default 320×256 at 10 FPS**, chosen from the measured inference benchmark in 4.2.1, not a guess. The imx219 sensor supports far higher native frame rates at low resolutions (up to 200fps at 640×480 in its binned mode) — the camera was never the bottleneck; CPU-bound pose inference is, and 320×256 is the input size the model actually gets fed after capture (capture can pull a larger frame and resize down, or capture directly at target size — `video_source.py` does the latter to avoid wasted resize work on a CPU-constrained device). Both FPS and resolution are overridable via config.

### 4.2 `pose/estimator.py`
**Backend: ONNX Runtime running a YOLO11n-pose model, not MediaPipe.** MediaPipe was the original plan, but it has no published wheel for Python 3.13 on linux/aarch64 (confirmed by attempting the install on the actual dev unit — `pip download mediapipe` returns no matching distribution) — it is not viable on this OS/Python combination without downgrading the system Python, which we're avoiding. `onnxruntime`, `numpy`, and `opencv-python-headless` all have prebuilt aarch64/cp313 wheels and install cleanly.

The model (`yolo11n-pose`, Ultralytics' nano pose variant, 17 COCO keypoints) is exported to ONNX **once, at build time, on a dev machine** (`tools/export_pose_model.py`, using `ultralytics` + `torch` — a build-time-only dependency, never installed on the Pi) at a fixed input size matching the capture resolution. The Pi only ever runs `onnxruntime.InferenceSession` against the resulting `.onnx` file — no torch, no ultralytics package, at runtime. `pose/estimator.py` owns letterbox-resize preprocessing, the forward pass, and keypoint/confidence postprocessing (NMS over the single expected person, since Sense cares about one resident per room), producing the same `PoseFrame` shape (`(x, y, confidence)` per keypoint + timestamp, `None` if no person detected) so everything downstream in 4.3/4.4 is unaffected by the backend swap. All downstream feature/threshold math is expressed in wall-clock seconds, not frame counts, so it stays correct regardless of the FPS the hardware actually sustains.

**NCNN as a documented future option:** community benchmarks (Qengineering's Pi-4-specific repos) show NCNN outperforming ONNX Runtime on bare Pi 4 for comparable vision models, and `ncnn`'s Python wheel does install cleanly on this unit (Python 3.13/aarch64, confirmed). It's not the v1 backend because it requires hand-porting model weights and pre/post-processing rather than using a maintained model-export pipeline, which is a larger, riskier lift than the ONNX Runtime path above for a first working version. If ONNX Runtime's measured FPS (section 4.2.1) doesn't clear the detection-latency budget with margin, NCNN is the next lever to pull, behind the same `PoseEstimator` interface.

#### 4.2.1 Benchmark methodology and measured results (real dev unit, not estimated)
`tools/export_pose_model.py` exports `yolo11n-pose` to ONNX at a configured input size; `tools/benchmark_pose.py` loads it with `onnxruntime.InferenceSession` (`intra_op_num_threads=4`, all cores, CPU execution provider — this Pi has no usable GPU/NPU for onnxruntime) and times 50 forward passes on synthetic frames after 5 warm-up runs, reporting mean/p50/p95/max latency and derived FPS. This was run for real against the dev unit (fan pinned to max state throughout, confirmed zero thermal throttling via `vcgencmd get_throttled` reading `0x0` and CPU clock holding at 1800MHz — the numbers below reflect sustained compute capability, not a throttled or lucky-burst measurement):

| Input size | Mean latency | p95 latency | Max sustained FPS |
|---|---|---|---|
| 640×480 | 346.6ms | 379.8ms | 2.89 |
| 320×256 | 96.9ms | 116.1ms | 10.32 |
| 256×192 | 55.8ms | 59.0ms | 17.93 |

640×480 — the original assumption — is not viable; it lands at under 3 FPS, far short of the safety-critical detection budget. **320×256 is the shipped default**: it lands almost exactly on the original 10 FPS target with a real number behind it, and gives the fall state machine roughly one pose sample every ~100ms, comfortable temporal resolution for tracking a fall's kinematics (rapid drop + settling typically unfolds over 0.5-1.5s). 256×192 is documented as an available step-up in latency margin (nearly 18 FPS) if the team's own recorded test footage shows keypoint accuracy holding up fine at that scale for a room-scale camera view — smaller input trades keypoint precision for temporal density, and that tradeoff should be judged against real footage, not guessed. Given 320×256 alone already clears the target with real margin, NCNN (4.2's "documented future option") is deprioritized rather than pursued now — the ONNX Runtime path is sufficient without taking on that extra implementation risk.

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
`FallValidator` protocol with `validate(event: FallCandidateEvent) -> ValidationResult`. **No cloud validator exists in this build — there are no AI API keys, and the system is required to run fully local.** The interface is still an abstraction (so a cloud validator could be added later without touching the state machine), but today it has exactly one real implementation:
- `LocalHeuristicValidator`: a second, independent pass over the same event window, deliberately using different signal than the primary state machine so it catches different mistakes rather than rubber-stamping the same logic twice — it looks at trajectory smoothness (a real fall has a fast, roughly monotonic descent; sitting down has a slower, controlled one) and post-drop recovery motion (any coordinated movement within the stillness window pulls the classification toward `false_positive`) alongside stricter versions of the state machine's own thresholds. Returns `fall_confirmed | false_positive_sitting | false_positive_object_drop | inconclusive`, a confidence score, and a one-line rationale string (useful for the incident report and for pitch credibility — "here's why the system believed this was a fall").
- This runs synchronously, in-process, in well under a second — there's no network call to wait on, so the old "20s timeout then auto-escalate" design is gone; if `LocalHeuristicValidator` itself returns `inconclusive`, that **also** fails open to `CONFIRMED` (a missed validation should never suppress a real alert), it just does so almost immediately instead of after a network timeout. This is a stronger offline-first story than the original Gemini-with-timeout design: fall validation latency no longer depends on connectivity at all.

### 4.6 `face/`
- `detector.py`: no separate MediaPipe dependency (unavailable on this Python/OS combo — see the revision note). Instead, this is a thin quality-gating wrapper around InsightFace's own bundled detector (SCRFD/RetinaFace, part of the `buffalo_s` model pack, running via ONNX Runtime): it takes InsightFace's per-frame detections and scores each on blur (Laplacian variance over the cropped face region), face size (min pixel threshold), and frontal-ness (using the 5-point landmarks InsightFace already returns), passing through only the best detection within a short capture window — this is the "nice snapshot" behavior. One fewer model/dependency than the original two-stage MediaPipe-then-InsightFace design.
- `recognizer.py`: InsightFace (`buffalo_s`, ONNX Runtime CPU) computes a 512-d ArcFace embedding for the gated snapshot, matched by cosine similarity against enrolled embeddings. On Pi 4B this is noticeably slower than pose estimation (multi-second per embedding is expected on this CPU) — acceptable because visitor logging isn't latency-critical the way fall alerts are. To avoid contending with a room camera's pose pipeline, the face path only runs on `entry_camera`/`combined`-role devices (see 2.1), and is additionally gated behind a cheap frame-difference motion check so InsightFace only runs when something in frame actually changed, not on every frame.
- `visitor_store.py`: `VisitorStore` interface (`enroll`, `match`, `log_visit`) with a `SQLiteVisitorStore` implementation (mock, matches the PRD's "Supabase-backed" data shape) and a documented seam for a future `SupabaseVisitorStore`.

### 4.7 `offline_queue/`
SQLite-backed durable queue (`queue_store.py`) for outgoing payloads (alerts, visitor logs). Each item has a UUID idempotency key, retry count, and next-retry-at (exponential backoff, capped). `dispatcher.py` runs a background thread draining the queue against the configured endpoint; items are only removed on a 2xx response.

### 4.8 `alerting/`
`schemas.py` defines the `AlertPayload` and `VisitorLogPayload` contracts (see integration PRD for the full schema — this is the single source of truth Dhairya's backend implements against). `client.py` POSTs to `SENSE_ALERT_ENDPOINT_URL`.

A minimal `mock_cloud/app.py` (FastAPI) implements that same contract so the full loop is demoable today without waiting on the real backend — it accepts the payloads, prints/logs them, and returns 200s, so `offline_queue`/`dispatcher` have something real to talk to in dev and in the demo.

### 4.9 `risk_scoring/`
v1 heuristic: rolling weekly aggregation of gait speed (from hip-center displacement during walking bouts) and nighttime movement frequency per resident session, mapped to a 0-100 trend score. Explicitly labeled `v1-heuristic` in its output so it's never mistaken for a validated clinical signal.

### 4.10 `daemon.py`
Wires the above into one run loop, structured JSON logging throughout (`logging_setup.py`), graceful shutdown, and a `--skeleton-view` flag that starts a small local HTTP MJPEG stream (not a native `cv2.imshow` window) rendering only the skeleton overlay on a blank background — chosen because the production Pi 4B units run headless (no desktop environment; see 2.1), so any live-view mechanism has to work over the network by design, not just happen to. This also means the pitch demo can display the skeleton view on a laptop/projector browser pointed at the Pi's IP, rather than needing a monitor physically attached to the unit. Shared code with `tools/live_demo.py`.

## 5. Tools

- `tools/export_pose_model.py` — exports `yolo11n-pose` to ONNX at a given input size (build-time only; depends on `ultralytics`/`torch`, which are never installed on the Pi — see 4.2). Run once per resolution choice, not part of the runtime.
- `tools/benchmark_pose.py` — loads an exported `.onnx` pose model with `onnxruntime.InferenceSession` and measures mean/p50/p95/max inference latency over N runs after warm-up, on whatever device it's run on. This is what produced the measured numbers in 4.2.1 — it's meant to be re-run whenever the model, input size, or hardware changes, not treated as a one-time result.
- `tools/live_demo.py` — runs the pipeline live against the camera with the skeleton-only MJPEG stream (see 4.10). This is the live "privacy moment" for the pitch.
- `tools/record_test_clip.py` — records a labeled webcam clip (`--label fall|sit|object_drop|normal`) into `tests/fixtures/clips/` with a metadata sidecar, for building the 100+ staged-event test set the PRD's success metrics call for.
- `tools/eval_harness.py` — runs the full pipeline over the labeled clip set, computes precision/recall/F1 on fall classification and end-to-end latency (capture → alert-fired), and writes a report (`reports/eval_<timestamp>.json` + a printed summary table). This will not fabricate a number — it only reports on whatever clips exist in `tests/fixtures/clips/`, and the report explicitly states the sample size and methodology so any number it produces is honest and citable in the pitch.

## 6. Testing

Unit tests (no camera required):
- `test_pose_features.py` — feature math against synthetic pose sequences
- `test_fall_state_machine.py` — synthetic sequences for fall / sit-down / object-drop / normal, asserting correct state transitions and that CONFIRMED never requires any I/O
- `test_offline_queue.py` — retry/backoff, idempotency, ordering under simulated endpoint failures
- `test_local_validator.py` — `LocalHeuristicValidator` classification correctness on synthetic windows (fall / sitting / object-drop / genuinely inconclusive), and the fail-open-to-CONFIRMED behavior on `inconclusive`
- `test_face_quality_gate.py` — blur/size/frontal scoring against synthetic/sample images

## 7. Config

`.env`-driven (`config.py`, pydantic-settings): `CAMERA_SOURCE`, `TARGET_FPS` (default 10), `CAPTURE_WIDTH`/`CAPTURE_HEIGHT` (default 320×256, per the measured benchmark in 4.2.1), `POSE_MODEL_PATH` (path to the exported `.onnx` file), `DEVICE_ROLE` (`room_camera` | `entry_camera` | `combined`, see 2.1), `SENSE_ALERT_ENDPOINT_URL` (defaults to the local mock cloud server), fall-detection thresholds override path, `FACE_RECOGNITION_ENABLED` (bool, defaults true but easy to disable per-camera for non-entry-point rooms), `SUPABASE_URL`/`SUPABASE_KEY` (optional; absent → SQLite mock). There is no `GEMINI_API_KEY` or equivalent cloud-AI setting in this build — validation is local-only by design, not by fallback.

## 8. Non-goals (carried from PRD section 9, plus this revision's constraint)

No raw video storage or transmission by default. No medical claims/diagnosis logic. No custom hardware bring-up beyond off-the-shelf Pi + camera. No Android/other-platform concerns (out of scope for Sense entirely). **No dependency on any cloud AI API for the core detection/validation path — the system must function fully offline/local, since no AI API keys exist for this build.**

## 9. Open items deferred, not blocking this build

- Real Supabase credentials for `SupabaseVisitorStore` (mocked with SQLite; swapping in real credentials is a `.env` change only, no code change)
- Real staged-fall footage for the 100+ event test set and a genuine precision number (harness is ready; footage capture is a team task, `record_test_clip.py` supports it)
- Whether the team ever wants a cloud validator (e.g. Gemini) as an *additional* opinion later — the `FallValidator` interface supports adding one, but none is built or planned now
- Validating keypoint accuracy at 320×256 (or the leaner 256×192 option) against real recorded footage of a person at typical room-camera distance — the FPS numbers in 4.2.1 are measured, but detection *accuracy* at reduced input size still needs real footage to confirm, not just inference speed
- Face recognition benchmark on the real unit — 4.2.1 only covers the pose path; InsightFace's own latency on this Pi 4B hasn't been measured yet the same rigorous way
