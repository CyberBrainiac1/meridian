# Pi 4B as Meridian Hub — capacity simulation, 2026-07-02

Context: PRD v2.1 replaces per-room on-device inference with a shared
**Meridian Hub** that ingests every camera's stream and runs all AI
inference centrally (section 10, section 15.3 "Inference scheduler").
The PRD's own Hub hardware target (section 14.3) calls for an 8-core+ CPU
and an NVIDIA GPU with 16GB+ VRAM. We don't have that hardware in this
session — we have the same Pi 4B used for the earlier per-room benchmark.
Rather than assume it's unusable as a Hub, we tested it directly: no real
camera involved, synthetic frames fed through N simulated camera queues
into a single shared ONNX Runtime pose-inference engine via a round-robin
scheduler (`hub_simulator.py`, modeling the PRD's inference-scheduler
concept), measuring realized per-camera FPS as camera count scales up.

Model: same `yolo11n-pose` ONNX export used in the per-room benchmark
(256x320 input). Fan pinned to max cooling; 15s test window per camera count.

| Simulated cameras | Aggregate FPS | Min per-camera FPS | Max per-camera FPS | Mean inference latency |
|---|---|---|---|---|
| 1 | 10.80 | 10.80 | 10.80 | 92.9ms |
| 2 | 10.53 | 5.27 | 5.27 | 95.4ms |
| 4 | 10.80 | 2.67 | 2.73 | 92.8ms |
| 8 | 10.60 | 1.27 | 1.33 | 94.3ms |

**Finding: aggregate throughput is a hard, flat ceiling around ~10.7 FPS total, regardless of camera count** — a single CPU-bound inference engine on this hardware doesn't get faster by round-robining across more streams, it just divides the same fixed budget more ways. Per-camera FPS falls off almost exactly as `10.7 / N`.

**What this means:**
- A Pi-4B-class device could plausibly serve as a **minimal Hub for ~2-3 rooms** at a marginal 3-5 FPS/room — likely still workable for fall detection given the state machine's thresholds are wall-clock-based, not frame-count-based, but with less temporal margin than the single-room 10.3 FPS number from the per-room benchmark.
- It is **not viable** at the PRD's stated engineering target of "8 to 12 simultaneous camera streams, 5 to 10 processed frames per second per active room" (section 14.3) — that implies roughly 40-120 FPS of aggregate throughput, 4-11x beyond what this device delivers. This empirically confirms the PRD's own hardware spec (real CPU + GPU) is the right call for a production Hub, not a cost-cutting Pi.
- This is a genuine capacity number for engineering/cost planning (e.g., a very small pilot could run on Pi-class hardware in a pinch), not a guess.

Reproduce with `benchmarks/hub_simulator.py`.
