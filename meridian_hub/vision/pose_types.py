from dataclasses import dataclass

# COCO-17 keypoint order, matching YOLO11-pose's output layout.
KEYPOINT_NAMES = [
    "nose", "left_eye", "right_eye", "left_ear", "right_ear",
    "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
    "left_wrist", "right_wrist", "left_hip", "right_hip",
    "left_knee", "right_knee", "left_ankle", "right_ankle",
]

BBox = tuple[float, float, float, float]  # x1, y1, x2, y2


@dataclass(frozen=True)
class Keypoint:
    x: float
    y: float
    confidence: float


@dataclass(frozen=True)
class PersonDetection:
    """One detected person in one frame -- pre-tracking. A frame with two
    people in it produces two of these."""

    keypoints: list[Keypoint]
    bbox: BBox
    confidence: float
    timestamp: float

    def get(self, name: str) -> Keypoint:
        return self.keypoints[KEYPOINT_NAMES.index(name)]

    def hip_center(self) -> tuple[float, float]:
        left = self.get("left_hip")
        right = self.get("right_hip")
        return (left.x + right.x) / 2.0, (left.y + right.y) / 2.0

    def shoulder_center(self) -> tuple[float, float]:
        left = self.get("left_shoulder")
        right = self.get("right_shoulder")
        return (left.x + right.x) / 2.0, (left.y + right.y) / 2.0

    def iou(self, other: "PersonDetection") -> float:
        ax1, ay1, ax2, ay2 = self.bbox
        bx1, by1, bx2, by2 = other.bbox
        ix1, iy1 = max(ax1, bx1), max(ay1, by1)
        ix2, iy2 = min(ax2, bx2), min(ay2, by2)
        iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
        intersection = iw * ih
        if intersection == 0.0:
            return 0.0
        area_a = (ax2 - ax1) * (ay2 - ay1)
        area_b = (bx2 - bx1) * (by2 - by1)
        union = area_a + area_b - intersection
        return intersection / union if union > 0 else 0.0
