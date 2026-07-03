import tempfile
from pathlib import Path

from meridian_hub.alerting.notification_dispatcher import HttpResponse, NotificationDispatcher
from meridian_hub.offline_queue.queue_store import QueueStore


def _queue():
    db_path = Path(tempfile.mkdtemp()) / "queue.sqlite3"
    return QueueStore(db_path=str(db_path))


class _RecordingPost:
    def __init__(self, status_code=200, fail_urls=None, raise_for=None):
        self.status_code = status_code
        self.calls = []
        self._raise_for = raise_for or set()

    def __call__(self, url, json_body, headers):
        self.calls.append((url, json_body, headers))
        if json_body.get("event_id") in self._raise_for:
            raise ConnectionError("simulated network drop")
        return HttpResponse(status_code=self.status_code, text="ok" if self.status_code < 300 else "rejected")


def test_delivers_pending_event_and_acks_on_2xx():
    queue = _queue()
    queue.enqueue({"event_id": "evt-1", "event_type": "fall_confirmed"}, idempotency_key="evt-1")
    post = _RecordingPost(status_code=200)
    dispatcher = NotificationDispatcher(queue, "https://backend/ingest-event", post_fn=post)

    results = dispatcher.dispatch_pending(now=0.0)
    assert len(results) == 1
    assert results[0].delivered is True
    assert post.calls[0][0] == "https://backend/ingest-event"
    assert post.calls[0][1]["event_id"] == "evt-1"
    # acked -> no longer pending
    assert queue.pending(now=0.0) == []


def test_failed_delivery_stays_queued_with_backoff():
    queue = _queue()
    queue.enqueue({"event_id": "evt-1"}, idempotency_key="evt-1")
    post = _RecordingPost(status_code=500)
    dispatcher = NotificationDispatcher(queue, "https://backend/ingest-event", post_fn=post)

    results = dispatcher.dispatch_pending(now=0.0)
    assert results[0].delivered is False
    assert results[0].status_code == 500
    # not immediately retryable, but reappears after backoff
    assert queue.pending(now=0.0) == []
    later = queue.pending(now=10.0)
    assert len(later) == 1
    assert later[0].retry_count == 1


def test_network_exception_is_isolated_and_requeues():
    queue = _queue()
    queue.enqueue({"event_id": "evt-good"}, idempotency_key="evt-good")
    queue.enqueue({"event_id": "evt-bad"}, idempotency_key="evt-bad")
    post = _RecordingPost(status_code=200, raise_for={"evt-bad"})
    dispatcher = NotificationDispatcher(queue, "https://backend/ingest-event", post_fn=post)

    results = dispatcher.dispatch_pending(now=0.0)
    by_id = {r.status_code: r for r in results}
    delivered = [r for r in results if r.delivered]
    failed = [r for r in results if not r.delivered]
    assert len(delivered) == 1  # the good one went through
    assert len(failed) == 1  # the bad one failed but didn't block the good one
    assert failed[0].error == "simulated network drop"


def test_auth_header_is_sent():
    queue = _queue()
    queue.enqueue({"event_id": "evt-1"}, idempotency_key="evt-1")
    post = _RecordingPost(status_code=200)
    dispatcher = NotificationDispatcher(
        queue, "https://backend/ingest-event", auth_header={"Authorization": "Bearer devicetoken"}, post_fn=post,
    )
    dispatcher.dispatch_pending(now=0.0)
    assert post.calls[0][2]["Authorization"] == "Bearer devicetoken"


def test_nothing_pending_is_a_noop():
    queue = _queue()
    post = _RecordingPost(status_code=200)
    dispatcher = NotificationDispatcher(queue, "https://backend/ingest-event", post_fn=post)
    assert dispatcher.dispatch_pending(now=0.0) == []
    assert post.calls == []
