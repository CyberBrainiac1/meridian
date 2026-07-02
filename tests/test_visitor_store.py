import tempfile
from pathlib import Path

from meridian_hub.face.visitor_store import VisitorStore


def _store():
    db_path = Path(tempfile.mkdtemp()) / "visitors.sqlite3"
    return VisitorStore(db_path=str(db_path))


def test_match_against_identical_embedding_is_a_perfect_match():
    store = _store()
    embedding = [1.0, 0.0, 0.0]
    store.enroll("res-1", embedding)
    result = store.match(embedding, threshold=0.5)
    assert result.person_id == "res-1"
    assert result.similarity > 0.99


def test_match_against_orthogonal_embedding_is_unknown():
    store = _store()
    store.enroll("res-1", [1.0, 0.0, 0.0])
    result = store.match([0.0, 1.0, 0.0], threshold=0.5)
    assert result.person_id is None


def test_match_with_no_enrolled_faces_is_unknown():
    store = _store()
    result = store.match([1.0, 0.0, 0.0], threshold=0.5)
    assert result.person_id is None
    assert result.similarity == 0.0


def test_enroll_upserts_existing_person():
    store = _store()
    store.enroll("res-1", [1.0, 0.0, 0.0])
    store.enroll("res-1", [0.0, 1.0, 0.0])
    result = store.match([0.0, 1.0, 0.0], threshold=0.5)
    assert result.person_id == "res-1"


def test_log_visit_and_query_recent():
    store = _store()
    store.log_visit(camera_id="cam-entry-1", match_status="known", person_id="res-1", confidence=0.9, timestamp=100.0)
    store.log_visit(camera_id="cam-entry-1", match_status="unknown", person_id=None, confidence=0.3, timestamp=200.0)
    store.log_visit(camera_id="cam-entry-2", match_status="known", person_id="res-2", confidence=0.8, timestamp=150.0)

    visits = store.recent_visits("cam-entry-1", since_timestamp=0.0)
    assert len(visits) == 2
    assert visits[0]["match_status"] == "known"
    assert visits[1]["match_status"] == "unknown"


def test_recent_visits_respects_since_timestamp():
    store = _store()
    store.log_visit(camera_id="cam-1", match_status="known", person_id="res-1", confidence=0.9, timestamp=100.0)
    store.log_visit(camera_id="cam-1", match_status="known", person_id="res-1", confidence=0.9, timestamp=500.0)
    visits = store.recent_visits("cam-1", since_timestamp=300.0)
    assert len(visits) == 1
    assert visits[0]["timestamp"] == 500.0
