# Pi 4B pose inference benchmark — 2026-07-02

Hardware: Raspberry Pi 4 Model B Rev 1.4, Cortex-A72 quad-core @ 1.8GHz max, 8GB RAM,
Debian 13 (trixie) aarch64, Python 3.13.5. Fan pinned to max cooling state throughout
(confirmed via `vcgencmd get_throttled` == `0x0` and clock held at 1800MHz — no thermal
throttling affected these numbers).

Model: `yolo11n-pose` (Ultralytics nano pose variant, 17 COCO keypoints), exported to ONNX
(opset 17), run via `onnxruntime.InferenceSession` (CPUExecutionProvider, intra_op_num_threads=4).
50 timed runs after 5 warm-up runs, synthetic input (no camera in the loop — pure inference cost).

| Input size | Mean latency | p50 | p95 | Max | Max sustained FPS |
|---|---|---|---|---|---|
| 640x480 | 346.6ms | 342.0ms | 379.8ms | 413.8ms | 2.89 |
| 320x256 | 96.9ms  | 92.7ms  | 116.1ms | 130.8ms | 10.32 |
| 256x192 | 55.8ms  | 55.4ms  | 59.0ms  | 60.5ms  | 17.93 |

**Decision: ship 320x256 as the default capture/inference resolution.** It lands almost
exactly on the original 10 FPS target with a real number behind it. 640x480 is not viable
(under 3 FPS). 256x192 is available as a documented option for more latency margin, pending
a keypoint-accuracy check against real footage (not just speed).

Reproduce with `benchmarks/benchmark_pose.py` (point `MODEL_PATH` at any exported `.onnx`).
