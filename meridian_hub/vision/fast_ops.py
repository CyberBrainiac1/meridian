"""Vectorized numpy implementations of the hot-path geometry operations
(IoU matrix, greedy NMS) used by pose decoding and tracking every frame,
for every person, on every camera. Rewritten from Python-level nested
loops over dataclass objects to raw array broadcasting -- the kind of
code where a constant-factor speedup compounds once you're running
multiple cameras through a shared scheduler."""
import numpy as np


def iou_matrix(boxes_a: np.ndarray, boxes_b: np.ndarray) -> np.ndarray:
    """boxes_a: (N,4) x1y1x2y2, boxes_b: (M,4) x1y1x2y2 -> (N,M) IoU
    matrix. Fully vectorized via broadcasting -- computes every pairwise
    IoU in one shot instead of N*M individual Python-level comparisons."""
    if boxes_a.shape[0] == 0 or boxes_b.shape[0] == 0:
        return np.zeros((boxes_a.shape[0], boxes_b.shape[0]), dtype=np.float32)

    a = boxes_a[:, None, :]  # (N,1,4)
    b = boxes_b[None, :, :]  # (1,M,4)

    ix1 = np.maximum(a[..., 0], b[..., 0])
    iy1 = np.maximum(a[..., 1], b[..., 1])
    ix2 = np.minimum(a[..., 2], b[..., 2])
    iy2 = np.minimum(a[..., 3], b[..., 3])

    iw = np.clip(ix2 - ix1, 0, None)
    ih = np.clip(iy2 - iy1, 0, None)
    intersection = iw * ih

    area_a = (a[..., 2] - a[..., 0]) * (a[..., 3] - a[..., 1])
    area_b = (b[..., 2] - b[..., 0]) * (b[..., 3] - b[..., 1])
    union = area_a + area_b - intersection

    return np.where(union > 0, intersection / union, 0.0).astype(np.float32)


def greedy_nms(boxes: np.ndarray, scores: np.ndarray, iou_threshold: float) -> list[int]:
    """Standard greedy NMS: returns indices to keep, highest-score-first
    order broken by suppressing anything that overlaps an already-kept
    box beyond iou_threshold. The outer while-loop is inherent to greedy
    NMS (each decision depends on prior keeps), but every per-step IoU
    computation against the remaining candidates is one vectorized call
    instead of a Python-level inner loop."""
    if boxes.shape[0] == 0:
        return []
    order = np.argsort(-scores)
    keep: list[int] = []
    while order.size > 0:
        i = order[0]
        keep.append(int(i))
        if order.size == 1:
            break
        rest = order[1:]
        ious = iou_matrix(boxes[i:i + 1], boxes[rest])[0]
        order = rest[ious < iou_threshold]
    return keep


def greedy_match_by_iou(cost_matrix: np.ndarray, min_iou: float) -> list[tuple[int, int]]:
    """Given an (N,M) IoU matrix (N prior tracks x M new detections),
    greedily pairs the globally-highest-remaining IoU first, repeating
    until nothing left clears min_iou. Returns (row, col) index pairs.
    This replaces a Python loop that, for each track, scanned every
    detection to find its best match -- O(N*M) Python-level comparisons
    either way, but this version does the scan as one vectorized argmax
    per iteration instead of a nested for-loop with per-pair function calls."""
    if cost_matrix.size == 0:
        return []
    matrix = cost_matrix.copy()
    matches: list[tuple[int, int]] = []
    while True:
        best_iou = matrix.max()
        if best_iou < min_iou:
            break
        row, col = np.unravel_index(np.argmax(matrix), matrix.shape)
        matches.append((int(row), int(col)))
        matrix[row, :] = -1.0
        matrix[:, col] = -1.0
    return matches
