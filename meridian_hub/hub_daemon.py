from datetime import datetime, timezone

import numpy as np

from meridian_hub.capture.camera_registry import CameraRegistry
from meridian_hub.classifiers.fall_state_machine import FallStateMachine
from meridian_hub.classifiers.fall_types import FallState
from meridian_hub.events.event_engine import EventEngine
from meridian_hub.events.schemas import MeridianEvent
from meridian_hub.features.feature_window import TrackFeatureManager
from meridian_hub.offline_queue.queue_store import QueueStore
from meridian_hub.validation.local_validator import LocalHeuristicValidator, ValidationOutcome
from meridian_hub.vision.preprocessing import preprocess_frame
from meridian_hub.vision.tracker import IouTracker

CONFIRMED_REASON_CODES = ["rapid_vertical_drop", "horizontal_torso", "remained_near_floor"]


class HubDaemon:
    """Wires capture -> preprocess -> pose -> tracking -> features ->
    fall detection -> local validation -> event engine -> offline queue
    for one Hub instance covering possibly-multiple cameras.
    process_frame() is one synchronous tick for one camera's one raw
    frame -- this is the fully testable core. The real capture loop
    (pulling frames from actual cameras via the inference scheduler)
    calls this repeatedly and is verified manually against a real webcam,
    not via pytest, since it requires a real camera or model file to be
    meaningful."""

    def __init__(
        self, pose_estimator, event_engine: EventEngine, queue_store: QueueStore,
        camera_registry: CameraRegistry,
    ):
        self._pose_estimator = pose_estimator
        self._event_engine = event_engine
        self._queue_store = queue_store
        self._camera_registry = camera_registry
        self._validator = LocalHeuristicValidator()
        self._trackers: dict[str, IouTracker] = {}
        self._feature_managers: dict[str, TrackFeatureManager] = {}
        self._fall_machines: dict[tuple[str, int], FallStateMachine] = {}

    def process_frame(self, camera_id: str, frame: np.ndarray, timestamp: float) -> list[MeridianEvent]:
        preprocessed = preprocess_frame(
            frame, self._pose_estimator.input_height, self._pose_estimator.input_width
        )
        detections = self._pose_estimator.estimate(preprocessed, timestamp)

        tracker = self._trackers.setdefault(camera_id, IouTracker())
        tracked = tracker.update(detections)

        feature_manager = self._feature_managers.setdefault(camera_id, TrackFeatureManager())
        feature_manager.prune({t.track_id for t in tracked})

        camera_record = self._camera_registry.get(camera_id)
        events: list[MeridianEvent] = []

        for person in tracked:
            feature_manager.update(person.track_id, person.detection)
            features = feature_manager.compute(person.track_id)

            key = (camera_id, person.track_id)
            machine = self._fall_machines.setdefault(key, FallStateMachine(track_id=person.track_id))
            fall_event = machine.update(features, timestamp)
            if fall_event is None:
                continue

            if fall_event.state == FallState.CONFIRMED:
                event = self._emit(camera_record, camera_id, person.track_id, "fall_confirmed", "critical", 0.9, timestamp, CONFIRMED_REASON_CODES)
            elif fall_event.state == FallState.SUSPECTED:
                event = self._resolve_suspected(camera_record, camera_id, person.track_id, features, timestamp)
            elif fall_event.state == FallState.CLEARED:
                self._event_engine.resolve(camera_id=camera_id, track_id=person.track_id, event_type="fall_confirmed")
                self._event_engine.resolve(camera_id=camera_id, track_id=person.track_id, event_type="fall_suspected")
                event = None
            else:
                event = None

            if event is not None:
                events.append(event)
                self._queue_store.enqueue(payload=event.model_dump(mode="json"), idempotency_key=event.event_id)

        return events

    def _resolve_suspected(self, camera_record, camera_id, track_id, features, timestamp):
        # Fail-open policy lives here, not in the validator itself (design
        # spec section 2.1): INCONCLUSIVE still becomes an alert, just a
        # lower-confidence one, because a missed validation must never
        # suppress a real alert.
        result = self._validator.validate(features)
        if result.outcome == ValidationOutcome.FALSE_POSITIVE_SITTING:
            return None
        if result.outcome == ValidationOutcome.FALL_CONFIRMED:
            return self._emit(camera_record, camera_id, track_id, "fall_confirmed", "critical", result.confidence, timestamp, [result.rationale])
        return self._emit(camera_record, camera_id, track_id, "fall_suspected", "warning", result.confidence, timestamp, [result.rationale])

    def _emit(self, camera_record, camera_id, track_id, event_type, severity, confidence, timestamp, reason_codes):
        detected_at = datetime.fromtimestamp(timestamp, tz=timezone.utc)
        return self._event_engine.emit_fall_event(
            camera_id=camera_id, track_id=track_id,
            facility_id=camera_record.facility_id if camera_record else "unknown",
            building_id=camera_record.building_id if camera_record else "unknown",
            floor_id=camera_record.floor_id if camera_record else "unknown",
            room_id=camera_record.room_id if camera_record else "unknown",
            resident_id=camera_record.resident_id if camera_record else None,
            event_type=event_type, severity=severity, confidence=confidence,
            detected_at=detected_at, reason_codes=reason_codes,
        )
