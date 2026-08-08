"""Typed, offline-first delivery routes for Hub-originated backend writes.

The SQLite queue remains the only durable transport.  This module adds the
small amount of routing the Hub needs now that it emits two real backend
objects: incident events and encrypted unknown-visitor observations.  Queue
records retain their destination as well as their payload, so a retry cannot
accidentally send a visitor observation to the incident endpoint.
"""

from collections.abc import Mapping
from typing import Any

from meridian_hub.events.schemas import MeridianEvent
from meridian_hub.activity_rollup import ResidentActivityRollup
from meridian_hub.face.visitor_observation import VisitorFaceObservation
from meridian_hub.offline_queue.queue_store import QueueStore

DELIVERY_ENVELOPE_KEY = "_meridian_delivery"
INCIDENT_DESTINATION = "ingest-event"
VISITOR_OBSERVATION_DESTINATION = "ingest-visitor-face"
RESIDENT_ACTIVITY_ROLLUP_DESTINATION = "record-resident-activity-rollup"


class HubDeliveryQueue:
    """Queues typed Hub writes with stable, endpoint-specific idempotency.

    QueueStore is deliberately injected so this remains deterministic in unit
    tests and survives network/device restarts in production.
    """

    def __init__(self, queue_store: QueueStore):
        self._queue = queue_store

    def enqueue_incident(self, event: MeridianEvent, *, now: float = 0.0) -> str:
        return self._enqueue(
            destination=INCIDENT_DESTINATION,
            payload=event.model_dump(mode="json"),
            idempotency_key=event.event_id,
            now=now,
        )

    def enqueue_visitor_observation(
        self, observation: VisitorFaceObservation, *, now: float = 0.0
    ) -> str:
        return self._enqueue(
            destination=VISITOR_OBSERVATION_DESTINATION,
            payload=observation.model_dump(mode="json"),
            idempotency_key=observation.source_event_id,
            now=now,
        )

    def enqueue_resident_activity_rollup(
        self, rollup: ResidentActivityRollup, *, now: float = 0.0
    ) -> str:
        """Queues the category-only daily summary for the authenticated Hub RPC."""

        return self._enqueue(
            destination=RESIDENT_ACTIVITY_ROLLUP_DESTINATION,
            payload=rollup.delivery_payload(),
            idempotency_key=f"activity:{rollup.resident_id}:{rollup.rollup_date.isoformat()}",
            now=now,
        )

    def _enqueue(
        self, *, destination: str, payload: Mapping[str, Any], idempotency_key: str, now: float
    ) -> str:
        return self._queue.enqueue(
            {
                DELIVERY_ENVELOPE_KEY: {
                    "destination": destination,
                    "payload": dict(payload),
                }
            },
            idempotency_key=idempotency_key,
            now=now,
        )


def unwrap_delivery(payload: dict[str, Any]) -> tuple[str | None, dict[str, Any]]:
    """Returns a queued destination/body pair without exposing envelope data.

    Existing raw queue records remain supported for safe incremental rollout;
    they return ``(None, payload)`` and use NotificationDispatcher's original
    ingest URL.
    """

    envelope = payload.get(DELIVERY_ENVELOPE_KEY)
    if not isinstance(envelope, dict):
        return None, payload
    destination = envelope.get("destination")
    body = envelope.get("payload")
    if not isinstance(destination, str) or not isinstance(body, dict):
        raise ValueError("invalid_delivery_envelope")
    return destination, body
