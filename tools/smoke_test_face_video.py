"""Real end-to-end smoke test for the face pipeline: real InsightFace
model, real video frames (not a static photo, not a webcam), real quality
gate. Confirms detector.py's quality thresholds are sane against actual
footage rather than only the synthetic checkerboard/flat-gray frames its
unit tests use.

Usage:
    python tools/smoke_test_face_video.py --video tests/fixtures/videos/people-detection.mp4
"""
import argparse

import cv2

from meridian_hub.face.detector import score_detection, select_best_detection
from meridian_hub.face.recognizer import FaceRecognizer


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--video", required=True)
    parser.add_argument("--max-frames", type=int, default=200)
    parser.add_argument("--sample-every", type=int, default=5)
    args = parser.parse_args()

    recognizer = FaceRecognizer()  # default provider (cpu) -- see recognizer.py for why
    print(f"Recognizer ready, provider={recognizer.active_provider}")

    cap = cv2.VideoCapture(args.video)
    frame_count = 0
    frames_with_face = 0
    frames_with_passing_face = 0
    best_quality_seen = None

    while frame_count < args.max_frames:
        ok, frame = cap.read()
        if not ok:
            break
        frame_count += 1
        if frame_count % args.sample_every != 0:
            continue

        detections = recognizer.detect_and_embed(frame)
        if detections:
            frames_with_face += 1
            best = select_best_detection(frame, detections)
            if best is not None:
                frames_with_passing_face += 1
                score = score_detection(frame, best)
                if best_quality_seen is None or score.sharpness > best_quality_seen.sharpness:
                    best_quality_seen = score

    cap.release()
    print(f"\n=== Face smoke test: {args.video} ===")
    print(f"frames sampled: {frame_count // args.sample_every}")
    print(f"frames with >=1 raw face detection: {frames_with_face}")
    print(f"frames with a quality-gate-passing face: {frames_with_passing_face}")
    if best_quality_seen:
        print(f"best quality seen: sharpness={best_quality_seen.sharpness:.1f} size_px={best_quality_seen.size_px:.1f}")


if __name__ == "__main__":
    main()
