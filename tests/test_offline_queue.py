import tempfile
from pathlib import Path

from meridian_hub.offline_queue.queue_store import QueueStore


def _store():
    db_path = Path(tempfile.mkdtemp()) / "queue.sqlite3"
    return QueueStore(db_path=str(db_path))


def test_enqueue_then_pending_returns_item_immediately():
    store = _store()
    item_id = store.enqueue(payload={"event_id": "evt-1", "kind": "fall_confirmed"})
    pending = store.pending(now=0.0)
    assert len(pending) == 1
    assert pending[0].id == item_id
    assert pending[0].payload["event_id"] == "evt-1"


def test_ack_removes_item():
    store = _store()
    item_id = store.enqueue(payload={"event_id": "evt-1"})
    store.ack(item_id)
    assert store.pending(now=0.0) == []


def test_nack_schedules_retry_with_backoff_not_immediate_requeue():
    store = _store()
    item_id = store.enqueue(payload={"event_id": "evt-1"})
    store.nack(item_id, now=0.0)
    assert store.pending(now=0.0) == []  # not immediately retryable
    later = store.pending(now=5.0)
    assert len(later) == 1
    assert later[0].retry_count == 1


def test_idempotency_key_prevents_duplicate_enqueue():
    store = _store()
    first_id = store.enqueue(payload={"event_id": "evt-1"}, idempotency_key="evt-1")
    second_id = store.enqueue(payload={"event_id": "evt-1"}, idempotency_key="evt-1")
    assert first_id == second_id
    assert len(store.pending(now=0.0)) == 1
