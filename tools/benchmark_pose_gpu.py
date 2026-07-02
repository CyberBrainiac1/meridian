"""Real inference-latency benchmark for the Hub's PoseEstimator, run
against whatever execution provider is actually configured -- same
methodology as benchmarks/benchmark_pose.py (Pi 4B), so the numbers are
directly comparable. This is what sets TARGET_FPS in .env.example; it is
not assumed, it is measured on this exact machine.

Usage:
    python tools/benchmark_pose_gpu.py --model models/yolo11s-pose.onnx --provider directml
"""
import argparse
import time

import numpy as np

from meridian_hub.vision.pose_estimator import PoseEstimator


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="models/yolo11s-pose.onnx")
    parser.add_argument("--provider", default="directml", choices=["directml", "cpu"])
    parser.add_argument("--warmup", type=int, default=5)
    parser.add_argument("--runs", type=int, default=50)
    args = parser.parse_args()

    estimator = PoseEstimator(model_path=args.model, preferred_provider=args.provider)
    print(f"Active provider: {estimator.active_provider}")
    print(f"Input size: {estimator.input_height}x{estimator.input_width}")

    rng = np.random.default_rng(0)
    frame = rng.random((1, 3, estimator.input_height, estimator.input_width), dtype=np.float32)

    for _ in range(args.warmup):
        estimator.estimate(frame, timestamp=0.0)

    latencies = []
    for _ in range(args.runs):
        t0 = time.perf_counter()
        estimator.estimate(frame, timestamp=0.0)
        latencies.append(time.perf_counter() - t0)

    latencies = np.array(latencies)
    mean_ms = latencies.mean() * 1000
    p50_ms = np.percentile(latencies, 50) * 1000
    p95_ms = np.percentile(latencies, 95) * 1000
    max_ms = latencies.max() * 1000
    fps = 1.0 / latencies.mean()

    print(f"\n=== {args.model} ({estimator.active_provider}) benchmark ===")
    print(f"runs: {args.runs} (after {args.warmup} warmup)")
    print(f"mean:  {mean_ms:.1f} ms")
    print(f"p50:   {p50_ms:.1f} ms")
    print(f"p95:   {p95_ms:.1f} ms")
    print(f"max:   {max_ms:.1f} ms")
    print(f"max sustainable FPS (mean-based): {fps:.2f}")


if __name__ == "__main__":
    main()
