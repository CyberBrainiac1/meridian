"""Live pitch-demo runner: the single command that drives the whole
on-stage demo. Opens a camera (webcam or a pre-recorded staged-fall
clip), runs the real HubDaemon pipeline frame-by-frame with the demo
skeleton relay attached, and prints/delivers fall + visitor events as
they happen.

    python tools/run_live_demo.py --source 0                # live webcam
    python tools/run_live_demo.py --source clip.mp4 --loop  # rehearsed clip

While this runs, open the skeleton view in a browser on the same machine:
    meridian_insights /demo/skeleton   (connects to ws://localhost:8765/ws/pose)
or just point any WebSocket client at that URL. Every processed frame with
a person in it streams a COCO-17 skeleton to that page -- that is the
"privacy moment" pitch beat (skeleton, never raw video).

Fall events are printed prominently and delivered through the real
offline-queue -> NotificationDispatcher path. By default delivery targets
--backend-url; if that's unreachable the event stays safely queued
(offline-first) and the on-screen banner still fires, so the visible demo
never depends on the network being up.
"""
import argparse
import signal
import sys
import time

import cv2

from meridian_hub.alerting.alert_formatter import format_alert_message
from meridian_hub.alerting.notification_dispatcher import NotificationDispatcher
from meridian_hub.capture.camera_registry import CameraRecord, CameraRegistry
from meridian_hub.demo_relay import DemoPoseRelay
from meridian_hub.events.event_engine import EventEngine
from meridian_hub.hub_daemon import HubDaemon
from meridian_hub.offline_queue.queue_store import QueueStore
from meridian_hub.scheduler.inference_scheduler import InferenceScheduler
from meridian_hub.vision.pose_estimator import PoseEstimator

BANNER = "\033[1;97;41m"  # bold white on red
GREEN = "\033[1;92m"
DIM = "\033[2m"
RESET = "\033[0m"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", action="append", default=None,
                        help="webcam index or video path; repeat for multiple rooms (default: 0)")
    parser.add_argument("--model", default="models/yolo11s-pose-480x640.onnx")
    parser.add_argument("--provider", default="directml", choices=["directml", "cpu"])
    parser.add_argument("--room", default="room-12")
    parser.add_argument("--resident", default="Maggie")
    parser.add_argument("--relay-port", type=int, default=8765)
    parser.add_argument("--backend-url", default="http://localhost:8000/ingest-event")
    parser.add_argument("--loop", action="store_true", help="loop a video file forever (rehearsal)")
    parser.add_argument("--target-fps", type=float, default=15.0)
    args = parser.parse_args()

    print(f"{DIM}Loading pose model ({args.provider})...{RESET}")
    estimator = PoseEstimator(model_path=args.model, preferred_provider=args.provider)
    print(f"{DIM}Pose model ready on: {estimator.active_provider}{RESET}")

    relay = DemoPoseRelay(host="127.0.0.1", port=args.relay_port)
    if relay.start():
        print(f"{GREEN}Skeleton relay live at ws://localhost:{args.relay_port}/ws/pose{RESET}")
        print(f"{DIM}Open the Insights /demo/skeleton page now to see the live skeleton.{RESET}")
    else:
        print(f"{BANNER}  SKELETON RELAY DID NOT START  {RESET}")
        print(f"{DIM}  Port {args.relay_port} is likely still held by a previous run. The fall")
        print(f"  detection below still works, but the live skeleton view will be blank.")
        print(f"  Fix: close any old demo terminal, or run with --relay-port 8766, and retry.{RESET}")

    source_values = args.source or ["0"]
    registry = CameraRegistry(db_path=":memory:")
    camera_sources = {f"cam-demo-{index + 1}": source for index, source in enumerate(source_values)}
    for camera_id, source_value in camera_sources.items():
        registry.register(CameraRecord(
            camera_id=camera_id, facility_id="fac-poc-001", building_id="bld-poc-001",
            floor_id="flr-1", room_id=args.room, resident_id=args.resident,
            source=source_value, privacy_state="active",
        ))
    queue = QueueStore(db_path=":memory:")
    daemon = HubDaemon(
        pose_estimator=estimator, event_engine=EventEngine(),
        queue_store=queue, camera_registry=registry, demo_relay=relay,
    )
    dispatcher = NotificationDispatcher(queue, args.backend_url)

    captures = {}
    for camera_id, source_value in camera_sources.items():
        source = int(source_value) if source_value.isdigit() else source_value
        cap = cv2.VideoCapture(source)
        if not cap.isOpened():
            for opened in captures.values():
                opened.release()
            print(f"Could not open source for {camera_id}: {source_value}", file=sys.stderr)
            sys.exit(1)
        captures[camera_id] = cap

    running = {"on": True}

    def stop(*_):
        running["on"] = False
    signal.signal(signal.SIGINT, stop)

    print(f"{GREEN}Running. Stage a fall in view of the camera. Ctrl+C to stop.{RESET}\n")
    frame_interval = 1.0 / args.target_fps
    timestamps = {camera_id: 0.0 for camera_id in camera_sources}
    scheduler = InferenceScheduler(list(camera_sources))
    people_seen: set[str] = set()
    try:
        while running["on"]:
            t_frame = time.perf_counter()
            camera_id = scheduler.next_camera()
            cap = captures[camera_id]
            ok, frame = cap.read()
            if not ok:
                source_value = camera_sources[camera_id]
                if args.loop and not source_value.isdigit():
                    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    continue
                break
            timestamps[camera_id] += frame_interval
            ts = timestamps[camera_id]

            events = daemon.process_frame(camera_id, frame, ts)

            # Surface skeleton presence once so the presenter knows the
            # relay has something to show.
            n_tracked = len(daemon._trackers[camera_id]._active) if camera_id in daemon._trackers else 0
            if n_tracked and camera_id not in people_seen:
                people_seen.add(camera_id)
                if relay.is_serving():
                    print(f"{GREEN}Person detected on {camera_id} -- skeleton is now streaming to the demo page.{RESET}")
                else:
                    print(f"{DIM}Person detected (skeleton relay is down -- see warning above).{RESET}")

            for event in events:
                if event.event_type == "fall_confirmed":
                    msg = format_alert_message(event, resident_display_name=args.resident)
                    print(f"\n{BANNER}  FALL CONFIRMED  {RESET} {GREEN}{msg}{RESET}")
                    print(f"{DIM}  event_id={event.event_id} room={event.room_id} "
                          f"confidence={event.confidence:.2f} -> queued for app notification{RESET}\n")
                else:
                    print(f"{DIM}  event: {event.event_type} ({event.severity}) in {event.room_id}{RESET}")

            # Deliver anything queued (app push via backend). Never blocks
            # the visible demo -- failures stay queued, offline-first.
            dispatcher.dispatch_pending(now=max(timestamps.values()))

            elapsed = time.perf_counter() - t_frame
            # Scheduler visits every camera in turn, so this aggregate pacing
            # preserves --target-fps as a per-camera target instead of dividing
            # it by the number of configured rooms.
            aggregate_interval = frame_interval / len(camera_sources)
            if elapsed < aggregate_interval:
                time.sleep(aggregate_interval - elapsed)
    finally:
        for cap in captures.values():
            cap.release()
        relay.stop()
        print(f"\n{DIM}Demo stopped. {queue.pending(now=max(timestamps.values()) + 1e9).__len__()} event(s) still queued "
              f"(would deliver once the backend is reachable).{RESET}")


if __name__ == "__main__":
    main()
