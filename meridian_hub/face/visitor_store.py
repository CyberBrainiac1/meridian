import json
import math
import sqlite3
from dataclasses import dataclass

DEFAULT_MATCH_THRESHOLD = 0.5


@dataclass(frozen=True)
class MatchResult:
    person_id: str | None
    similarity: float


def _cosine_similarity(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return dot / (norm_a * norm_b)


class VisitorStore:
    """SQLite-backed enrolled-face store and visit log (design spec
    section 4.10 / PRD section 15.1-adjacent). Matches the PRD's
    'Supabase-backed' data shape (person_id/embedding/visit records) so
    swapping in a real SupabaseVisitorStore later is a config change, not
    a redesign. New/unmatched faces are NOT auto-enrolled here -- that's
    the pending-enrollment gate Codex's Supabase work implements; this
    class only records that an unknown face was seen, via log_visit with
    match_status='unknown'."""

    def __init__(self, db_path: str):
        self._conn = sqlite3.connect(db_path)
        self._conn.execute(
            "CREATE TABLE IF NOT EXISTS enrolled_faces (person_id TEXT PRIMARY KEY, embedding TEXT)"
        )
        self._conn.execute(
            """CREATE TABLE IF NOT EXISTS visitor_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT, camera_id TEXT,
                match_status TEXT, person_id TEXT, confidence REAL, timestamp REAL
            )"""
        )
        self._conn.commit()

    def enroll(self, person_id: str, embedding: list[float]) -> None:
        self._conn.execute(
            "INSERT INTO enrolled_faces (person_id, embedding) VALUES (?, ?) "
            "ON CONFLICT(person_id) DO UPDATE SET embedding=excluded.embedding",
            (person_id, json.dumps(embedding)),
        )
        self._conn.commit()

    def match(self, embedding: list[float], threshold: float = DEFAULT_MATCH_THRESHOLD) -> MatchResult:
        rows = self._conn.execute("SELECT person_id, embedding FROM enrolled_faces").fetchall()
        best_id, best_sim = None, -1.0
        for person_id, embedding_json in rows:
            similarity = _cosine_similarity(embedding, json.loads(embedding_json))
            if similarity > best_sim:
                best_id, best_sim = person_id, similarity

        if best_sim >= threshold:
            return MatchResult(person_id=best_id, similarity=best_sim)
        return MatchResult(person_id=None, similarity=max(best_sim, 0.0))

    def log_visit(self, camera_id: str, match_status: str, person_id: str | None, confidence: float, timestamp: float) -> None:
        self._conn.execute(
            "INSERT INTO visitor_log (camera_id, match_status, person_id, confidence, timestamp) VALUES (?, ?, ?, ?, ?)",
            (camera_id, match_status, person_id, confidence, timestamp),
        )
        self._conn.commit()

    def recent_visits(self, camera_id: str, since_timestamp: float) -> list[dict]:
        rows = self._conn.execute(
            "SELECT camera_id, match_status, person_id, confidence, timestamp FROM visitor_log "
            "WHERE camera_id = ? AND timestamp >= ? ORDER BY timestamp",
            (camera_id, since_timestamp),
        ).fetchall()
        return [
            {"camera_id": r[0], "match_status": r[1], "person_id": r[2], "confidence": r[3], "timestamp": r[4]}
            for r in rows
        ]
