import json
import sqlite3
import uuid
from dataclasses import dataclass

BASE_BACKOFF_SECONDS = 2.0
MAX_BACKOFF_SECONDS = 300.0


@dataclass(frozen=True)
class QueueItem:
    id: str
    payload: dict
    retry_count: int


class QueueStore:
    """SQLite-backed durable queue for outgoing event/health payloads.
    Survives a process restart or a network drop -- items are only
    removed on ack() (a confirmed 2xx delivery). The first enqueue of any
    item is always immediately pending (retry_count 0, next_retry_at =
    enqueue time) -- delivery is only ever delayed after a failed
    attempt, never on the happy path."""

    def __init__(self, db_path: str):
        self._conn = sqlite3.connect(db_path)
        self._conn.execute(
            """CREATE TABLE IF NOT EXISTS queue (
                id TEXT PRIMARY KEY, idempotency_key TEXT UNIQUE,
                payload TEXT, retry_count INTEGER DEFAULT 0,
                next_retry_at REAL
            )"""
        )
        self._conn.commit()

    def enqueue(self, payload: dict, idempotency_key: str | None = None, now: float = 0.0) -> str:
        if idempotency_key is not None:
            existing = self._conn.execute(
                "SELECT id FROM queue WHERE idempotency_key = ?", (idempotency_key,)
            ).fetchone()
            if existing:
                return existing[0]

        item_id = str(uuid.uuid4())
        self._conn.execute(
            "INSERT INTO queue (id, idempotency_key, payload, retry_count, next_retry_at) VALUES (?, ?, ?, 0, ?)",
            (item_id, idempotency_key, json.dumps(payload), now),
        )
        self._conn.commit()
        return item_id

    def pending(self, now: float) -> list[QueueItem]:
        rows = self._conn.execute(
            "SELECT id, payload, retry_count FROM queue WHERE next_retry_at <= ? ORDER BY next_retry_at",
            (now,),
        ).fetchall()
        return [QueueItem(id=r[0], payload=json.loads(r[1]), retry_count=r[2]) for r in rows]

    def ack(self, item_id: str) -> None:
        self._conn.execute("DELETE FROM queue WHERE id = ?", (item_id,))
        self._conn.commit()

    def nack(self, item_id: str, now: float) -> None:
        row = self._conn.execute("SELECT retry_count FROM queue WHERE id = ?", (item_id,)).fetchone()
        if row is None:
            return
        retry_count = row[0] + 1
        backoff = min(BASE_BACKOFF_SECONDS * (2 ** (retry_count - 1)), MAX_BACKOFF_SECONDS)
        self._conn.execute(
            "UPDATE queue SET retry_count = ?, next_retry_at = ? WHERE id = ?",
            (retry_count, now + backoff, item_id),
        )
        self._conn.commit()
