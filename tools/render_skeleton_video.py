"""Render a skeleton-only video from a source clip, using the real pose pipeline.

The pitch video needs the "privacy moment" beat -- raw footage dissolving into
a 17-point skeleton -- as a file Remotion can import. Screen-recording the live
/demo/skeleton page works but is fiddly and non-reproducible.

This renders the same thing offline, deliberately reusing the exact drawing
contract of meridian_insights/app/demo/skeleton/skeleton-canvas.tsx: same bone
topology, same colours from lib/tokens.ts, same confidence gate. If that page
changes, this should change with it -- otherwise the video stops matching the
product.

Nothing here fabricates pose data. Every skeleton drawn is real output from the
real ONNX model on the real source frames; frames the model does not detect a
person in are rendered empty, which is honest and is what the live page does.

    python tools/render_skeleton_video.py --source assets/video/fall.mp4 \
        --out assets/video/skeleton.mp4
"""
import argparse

import cv2
import numpy as np

from meridian_hub.vision.pose_estimator import PoseEstimator
from meridian_hub.vision.pose_types import KEYPOINT_NAMES
from meridian_hub.vision.preprocessing import preprocess_frame

# Mirrors skeleton-canvas.tsx BONES exactly.
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

# lib/tokens.ts demoSkeleton. OpenCV is BGR, these are the RGB values reversed.
BACKGROUND_BGR = (0x0A, 0x06, 0x05)   # #05060A
ACCENT_BGR = (0xC2, 0xFF, 0x22)       # #22FFC2
KEYPOINT_MIN_CONFIDENCE = 0.3         # skeleton-canvas.tsx

POSE_SPACE_W, POSE_SPACE_H = 640, 480


def _draw(canvas, detections, scale_x, scale_y, thickness, radius):
    """Bones first, then joints, so joints sit on top -- as the canvas does."""
    glow = canvas.copy()
    for person in detections:
        # Keypoints are positional, in COCO-17 order (pose_types.KEYPOINT_NAMES).
        by_name = dict(zip(KEYPOINT_NAMES, person.keypoints))
        for a, b in BONES:
            ka, kb = by_name.get(a), by_name.get(b)
            if ka is None or kb is None:
                continue
            if ka.confidence < KEYPOINT_MIN_CONFIDENCE or kb.confidence < KEYPOINT_MIN_CONFIDENCE:
                continue
            pa = (int(ka.x * scale_x), int(ka.y * scale_y))
            pb = (int(kb.x * scale_x), int(kb.y * scale_y))
            cv2.line(glow, pa, pb, ACCENT_BGR, thickness, cv2.LINE_AA)

    # Approximates the canvas's shadowBlur glow.
    blurred = cv2.GaussianBlur(glow, (0, 0), sigmaX=6)
    canvas[:] = cv2.addWeighted(canvas, 1.0, blurred, 0.6, 0)

    for person in detections:
        for kp in person.keypoints[:len(KEYPOINT_NAMES)]:
            if kp.confidence < KEYPOINT_MIN_CONFIDENCE:
                continue
            cv2.circle(canvas, (int(kp.x * scale_x), int(kp.y * scale_y)),
                       radius, ACCENT_BGR, -1, cv2.LINE_AA)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--model", default="models/yolo11s-pose-480x640.onnx")
    parser.add_argument("--provider", default="directml")
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    args = parser.parse_args()

    cap = cv2.VideoCapture(args.source)
    if not cap.isOpened():
        raise SystemExit(f"could not open {args.source}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0

    estimator = PoseEstimator(args.model, preferred_provider=args.provider)
    writer = cv2.VideoWriter(
        args.out, cv2.VideoWriter_fourcc(*"mp4v"), fps, (args.width, args.height)
    )
    if not writer.isOpened():
        raise SystemExit(f"could not open writer for {args.out}")

    scale_x = args.width / POSE_SPACE_W
    scale_y = args.height / POSE_SPACE_H
    # Keep stroke weight proportional to the 640x480 reference the page uses.
    thickness = max(1, round(3 * (args.width / POSE_SPACE_W)))
    radius = max(1, round(4 * (args.width / POSE_SPACE_W)))

    frames = detected = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        timestamp = frames / fps
        detections = estimator.estimate(
            preprocess_frame(frame, estimator.input_height, estimator.input_width), timestamp
        )
        canvas = np.full((args.height, args.width, 3), BACKGROUND_BGR, dtype=np.uint8)
        if detections:
            detected += 1
            _draw(canvas, detections, scale_x, scale_y, thickness, radius)
        writer.write(canvas)
        frames += 1

    cap.release()
    writer.release()
    pct = (100 * detected / frames) if frames else 0
    print(f"wrote {args.out}: {frames} frames @ {fps:.2f}fps, "
          f"{detected} with a detected person ({pct:.0f}%)")


if __name__ == "__main__":
    main()
