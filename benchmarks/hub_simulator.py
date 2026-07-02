"""
Hub capacity simulator: no real camera involved. Feeds synthetic frames
through N simulated camera queues into a single shared pose-inference
engine using a round-robin scheduler (modeling PRD v2.1 section 15.3's
"Inference scheduler"), and measures realized per-camera FPS.

This answers: "if this Pi 4B were the Meridian Hub, how many simulated
camera streams could it actually service, and at what per-camera frame
rate?" -- purely a scheduling/throughput test, not a capture test.
"""
import argparse
import queue
import threading
import time

import numpy as np
import onnxruntime as ort

MODEL_PATH = "/home/pranav/yolo11n-pose-320x240.onnx"  # actual tensor: 1x3x256x320


class FakeCamera(threading.Thread):
    """Simulates a camera producing frames at TARGET_FPS into a bounded queue."""

    def __init__(self, cam_id, input_shape, produce_fps=15):
        super().__init__(daemon=True)
        self.cam_id = cam_id
        self.q = queue.Queue(maxsize=2)  # small buffer -- realistic camera behavior
        self.input_shape = input_shape
        self.produce_fps = produce_fps
        self.stop_flag = threading.Event()
        self.produced = 0
        rng = np.random.default_rng(cam_id)
        self._frame = rng.random(input_shape, dtype=np.float32)

    def run(self):
        interval = 1.0 / self.produce_fps
        while not self.stop_flag.is_set():
            try:
                self.q.put_nowait((self.cam_id, self._frame, time.perf_counter()))
                self.produced += 1
            except queue.Full:
                pass  # camera drops frame if Hub hasn't kept up -- realistic
            time.sleep(interval)

    def stop(self):
        self.stop_flag.set()


def run_hub_scheduler(n_cameras, duration_s, input_shape):
    so = ort.SessionOptions()
    so.intra_op_num_threads = 4
    so.inter_op_num_threads = 1
    session = ort.InferenceSession(MODEL_PATH, sess_options=so, providers=["CPUExecutionProvider"])
    input_name = session.get_inputs()[0].name

    cameras = [FakeCamera(i, input_shape) for i in range(n_cameras)]
    for cam in cameras:
        cam.start()

    processed_per_cam = {i: 0 for i in range(n_cameras)}
    latencies = []
    end_time = time.perf_counter() + duration_s
    idx = 0
    while time.perf_counter() < end_time:
        cam = cameras[idx % n_cameras]
        idx += 1
        try:
            cam_id, frame, produced_at = cam.q.get(timeout=0.5)
        except queue.Empty:
            continue
        t0 = time.perf_counter()
        session.run(None, {input_name: frame})
        latencies.append(time.perf_counter() - t0)
        processed_per_cam[cam_id] += 1

    for cam in cameras:
        cam.stop()
    for cam in cameras:
        cam.join(timeout=1.0)

    total_processed = sum(processed_per_cam.values())
    total_produced = sum(cam.produced for cam in cameras)
    aggregate_fps = total_processed / duration_s
    per_cam_fps = {i: processed_per_cam[i] / duration_s for i in range(n_cameras)}
    return {
        "n_cameras": n_cameras,
        "duration_s": duration_s,
        "total_produced": total_produced,
        "total_processed": total_processed,
        "aggregate_fps": aggregate_fps,
        "min_per_cam_fps": min(per_cam_fps.values()),
        "max_per_cam_fps": max(per_cam_fps.values()),
        "mean_inference_ms": (sum(latencies) / len(latencies)) * 1000 if latencies else 0.0,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration", type=float, default=15.0)
    args = parser.parse_args()

    input_shape = (1, 3, 256, 320)
    print(f"{'cameras':>8} {'agg_fps':>10} {'min_cam_fps':>12} {'max_cam_fps':>12} {'mean_ms':>10} {'produced':>10} {'processed':>10}")
    for n in [1, 2, 4, 8]:
        r = run_hub_scheduler(n, args.duration, input_shape)
        print(f"{r['n_cameras']:>8} {r['aggregate_fps']:>10.2f} {r['min_per_cam_fps']:>12.2f} "
              f"{r['max_per_cam_fps']:>12.2f} {r['mean_inference_ms']:>10.1f} "
              f"{r['total_produced']:>10} {r['total_processed']:>10}")
