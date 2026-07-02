"""Export a YOLO pose model to ONNX at a given input size. Build-time
only -- depends on ultralytics/torch, which are never installed on the
Hub's runtime environment (or the Pi, in the earlier per-room design).
Run this once per model/resolution choice, commit the resulting .onnx
(or distribute it separately -- it's gitignored, see .gitignore).

Usage:
    python tools/export_pose_model.py --model yolo11s-pose --height 256 --width 320
"""
import argparse

from ultralytics import YOLO


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="yolo11s-pose", help="ultralytics model name, e.g. yolo11n-pose/yolo11s-pose")
    parser.add_argument("--height", type=int, default=256)
    parser.add_argument("--width", type=int, default=320)
    parser.add_argument("--opset", type=int, default=17)
    args = parser.parse_args()

    model = YOLO(f"{args.model}.pt")
    path = model.export(format="onnx", imgsz=(args.height, args.width), simplify=False, opset=args.opset)
    print(f"EXPORTED: {path}")


if __name__ == "__main__":
    main()
