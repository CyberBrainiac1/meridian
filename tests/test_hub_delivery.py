from datetime import datetime, timezone
import os

from meridian_hub.alerting.notification_dispatcher import HttpResponse, NotificationDispatcher
from meridian_hub.events.schemas import MeridianEvent
from meridian_hub.face.embedding_encryption import EmbeddingEncryptor
from meridian_hub.face.visitor_dispatch import UnknownVisitorReporter
from meridian_hub.face.visitor_observation import build_visitor_observation
from meridian_hub.ingestion.hub_delivery import (
    DELIVERY_ENVELOPE_KEY,
    HubDeliveryQueue,
    INCIDENT_DESTINATION,
    VISITOR_OBSERVATION_DESTINATION,
)
from meridian_hub.offline_queue.queue_store import QueueStore


class _Post:
    def __init__(self):
        self.calls = []

    def __call__(self, url, json_body, headers):
        self.calls.append((url, json_body, headers))
        return HttpResponse(status_code=201, text="created")


def _event() -> MeridianEvent:
    timestamp = datetime(2026, 8, 7, 12, 0, tzinfo=timezone.utc)
    return MeridianEvent(
        event_id="fall-1", facility_id="fac-1", building_id="building-1",
        floor_id="floor-1", room_id="room-101", resident_id="resident-1",
        camera_id="camera-101", event_type="fall_confirmed", severity="critical",
        confidence=0.9, detected_at=timestamp, generated_at=timestamp,
        reason_codes=["rapid_vertical_drop"],
    )


def _unknown_observation():
    encrypted = EmbeddingEncryptor(key=os.urandom(32), key_id="building-key").encrypt([0.1, 0.2])
    return build_visitor_observation(
        facility_id="fac-1", camera_id="entry-1", source_event_id="visitor-1",
        detected_at=datetime(2026, 8, 7, 12, 0, tzinfo=timezone.utc),
        match_status="unknown", quality_score=0.91, match_confidence=None,
        encrypted=encrypted, body_description="wearing a navy jacket",
    )


def test_confirmed_fall_is_queued_for_the_real_incident_ingest_endpoint():
    store = QueueStore(":memory:")
    delivery = HubDeliveryQueue(store)
    delivery.enqueue_incident(_event(), now=5.0)

    queued = store.pending(now=5.0)
    assert len(queued) == 1
    envelope = queued[0].payload[DELIVERY_ENVELOPE_KEY]
    assert envelope["destination"] == INCIDENT_DESTINATION
    assert envelope["payload"]["event_type"] == "fall_confirmed"


def test_unknown_visitor_is_queued_for_visitor_ingest_without_plaintext_embedding():
    store = QueueStore(":memory:")
    reporter = UnknownVisitorReporter(HubDeliveryQueue(store))
    observation = _unknown_observation()

    assert reporter.report(observation, now=5.0) is not None
    queued = store.pending(now=5.0)
    envelope = queued[0].payload[DELIVERY_ENVELOPE_KEY]
    assert envelope["destination"] == VISITOR_OBSERVATION_DESTINATION
    assert envelope["payload"]["body_description"] == "wearing a navy jacket"
    assert "0.1" not in str(envelope["payload"])


def test_known_visitor_is_not_sent_to_the_resident_verification_trigger():
    store = QueueStore(":memory:")
    reporter = UnknownVisitorReporter(HubDeliveryQueue(store))
    observation = _unknown_observation().model_copy(update={"match_status": "known"})

    assert reporter.report(observation) is None
    assert store.pending(now=0.0) == []


def test_dispatcher_routes_envelopes_and_only_acks_after_backend_success():
    store = QueueStore(":memory:")
    delivery = HubDeliveryQueue(store)
    delivery.enqueue_incident(_event())
    reporter = UnknownVisitorReporter(delivery)
    reporter.report(_unknown_observation())
    post = _Post()
    dispatcher = NotificationDispatcher(
        store,
        "https://backend/functions/v1/ingest-event",
        delivery_urls={
            INCIDENT_DESTINATION: "https://backend/functions/v1/ingest-event",
            VISITOR_OBSERVATION_DESTINATION: "https://backend/functions/v1/ingest-visitor-face",
        },
        post_fn=post,
    )

    results = dispatcher.dispatch_pending(now=0.0)
    assert [result.delivered for result in results] == [True, True]
    assert [call[0] for call in post.calls] == [
        "https://backend/functions/v1/ingest-event",
        "https://backend/functions/v1/ingest-visitor-face",
    ]
    assert store.pending(now=0.0) == []
