from dataclasses import dataclass

import numpy as np

from meridian_hub.vision.fast_ops import greedy_match_by_iou, iou_matrix
from meridian_hub.vision.pose_types import PersonDetection

MIN_IOU_TO_MATCH = 0.3


@dataclass(frozen=True)
class TrackedPerson:
    track_id: int
    detection: PersonDetection


class IouTracker:
    """Assigns a stable track_id per person within one camera by matching
    each new detection to the closest prior track by bounding-box IoU.
    Tolerates max_missed_frames of no matching detection (brief occlusion)
    before dropping a track -- PRD section 15.5.

    Matching is a single vectorized (tracks x detections) IoU matrix
    (meridian_hub.vision.fast_ops) resolved by global greedy assignment,
    not a per-track scan through every detection. This is also more
    correct than the original per-track-first-served approach: when two
    tracks are both near two close detections, resolving the single
    highest-IoU pair first (globally) is less prone to an identity swap
    than whichever track happened to iterate first grabbing its
    locally-best match."""

    def __init__(self, max_missed_frames: int = 5):
        self.max_missed_frames = max_missed_frames
        self._next_id = 1
        self._active: dict[int, PersonDetection] = {}
        self._missed: dict[int, int] = {}

    def update(self, detections: list[PersonDetection]) -> list[TrackedPerson]:
        track_ids = list(self._active.keys())
        priors = [self._active[tid] for tid in track_ids]

        results: list[TrackedPerson] = []
        matched_track_ids: set[int] = set()
        matched_detection_indices: set[int] = set()

        if track_ids and detections:
            prior_boxes = np.array([p.bbox for p in priors], dtype=np.float32)
            det_boxes = np.array([d.bbox for d in detections], dtype=np.float32)
            cost = iou_matrix(prior_boxes, det_boxes)
            for row, col in greedy_match_by_iou(cost, min_iou=MIN_IOU_TO_MATCH):
                track_id = track_ids[row]
                detection = detections[col]
                self._active[track_id] = detection
                self._missed[track_id] = 0
                matched_track_ids.add(track_id)
                matched_detection_indices.add(col)
                results.append(TrackedPerson(track_id=track_id, detection=detection))

        for track_id in track_ids:
            if track_id not in matched_track_ids:
                self._missed[track_id] = self._missed.get(track_id, 0) + 1
                if self._missed[track_id] > self.max_missed_frames:
                    del self._active[track_id]
                    del self._missed[track_id]

        for idx, det in enumerate(detections):
            if idx not in matched_detection_indices:
                track_id = self._next_id
                self._next_id += 1
                self._active[track_id] = det
                self._missed[track_id] = 0
                results.append(TrackedPerson(track_id=track_id, detection=det))

        return results
