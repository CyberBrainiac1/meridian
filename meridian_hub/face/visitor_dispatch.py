"""Queue unknown-visitor observations for the resident verification flow."""

from meridian_hub.face.visitor_observation import VisitorFaceObservation
from meridian_hub.ingestion.hub_delivery import HubDeliveryQueue


class UnknownVisitorReporter:
    """The final dependency-injected hop after encryption and matching.

    Only unrecognized visitors create resident verification prompts.  The
    backend trigger attached to ingest-visitor-face owns prompt creation,
    expiry, RLS, and care-team escalation; this class owns reliable delivery
    to that trigger path and intentionally never decrypts or inspects media.
    """

    def __init__(self, delivery_queue: HubDeliveryQueue):
        self._delivery_queue = delivery_queue

    def report(self, observation: VisitorFaceObservation, *, now: float = 0.0) -> str | None:
        if observation.match_status not in ("unknown", "new_visitor"):
            return None
        return self._delivery_queue.enqueue_visitor_observation(observation, now=now)
