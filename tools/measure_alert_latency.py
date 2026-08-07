"""Reproducible alert-latency measurement for Meridian Hub.

The synthetic timeline deliberately defines *fall onset* as the first pose
sample crossing the fall-candidate thresholds.  This makes the physical-clock
component reproducible: it is the sequence timestamp of that sample, rather
than an operator's subjective estimate of when a person started moving.

Use --real-inference to additionally time the installed ONNX model.  The
scripted-pose run exercises all of the event/queue/dispatch chain with a known
fall outcome; it does not claim a real camera or YOLO model classified a fall.
"""
import argparse
import json
import time
from collections import defaultdict
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread

import numpy as np

from meridian_hub.alerting.notification_dispatcher import NotificationDispatcher
from meridian_hub.capture.camera_registry import CameraRecord, CameraRegistry
from meridian_hub.events.event_engine import EventEngine
from meridian_hub.hub_daemon import HubDaemon
from meridian_hub.offline_queue.queue_store import QueueStore
from meridian_hub.vision.pose_estimator import PoseEstimator
from meridian_hub.vision.pose_types import KEYPOINT_NAMES, Keypoint, PersonDetection


def pose(t: float, *, fallen: bool, hip_y: float = 100.0, angle: str = "confirmed") -> PersonDetection:
    points = [Keypoint(50.0, hip_y, 0.9) for _ in range(17)]
    if not fallen:
        points[KEYPOINT_NAMES.index("left_hip")] = Keypoint(45, hip_y, .9)
        points[KEYPOINT_NAMES.index("right_hip")] = Keypoint(55, hip_y, .9)
        points[KEYPOINT_NAMES.index("left_shoulder")] = Keypoint(45, hip_y - 60, .9)
        points[KEYPOINT_NAMES.index("right_shoulder")] = Keypoint(55, hip_y - 60, .9)
        points[KEYPOINT_NAMES.index("left_ankle")] = Keypoint(40, hip_y + 50, .9)
        points[KEYPOINT_NAMES.index("right_ankle")] = Keypoint(60, hip_y + 50, .9)
        return PersonDetection(points, (30, hip_y - 70, 70, hip_y + 60), .9, t)
    shoulder_x, hip_x = (10, 70) if angle == "confirmed" else (50, 70)
    points[KEYPOINT_NAMES.index("left_shoulder")] = Keypoint(shoulder_x, hip_y - 20, .9)
    points[KEYPOINT_NAMES.index("right_shoulder")] = Keypoint(shoulder_x + 20, hip_y - 20, .9)
    points[KEYPOINT_NAMES.index("left_hip")] = Keypoint(hip_x, hip_y, .9)
    points[KEYPOINT_NAMES.index("right_hip")] = Keypoint(hip_x + 20, hip_y, .9)
    points[KEYPOINT_NAMES.index("left_ankle")] = Keypoint(60, hip_y + 3, .9)
    points[KEYPOINT_NAMES.index("right_ankle")] = Keypoint(100, hip_y + 3, .9)
    # Preserve enough overlap with the upright box for the IoU tracker to
    # follow the same resident through the synthetic drop.
    return PersonDetection(points, (10, 90, 90, 165), .9, t)


class ScriptedEstimator:
    input_height = 256
    input_width = 320

    def __init__(self, samples):
        self.samples = iter(samples)

    def estimate(self, _frame, _timestamp):
        return [next(self.samples)]


def sequence(path: str):
    if path == "confirmed":
        # Candidate at t=.4, horizontal and still at t=2.4.
        return [(0.0, pose(0, fallen=False)), (.4, pose(.4, fallen=True, hip_y=160)),
                (2.4, pose(2.4, fallen=True, hip_y=160))]
    # Candidate at .4. Move four px/sample to prevent the stillness shortcut;
    # candidate-window fallback fires at 3.5 seconds.
    return [(0.0, pose(0, fallen=False)), (.4, pose(.4, fallen=True, hip_y=160, angle="suspected")),
            (.8, pose(.8, fallen=True, hip_y=164, angle="suspected")),
            (1.2, pose(1.2, fallen=True, hip_y=168, angle="suspected")),
            (1.6, pose(1.6, fallen=True, hip_y=172, angle="suspected")),
            (2.0, pose(2.0, fallen=True, hip_y=176, angle="suspected")),
            (2.4, pose(2.4, fallen=True, hip_y=180, angle="suspected")),
            (2.8, pose(2.8, fallen=True, hip_y=184, angle="suspected")),
            # Still moving enough at timeout to be inconclusive rather than
            # classified as a controlled sit by the local validator.
            (3.5, pose(3.5, fallen=True, hip_y=350, angle="suspected"))]


def percentile(values, p):
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * p / 100)]


def summarize(samples):
    return {k: {"p50_ms": round(percentile(v, 50), 3), "p95_ms": round(percentile(v, 95), 3),
                "max_ms": round(max(v), 3)} for k, v in samples.items()}


def run_once(path: str):
    stages = defaultdict(float)
    timeline = sequence(path)
    queue = QueueStore(":memory:")
    registry = CameraRegistry(":memory:")
    registry.register(CameraRecord("cam-1", "fac", "bld", "floor", "room", "resident", "synthetic", "active"))
    daemon = HubDaemon(
        ScriptedEstimator([item for _, item in timeline]), EventEngine(), queue, registry,
        stage_observer=lambda stage, milliseconds: stages.__setitem__(stage, stages[stage] + milliseconds),
    )
    delivered = []

    class AckHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            length = int(self.headers["Content-Length"])
            delivered.append(json.loads(self.rfile.read(length))["event_id"])
            self.send_response(202)
            self.end_headers()

        def log_message(self, _format, *_args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), AckHandler)
    server_thread = Thread(target=lambda: server.serve_forever(poll_interval=0.001), daemon=True)
    server_thread.start()
    dispatcher = NotificationDispatcher(queue, f"http://127.0.0.1:{server.server_port}/ingest")
    frame = np.zeros((32, 32, 3), dtype=np.uint8)
    onset = timeline[1][0]
    for timestamp, _ in timeline:
        events = daemon.process_frame("cam-1", frame, timestamp)
        stages["capture"] += 0.0  # synthetic source has no capture latency
        if events:
            enqueue_start = time.perf_counter_ns()
            results = dispatcher.dispatch_pending(timestamp)
            stages["dispatch_ack"] += (time.perf_counter_ns() - enqueue_start) / 1e6
            assert results and results[0].delivered and delivered == [events[0].event_id]
            detection_seconds = timestamp - onset
            server.shutdown()
            server.server_close()
            server_thread.join(timeout=1)
            queue.close()
            registry.close()
            return stages, detection_seconds
    raise RuntimeError(f"{path} sequence did not emit an event")


def real_inference(model: str, provider: str, runs: int):
    estimator = PoseEstimator(model, provider)
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    from meridian_hub.vision.preprocessing import preprocess_frame
    for _ in range(5):
        prepared = preprocess_frame(frame, estimator.input_height, estimator.input_width)
        estimator.estimate(prepared, 0.0)
    prep, infer = [], []
    for _ in range(runs):
        started = time.perf_counter_ns()
        prepared = preprocess_frame(frame, estimator.input_height, estimator.input_width)
        midpoint = time.perf_counter_ns()
        estimator.estimate(prepared, 0.0)
        prep.append((midpoint - started) / 1e6)
        infer.append((time.perf_counter_ns() - midpoint) / 1e6)
    return {"provider": estimator.active_provider, "preprocess": summarize({"preprocess": prep})["preprocess"],
            "inference_decode": summarize({"inference_decode": infer})["inference_decode"]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", type=int, default=100)
    parser.add_argument("--model", default="models/yolo11s-pose-480x640.onnx")
    parser.add_argument("--provider", default="directml", choices=("directml", "cpu"))
    parser.add_argument("--real-inference", action="store_true")
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    result = {"generated_at": datetime.now(timezone.utc).isoformat(), "runs": args.runs, "paths": {}}
    for path in ("confirmed", "suspected"):
        grouped, logical = defaultdict(list), []
        for _ in range(args.runs):
            stages, detection_seconds = run_once(path)
            for name, value in stages.items():
                grouped[name].append(value)
            logical.append(detection_seconds * 1000)
        grouped["detection_logical"] = logical
        grouped["total_wall_overhead"] = [
            sum(grouped[name][index] for name in grouped if name != "detection_logical")
            for index in range(args.runs)
        ]
        result["paths"][path] = summarize(grouped)
    if args.real_inference:
        result["real_pose_stage"] = real_inference(args.model, args.provider, args.runs)
    rendered = json.dumps(result, indent=2)
    print(rendered)
    if args.json_out:
        args.json_out.write_text(rendered + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
