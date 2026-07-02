# Laptop GPU pose inference benchmark — 2026-07-02

Hardware: Intel Core Ultra 9 275HX (24 cores), NVIDIA GeForce RTX 5060 Laptop GPU,
Windows 11. Same benchmark methodology as `benchmarks/pi4b_pose_benchmark_2026-07-02.md`
so the numbers are directly comparable.

Model: `yolo11s-pose` (Ultralytics small pose variant — one size up from the `yolo11n-pose`
used on the Pi, since this hardware has real headroom), exported to ONNX (opset 17), run via
`onnxruntime` with the `DmlExecutionProvider` (DirectML) through `meridian_hub.vision.pose_estimator.PoseEstimator`.
50 timed runs after 5 warm-up runs, synthetic input.

| Input size | Mean latency | p95 | Max sustained FPS |
|---|---|---|---|
| 256x320 | 2.1ms | 2.3ms | 467.95 |
| 480x640 | 4.6ms | 4.8ms | 218.50 |

Compare to the Pi 4B (`yolo11n-pose`, CPU only): 320x256 → 96.9ms (10.32 FPS), 640x480 →
346.6ms (2.89 FPS, not viable). This machine's GPU is **20-75x faster** than the Pi's CPU
path, even running a bigger, more accurate model.

**Decision: no resolution compromise needed.** Unlike the Pi, where 640x480 was ruled out
for being 3x too slow, this hardware runs full 640x480 at 218 FPS with huge margin over any
realistic camera frame rate (a webcam or ESP32-CAM tops out well under 30-60 FPS). Shipped
default becomes **640x480 at a camera-limited 30 FPS** (the bottleneck is the camera, not
the model) rather than a model-limited lower resolution.

This also directly answers the PRD's own Hub engineering target (section 14.3: "8 to 12
simultaneous camera streams, 5 to 10 processed frames per second per active room"): at
218 FPS aggregate single-stream throughput, this machine could serve roughly 20+ simultaneous
480p camera streams at 10 FPS each with room to spare -- a real GPU machine clears the
PRD's own target, confirming the Pi-as-Hub finding (benchmarks/pi4b_hub_capacity_2026-07-02.md)
wasn't a tooling problem, it was a hardware-class problem.

Reproduce with `tools/benchmark_pose_gpu.py --model models/yolo11s-pose-480x640.onnx --provider directml`.
