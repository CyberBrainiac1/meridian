import logging
from collections.abc import Callable, Mapping
from dataclasses import dataclass

from meridian_hub.offline_queue.queue_store import QueueStore
from meridian_hub.ingestion.hub_delivery import unwrap_delivery

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class DeliveryResult:
    item_id: str
    delivered: bool
    status_code: int | None
    error: str | None


class NotificationDispatcher:
    """Drains the offline queue and delivers each alert event to the
    backend's ingest endpoint over HTTP. The backend (Codex's
    notify-family Edge Function + realtime views) is what actually pushes
    the notification to the caregiver/family/resident apps -- the Hub's
    job ends at handing the event to the backend, which is exactly the
    Pranav/Dhairya integration boundary in the PRD (section 16.2).

    This replaces SMS as the alert-delivery mechanism: instead of texting
    a phone directly, the Hub delivers the event to the platform and the
    apps receive an in-app push. It's strictly offline-first -- items
    stay in the durable queue until a 2xx confirms delivery, so a WiFi
    drop delays notifications but never loses them (PRD section 8.10).

    post_fn is injectable so tests never touch the network. In
    production it's a thin requests.post wrapper; the default builds one
    lazily so importing this module doesn't require requests at all until
    a real dispatch happens."""

    def __init__(
        self, queue_store: QueueStore, ingest_url: str,
        auth_header: dict[str, str] | None = None,
        post_fn: Callable[[str, dict, dict], "HttpResponse"] | None = None,
        timeout_seconds: float = 5.0,
        delivery_urls: Mapping[str, str] | None = None,
    ):
        self._queue = queue_store
        self._ingest_url = ingest_url
        self._auth_header = auth_header or {}
        self._timeout = timeout_seconds
        self._post_fn = post_fn or self._default_post_fn
        self._delivery_urls = dict(delivery_urls or {})

    def _default_post_fn(self, url: str, json_body: dict, headers: dict):
        import requests
        resp = requests.post(url, json=json_body, headers=headers, timeout=self._timeout)
        return HttpResponse(status_code=resp.status_code, text=resp.text)

    def dispatch_pending(self, now: float) -> list[DeliveryResult]:
        """Attempt delivery of every currently-due queue item. Called on
        a timer by the Hub run loop. Each item is independent: one bad
        payload or a transient failure on one never blocks the rest."""
        results: list[DeliveryResult] = []
        for item in self._queue.pending(now=now):
            try:
                destination, body = unwrap_delivery(item.payload)
                # ingest-event was the queue's only destination before
                # MeridianHub. Keep that established route as the default so
                # durable records written by older Hub builds still drain.
                url = self._delivery_urls.get(destination, self._ingest_url) if destination else self._ingest_url
                if destination and destination not in self._delivery_urls and destination != "ingest-event":
                    raise ValueError(f"delivery_destination_not_configured:{destination}")
                resp = self._post_fn(url, body, dict(self._auth_header))
            except Exception as e:
                logger.warning("Notification delivery failed for %s: %s", item.id, e)
                self._queue.nack(item.id, now=now)
                results.append(DeliveryResult(item.id, delivered=False, status_code=None, error=str(e)))
                continue

            if 200 <= resp.status_code < 300:
                self._queue.ack(item.id)
                results.append(DeliveryResult(item.id, delivered=True, status_code=resp.status_code, error=None))
            else:
                logger.warning("Backend rejected notification %s with %d: %s", item.id, resp.status_code, resp.text)
                self._queue.nack(item.id, now=now)
                results.append(DeliveryResult(item.id, delivered=False, status_code=resp.status_code, error=resp.text))
        return results


@dataclass(frozen=True)
class HttpResponse:
    status_code: int
    text: str
