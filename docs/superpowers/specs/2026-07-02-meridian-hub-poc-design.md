# Meridian Hub — Local Proof-of-Concept Design

Status: Approved | Date: 2026-07-02 | Owner: Pranav Emmadi | Supersedes: Sense-on-Pi design (2026-07-02-meridian-sense-design.md) for the AI/inference architecture

## 1. Purpose and revision context

PRD v2.1 (`PRD.md`, replacing v1.0) changes the architecture from per-room on-device inference to a centralized **Meridian Hub**: room cameras capture and stream only (no AI), and one shared Hub per facility does all AI inference — person detection, tracking, pose estimation, fall/long-lie classification, dementia-safety rules, risk trends, visitor logging, device health.

This session already benchmarked the Raspberry Pi 4B extensively as a Hub candidate (`benchmarks/pi4b_hub_capacity_2026-07-02.md`): it has a hard ~10.7 FPS aggregate throughput ceiling, enough for 2-3 rooms at most, far short of the PRD's 8-12 camera target. This document scopes a **local proof-of-concept of the Hub running on the Windows dev machine instead** (Intel Core Ultra 9 275HX, 24 cores; NVIDIA RTX 5060 Laptop GPU) — hardware that can plausibly approach the PRD's real target, unlike the Pi.

**Scope boundary, confirmed by the user:** this build covers Pranav's ownership only (PRD section 23): cameras, wireless streaming, Hub hardware/software, the AI pipeline, event generation, device health. It explicitly excludes auth, RBAC enforcement, the multi-tenant database, and the resident/caregiver/family/admin apps and dashboards — those are Dhairya's. This POC proves the Hub produces correctly-formed events against the real contract (PRD section 17 event schema, section 19 API shapes); it does not build the systems that consume them.

**Confirmed prototype camera hardware:** the user is purchasing 2x HiLetgo ESP32-CAM boards (ESP32-S, OV2640 2MP sensor, 2.4GHz WiFi, MJPEG-capable, TF card slot, CH340C USB-serial for flashing) — matching PRD section 14.1 exactly. Not in hand yet this session, but the stream-ingestion interface below is designed around this hardware's real characteristics (WiFi MJPEG stream, no onboard AI, no hardware H.264) rather than a generic placeholder, so swapping in real units later is a config change, not a rewrite. Until then, camera input is the dev machine's webcam (live) plus looped video files (simulating additional rooms).

## 2. Priority

Everything in this doc is being built now — the point of "implement ALL features" is a comprehensive POC, not a P0-only slice. Within that, the fall/long-lie/validation/event-engine/offline-queue path is the safety-critical core and gets built and tested first; dementia-safety, risk trends, night-rounds, visitor logging, and medication-visit verification follow, since they share the same tracked-person/feature-window foundation.

## 3. Architecture

```
Camera(s): webcam (live) + looped video files (simulated extra rooms)
        │
        ▼
Stream Ingestion  (per-camera FPS, frozen-frame detection, timestamping)
        │
        ▼
Inference Scheduler  (round-robin across active cameras; priority boost for
                       cameras with an open incident; drops frames under
                       load rather than falling behind — same lesson as
                       benchmarks/hub_simulator.py)
        │
        ▼
Person Detector + Pose Estimator  (YOLO11s-pose, ONNX Runtime + DirectML,
                                    multi-person per frame)
        │
        ▼
Tracker  (IoU-based, stable track_id per person within a camera, tolerates
          brief occlusion)
        │
        ├──► per-track Feature Window (kinematics) ──► Fall / Long-Lie /
        │      Inactivity Classifier ──► Local Validation ──► Event Engine
        │
        ├──► Dementia-safety Zone Rules (pacing, door approach/crossing,
        │      unaccompanied exit — checks co-presence of a second track)
        │
        ├──► Mobility/Risk Trend Scorer (weekly heuristic)
        │
        ├──► Night-Rounds Status Classifier (in_bed / moving_normally /
        │      out_of_bed / not_visible / possible_distress)
        │
        └──► Medication-Visit Verification (dwell time in a configured
               zone near a med-cart marker)

Event Engine ──► Offline Queue (SQLite) ──► local mock backend
                                              (implements PRD §19 endpoints)

Parallel path: entry-camera frames ──► Face Detection+Recognition
               (InsightFace) ──► visitor_log event ──► same Offline Queue

Device Health Service aggregates per-camera FPS/dropped-frames/latency and
Hub-level CPU/GPU/RAM/queue-depth, feeding PRD §19.2/§19.3 health payloads.
```

**Privacy invariant carried over from the Sense design:** raw frames are held only long enough to run detection/pose/face extraction, then discarded. No raw video is written to disk or transmitted by default. Skeleton-only views are the default visualization.

## 4. Components

### 4.1 `hub/capture/`
- `camera_source.py`: unified interface over `cv2.VideoCapture` for both the live webcam and looped video files. Designed against the real HiLetgo ESP32-CAM's characteristics (MJPEG-over-WiFi stream, no hardware H.264, no onboard AI) so a `MjpegHttpCameraSource` implementing the same interface is a config change once real units arrive, not a redesign.
- `camera_registry.py`: matches PRD §15.1 — `camera_id → facility/building/floor/room/resident_id`, `stream_url`, `firmware_version`, `device_status`, `privacy_state`. SQLite-backed for the POC.

### 4.2 `hub/ingestion/`
Per-camera FPS measurement, frozen-frame detection (same frame hash repeated beyond a threshold), timestamping. Matches PRD §15.2.

### 4.3 `hub/scheduler/`
Round-robins active camera queues into the shared inference engine; boosts priority for any camera with an open (unresolved) incident; drops frames rather than building unbounded backlog when oversubscribed. Directly informed by `benchmarks/hub_simulator.py`'s finding that aggregate throughput is a fixed ceiling regardless of camera count — this component is what turns that fixed budget into a sane per-camera allocation instead of unbounded queueing. Matches PRD §15.3.

### 4.4 `hub/vision/`
- `pose_estimator.py`: YOLO11s-pose via ONNX Runtime with the DirectML execution provider (falls back to CPU if DirectML init fails, logged loudly — never silently degrades without a visible signal). Multi-person: returns every detection above a confidence threshold, not just the top-1.
- `tracker.py`: IoU-based tracker assigning a stable `track_id` per person per camera, matching detections frame-to-frame by bounding-box overlap, tolerating a short gap (configurable frames) for brief occlusion before dropping a track.

### 4.5 `hub/features/`
Per-`track_id` sliding-window kinematic features (hip-center vertical velocity, torso-tilt angle, aspect ratio, stillness duration) — the same feature math validated in the Pi-era design, now keyed by track rather than assuming a single person in frame.

### 4.6 `hub/classifiers/`
- `fall_state_machine.py`: `NORMAL → FALL_CANDIDATE → {CONFIRMED, SUSPECTED, CLEARED}`, same design as the Sense spec, operating per-track.
- `long_lie.py`: extends beyond the fall-confirm window — flags floor-level posture or an unusual-location motionless streak that persists well past the fall-confirmation threshold, using time-of-day and a per-resident movement baseline so normal sleep isn't flagged (PRD §8.4).

### 4.7 `hub/dementia_safety/`
`zone_rules.py`: configurable polygonal zones per camera (e.g., "exit door"). Detects repeated pacing (oscillating track movement within a region over a configured window), door approach/crossing, and unaccompanied exit (crossing an exit zone with no second track — a caregiver — co-present within a time window). Explicitly does not diagnose cognitive decline or restrict movement — it only generates events, per PRD §8.12's stated non-goals.

### 4.8 `hub/risk_scoring/`
v1 heuristic mobility/fall-risk trend: gait speed (from walking-bout track displacement), approximate sit-to-stand time, nighttime movement frequency, rolled into a weekly per-resident trend score. Labeled `v1-heuristic` in its output, framed as a trend flag, never a clinical prediction (PRD §8.13, §22 non-goals).

### 4.9 `hub/night_rounds/`
Per-resident/room status classifier: `in_bed | moving_normally | out_of_bed | not_visible | possible_distress`, derived from presence + pose + a configured "bed zone" + time-of-day window. Assists, does not replace required rounds (PRD §8.14).

### 4.10 `hub/face/`
Reuses the InsightFace-based design from the Sense spec (SCRFD/RetinaFace detection + ArcFace embedding, quality-gated snapshot selection) for visitor logging at an entry-designated camera. `visitor_store.py` stays SQLite-backed.

### 4.11 `hub/medication/`
`visit_verification.py`: flags a tracked person entering a configured med-cart/doorway zone and dwelling at least a configured duration within a configured time window — a presence check, not clinical verification (PRD §8.16 — explicitly does not verify ingestion).

### 4.12 `hub/validation/`
`LocalHeuristicValidator`, same design and rationale as the Sense spec: a second independent pass over ambiguous fall candidates, entirely local, fails open to `CONFIRMED` rather than suppressing a real alert. No cloud AI dependency anywhere in this build.

### 4.13 `hub/events/`
`event_engine.py`: builds the canonical event exactly per PRD §17 —

```json
{
  "event_id": "...", "schema_version": "1.0",
  "facility_id": "...", "building_id": "...", "floor_id": "...",
  "room_id": "...", "resident_id": "...", "camera_id": "...",
  "event_type": "fall_confirmed", "severity": "critical", "confidence": 0.94,
  "detected_at": "...", "generated_at": "...", "status": "open",
  "reason_codes": ["rapid_vertical_drop", "horizontal_torso", "remained_near_floor"],
  "evidence": {"skeleton_available": true, "incident_clip_available_locally": true, "cloud_video_available": false},
  "device_health": {"stream_fps": 7.4, "wifi_rssi": -58}
}
```

Supports every `event_type` PRD §17 lists (`fall_suspected`, `fall_confirmed`, `long_lie`, `unusual_inactivity`, `wandering`, `exit_risk`, `night_activity`, `device_offline`, `stream_degraded`, `medication_visit_missing`, `visitor_arrival`, `visitor_departure`). Handles cooldown/dedup so a sustained condition doesn't spam duplicate events.

### 4.14 `hub/offline_queue/`
Same SQLite-backed durable queue design as the Sense spec: idempotency key, retry/backoff, survives a network drop.

### 4.15 `hub/device_health/`
Aggregates per-camera FPS/dropped-frames/signal (simulated for webcam/file sources), and Hub-level CPU/GPU/RAM/inference-latency/queue-depth, formatted per PRD §19.2/§19.3.

### 4.16 `mock_backend/`
Minimal FastAPI app implementing PRD §19's endpoints (`POST /v1/hub/events`, `POST /v1/hub/health`, `POST /v1/hub/cameras/health`, `POST /v1/events/{event_id}/acknowledge`, `POST /v1/events/{event_id}/resolve`), matching the idempotent-on-`event_id` and facility/camera/resident-mapping validation PRD §19.1 requires. Persists to SQLite and exposes a read endpoint so received events are inspectable. This is the entire stand-in for Dhairya's backend — intentionally minimal, proving the contract, not building the product.

## 5. Tools

- `tools/export_pose_model.py` — exports `yolo11s-pose` to ONNX (build-time only, `ultralytics`/`torch` never required at Hub runtime).
- `tools/benchmark_pose_gpu.py` — same methodology as the Pi benchmark (mean/p50/p95/max latency, N runs after warm-up), re-run here against DirectML to get a real number before locking defaults, not reused from the Pi numbers.
- `tools/digital_twin.py` — loops several video files as simulated additional camera feeds, so the demo can show a multi-camera "facility" running on one laptop.
- `tools/live_demo.py` — skeleton-only multi-camera grid view (HTTP MJPEG, browser-viewable), the live privacy-and-capability demo.
- `tools/record_test_clip.py`, `tools/eval_harness.py` — carried over from the Sense design for building/scoring a labeled test set.

## 6. Testing

Pytest suite, no camera required: tracker (ID stability across frames, occlusion handling), each classifier (fall/long-lie/dementia-zone/night-rounds/medication) against synthetic per-track feature sequences, event engine (schema correctness, dedup/cooldown), offline queue (retry/idempotency). Live/multi-camera behavior verified via `digital_twin.py` and a real webcam smoke test.

## 7. Config

`.env`-driven: `CAMERA_SOURCES` (list — webcam index and/or video file paths, each with a role), `POSE_MODEL_PATH`, `INFERENCE_PROVIDER` (`directml` default, `cpu` fallback), `FACILITY_ID`/`BUILDING_ID` test defaults, `MOCK_BACKEND_URL`, zone-definition file paths (dementia exit zones, med-cart zone, bed zones), per-feature enable flags so any single feature (dementia safety, night-rounds, medication verification) can be toggled off without touching code.

## 8. Non-goals (explicit, confirmed by user)

No auth, RBAC enforcement, multi-tenant database/row-level security, resident/caregiver/family/admin apps or dashboards, push/SMS notification delivery, real wireless camera firmware (ESP32 units not in hand this session), or PRD P2 features (voice distress detection, bed/door sensors, insurance exports). No cloud AI dependency (no Gemini, no external API keys) — validation stays fully local, same rationale as the Sense design.

## 9. Open items deferred, not blocking this build

- Real ESP32-CAM hardware (2x HiLetgo units, ordered but not yet in hand) — `camera_source.py`'s interface is designed for a straightforward swap once they arrive, but that swap itself is future work.
- GPU inference benchmark numbers (section 5's `benchmark_pose_gpu.py`) — to be run for real once the DirectML provider is installed and verified, not assumed.
- Real recorded fall/activity footage for the validation dataset (PRD §28.1's list of required scenarios) — still a team task.
