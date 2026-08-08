"""Real end-to-end smoke test: real exported model, real video frames,
real HubDaemon wiring. Everything up to this point was verified with
synthetic keypoints or a synthetic benchmark tensor -- this is the first
time the actual decode_yolo_pose_output logic runs against genuine model
output from a real frame, which is exactly the kind of thing that could
be subtly wrong (e.g. a transposed axis, a wrong confidence threshold)
without ever failing a unit test built on hand-crafted arrays.

Usage:
    python tools/smoke_test_video.py --video tests/fixtures/videos/people-detection.mp4
"""
import argparse
import time

import cv2

from meridian_hub.capture.camera_registry import CameraRecord, CameraRegistry
from meridian_hub.events.event_engine import EventEngine
from meridian_hub.hub_daemon import HubDaemon
from meridian_hub.offline_queue.queue_store import QueueStore
from meridian_hub.vision.pose_estimator import PoseEstimator


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--video", required=True)
    parser.add_argument("--model", default="models/yolo11s-pose-480x640.onnx")
    parser.add_argument("--max-frames", type=int, default=200)
    args = parser.parse_args()

    registry = CameraRegistry(db_path=":memory:")
    registry.register(CameraRecord(
        camera_id="cam-smoke", facility_id="fac-smoke", building_id="bld-smoke",
        floor_id="flr-smoke", room_id="room-smoke", resident_id="res-smoke",
        source=args.video, privacy_state="active",
    ))
    daemon = HubDaemon(
        pose_estimator=PoseEstimator(model_path=args.model, preferred_provider="directml"),
        event_engine=EventEngine(),
        queue_store=QueueStore(db_path=":memory:"),
        camera_registry=registry,
    )

    cap = cv2.VideoCapture(args.video)
    # Timestamps must reflect the clip's REAL frame rate. Every kinematic
    # feature the fall classifier reads is a rate (px/sec, degrees, stillness
    # seconds), so assuming the wrong fps silently rescales velocity and makes
    # a genuine fall undetectable. This was hardcoded to 10.0 and quietly
    # suppressed real detections on any clip that was not ~10fps.
    fps = cap.get(cv2.CAP_PROP_FPS) or 10.0
    frame_count = 0
    detection_frame_count = 0
    max_people_in_one_frame = 0
    total_events = 0
    errors = []
    t_start = time.perf_counter()

    while frame_count < args.max_frames:
        ok, frame = cap.read()
        if not ok:
            break
        frame_count += 1
        timestamp = frame_count / fps

        try:
            events = daemon.process_frame("cam-smoke", frame, timestamp)
        except Exception as e:
            errors.append(f"frame {frame_count}: {type(e).__name__}: {e}")
            continue

        total_events += len(events)
        tracked_now = daemon._trackers["cam-smoke"]._active
        if tracked_now:
            detection_frame_count += 1
            max_people_in_one_frame = max(max_people_in_one_frame, len(tracked_now))

        for event in events:
            print(f"  EVENT @ frame {frame_count}: {event.event_type} conf={event.confidence:.2f} reason={event.reason_codes}")

    elapsed = time.perf_counter() - t_start
    cap.release()

    print(f"\n=== Smoke test: {args.video} ===")
    print(f"frames processed: {frame_count}")
    print(f"frames with at least one detection: {detection_frame_count} ({100*detection_frame_count/max(frame_count,1):.0f}%)")
    print(f"max people tracked simultaneously: {max_people_in_one_frame}")
    print(f"total events emitted: {total_events}")
    print(f"errors: {len(errors)}")
    for err in errors[:5]:
        print(f"  {err}")
    print(f"wall-clock time: {elapsed:.2f}s ({frame_count/elapsed:.1f} frames/sec including preprocessing+decode+tracking+classification)")


if __name__ == "__main__":
    main()
