"""Measure fair, serial multi-camera pose throughput on the local Hub GPU.

Synthetic normalized tensors isolate shared-inference capacity from USB/network
camera capture.  Every logical camera receives turns through InferenceScheduler;
there is one real ONNX inference per accepted frame.
"""
import argparse
import json
import time

import numpy as np

from meridian_hub.scheduler.inference_scheduler import InferenceScheduler
from meridian_hub.vision.pose_estimator import PoseEstimator


def measure(estimator, cameras, seconds):
    scheduler = InferenceScheduler([f"cam-{i}" for i in range(cameras)])
    frame = np.zeros((1, 3, estimator.input_height, estimator.input_width), dtype=np.float32)
    counts = {f"cam-{i}": 0 for i in range(cameras)}
    end = time.perf_counter() + seconds
    while time.perf_counter() < end:
        camera_id = scheduler.next_camera()
        estimator.estimate(frame, time.perf_counter())
        counts[camera_id] += 1
    values = list(counts.values())
    elapsed = seconds
    return {"cameras": cameras, "aggregate_fps": round(sum(values) / elapsed, 2),
            "min_camera_fps": round(min(values) / elapsed, 2), "max_camera_fps": round(max(values) / elapsed, 2),
            "frames_per_camera": counts}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="models/yolo11s-pose-480x640.onnx")
    parser.add_argument("--provider", default="directml", choices=("directml", "cpu"))
    parser.add_argument("--seconds", type=float, default=5.0)
    parser.add_argument("--cameras", type=int, nargs="+", default=[1, 2, 4, 8, 12, 16, 20])
    args = parser.parse_args()
    estimator = PoseEstimator(args.model, args.provider)
    for _ in range(5):
        estimator.estimate(np.zeros((1, 3, estimator.input_height, estimator.input_width), dtype=np.float32), 0.0)
    output = {"provider": estimator.active_provider, "input": [estimator.input_height, estimator.input_width],
              "seconds_per_case": args.seconds, "results": [measure(estimator, n, args.seconds) for n in args.cameras]}
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
