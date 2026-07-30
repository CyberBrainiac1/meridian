"""Find the best-posed frame in a video and hold it on the skeleton relay.

Live video streams past too fast to screenshot a well-composed skeleton --
you get whatever instant you happened to click. This scans a clip with the
real pose pipeline, picks the frame with the cleanest single figure (most
confident keypoints, well inside the frame), then broadcasts that one
detection on repeat so the real /demo/skeleton page renders a stable image
you can screenshot for a deck, a slide, or the website.

It is the same relay and the same page the live demo uses -- nothing is
mocked or redrawn, it's just held still.

    python tools/hold_pose_frame.py --source tests/fixtures/videos/one-by-one-person-detection.mp4
    # then open http://localhost:3000/demo/skeleton and screenshot
"""
import argparse
import time

import cv2
import numpy as np

from meridian_hub.demo_relay import DemoPoseRelay
from meridian_hub.vision.pose_estimator import PoseEstimator
from meridian_hub.vision.pose_types import KEYPOINT_NAMES
from meridian_hub.vision.preprocessing import preprocess_frame

# Keypoints that make a skeleton read as a human figure at a glance.
CORE = [5, 6, 11, 12, 13, 14, 15, 16]  # shoulders, hips, knees, ankles
MIN_KP_CONF = 0.5

# Bone pairs mirror meridian_insights/app/demo/skeleton/skeleton-canvas.tsx
# so an exported still matches what the live demo page draws.
BONES = [
    ("nose", "left_eye"), ("nose", "right_eye"),
    ("left_eye", "left_ear"), ("right_eye", "right_ear"),
    ("left_shoulder", "right_shoulder"),
    ("left_shoulder", "left_elbow"), ("left_elbow", "left_wrist"),
    ("right_shoulder", "right_elbow"), ("right_elbow", "right_wrist"),
    ("left_shoulder", "left_hip"), ("right_shoulder", "right_hip"),
    ("left_hip", "right_hip"),
    ("left_hip", "left_knee"), ("left_knee", "left_ankle"),
    ("right_hip", "right_knee"), ("right_knee", "right_ankle"),
]
ACCENT = (168, 230, 46)  # BGR of the page's #2EE6A8
BG = (5, 5, 5)


def render_still(det, src_w, src_h, out_w=1920, out_h=1080):
    """Print-quality render of one pose, styled like the live demo page.
    The pose data is the pipeline's real output; this just draws it at a
    resolution suitable for a slide instead of a browser screenshot."""
    img = np.full((out_h, out_w, 3), BG, dtype=np.uint8)
    # Fit the source frame into the canvas without distorting the figure.
    s = min(out_w / src_w, out_h / src_h)
    ox, oy = (out_w - src_w * s) / 2, (out_h - src_h * s) / 2

    def pt(kp):
        return int(kp.x * s + ox), int(kp.y * s + oy)

    idx = {n: i for i, n in enumerate(KEYPOINT_NAMES)}
    # Two passes: a soft wide stroke for glow, then the crisp bone on top.
    for width, colour in ((13, (60, 90, 40)), (4, ACCENT)):
        for a, b in BONES:
            ka, kb = det.keypoints[idx[a]], det.keypoints[idx[b]]
            if ka.confidence < MIN_KP_CONF or kb.confidence < MIN_KP_CONF:
                continue
            cv2.line(img, pt(ka), pt(kb), colour, width, cv2.LINE_AA)
    for kp in det.keypoints:
        if kp.confidence >= MIN_KP_CONF:
            cv2.circle(img, pt(kp), 6, ACCENT, -1, cv2.LINE_AA)

    font = cv2.FONT_HERSHEY_SIMPLEX
    cv2.circle(img, (40, 46), 8, ACCENT, -1, cv2.LINE_AA)
    cv2.putText(img, "SENSE - LIVE POSE FEED", (60, 54), font, 0.75, ACCENT, 2, cv2.LINE_AA)
    cv2.putText(img, "NO VIDEO TRANSMITTED - SKELETON DATA ONLY",
                (34, out_h - 40), font, 0.65, (150, 150, 150), 2, cv2.LINE_AA)
    return img


def score(det, width, height):
    """Prefer a complete, confident, well-centred figure."""
    kps = det.keypoints
    core_ok = sum(1 for i in CORE if kps[i].confidence >= MIN_KP_CONF)
    if core_ok < len(CORE):
        return -1.0  # missing a limb -- won't read as a person
    x1, y1, x2, y2 = det.bbox
    if x1 < 4 or y1 < 4 or x2 > width - 4 or y2 > height - 4:
        return -1.0  # clipped by the frame edge
    tallness = (y2 - y1) / height  # a bigger figure fills the slide better
    mean_conf = sum(k.confidence for k in kps) / len(kps)
    return tallness * 2.0 + mean_conf + det.confidence


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--model", default="models/yolo11s-pose-480x640.onnx")
    parser.add_argument("--provider", default="directml")
    parser.add_argument("--relay-port", type=int, default=8765)
    parser.add_argument("--max-frames", type=int, default=600)
    parser.add_argument("--export", default=None,
                        help="Also write a print-quality PNG of the chosen pose to this path.")
    parser.add_argument("--no-serve", action="store_true",
                        help="Just export the still and exit; don't start the relay.")
    args = parser.parse_args()

    estimator = PoseEstimator(model_path=args.model, preferred_provider=args.provider)
    cap = cv2.VideoCapture(args.source)
    if not cap.isOpened():
        raise SystemExit(f"Could not open {args.source}")

    best, best_score, best_idx = None, -1.0, -1
    idx = 0
    while idx < args.max_frames:
        ok, frame = cap.read()
        if not ok:
            break
        idx += 1
        pre = preprocess_frame(frame, estimator.input_height, estimator.input_width)
        for det in estimator.estimate(pre, float(idx)):
            s = score(det, estimator.input_width, estimator.input_height)
            if s > best_score:
                best, best_score, best_idx = det, s, idx
    cap.release()

    if best is None:
        raise SystemExit("No clean full-body pose found in this clip -- try another source.")
    print(f"Best frame: #{best_idx} (score {best_score:.2f}, detection confidence {best.confidence:.2f})")

    if args.export:
        still = render_still(best, estimator.input_width, estimator.input_height)
        cv2.imwrite(args.export, still)
        print(f"Exported still: {args.export} ({still.shape[1]}x{still.shape[0]})")
    if args.no_serve:
        return

    relay = DemoPoseRelay(host="127.0.0.1", port=args.relay_port)
    if not relay.start():
        raise SystemExit(f"Relay could not bind port {args.relay_port} -- is another demo still running?")
    print(f"Holding this pose on ws://localhost:{args.relay_port}/ws/pose")
    print("Open /demo/skeleton and screenshot. Ctrl+C to stop.")

    try:
        t = 0.0
        while True:
            t += 0.1
            relay.broadcast("cam-demo", [best], t)
            time.sleep(0.1)
    except KeyboardInterrupt:
        pass
    finally:
        relay.stop()


if __name__ == "__main__":
    main()
