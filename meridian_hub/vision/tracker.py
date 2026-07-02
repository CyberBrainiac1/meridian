from dataclasses import dataclass

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
    before dropping a track -- PRD section 15.5."""

    def __init__(self, max_missed_frames: int = 5):
        self.max_missed_frames = max_missed_frames
        self._next_id = 1
        self._active: dict[int, PersonDetection] = {}
        self._missed: dict[int, int] = {}

    def update(self, detections: list[PersonDetection]) -> list[TrackedPerson]:
        unmatched_detections = list(detections)
        matched_track_ids: set[int] = set()
        results: list[TrackedPerson] = []

        for track_id, prior in list(self._active.items()):
            best_match, best_iou = None, 0.0
            for det in unmatched_detections:
                iou = prior.iou(det)
                if iou > best_iou:
                    best_match, best_iou = det, iou
            if best_match is not None and best_iou >= MIN_IOU_TO_MATCH:
                self._active[track_id] = best_match
                self._missed[track_id] = 0
                unmatched_detections.remove(best_match)
                matched_track_ids.add(track_id)
                results.append(TrackedPerson(track_id=track_id, detection=best_match))

        for track_id in list(self._active.keys()):
            if track_id not in matched_track_ids:
                self._missed[track_id] = self._missed.get(track_id, 0) + 1
                if self._missed[track_id] > self.max_missed_frames:
                    del self._active[track_id]
                    del self._missed[track_id]

        for det in unmatched_detections:
            track_id = self._next_id
            self._next_id += 1
            self._active[track_id] = det
            self._missed[track_id] = 0
            results.append(TrackedPerson(track_id=track_id, detection=det))

        return results
