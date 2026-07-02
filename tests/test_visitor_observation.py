import os
from datetime import datetime, timezone

from meridian_hub.face.embedding_encryption import EmbeddingEncryptor
from meridian_hub.face.visitor_observation import build_visitor_observation


def test_build_observation_never_carries_plaintext_embedding():
    encryptor = EmbeddingEncryptor(key=os.urandom(32), key_id="key-1")
    embedding = [0.111, 0.222, 0.333]
    encrypted = encryptor.encrypt(embedding)

    observation = build_visitor_observation(
        facility_id="fac-1", camera_id="cam-entry-1", source_event_id="evt-abc",
        detected_at=datetime(2026, 7, 2, 14, 0, 0, tzinfo=timezone.utc),
        match_status="unknown", quality_score=0.82, match_confidence=None,
        encrypted=encrypted,
    )

    payload = observation.model_dump(mode="json")
    assert payload["face_embedding_ciphertext"] == encrypted.ciphertext
    assert payload["face_embedding_digest"] == encrypted.digest
    assert payload["face_embedding_key_id"] == "key-1"
    assert payload["face_embedding_dimensions"] == 3
    assert payload["face_embedding_model"] == "buffalo_s/arcface"
    serialized = str(payload)
    assert "0.111" not in serialized
    assert "0.222" not in serialized


def test_known_match_includes_confidence():
    encryptor = EmbeddingEncryptor(key=os.urandom(32), key_id="key-1")
    encrypted = encryptor.encrypt([0.5, 0.5])
    observation = build_visitor_observation(
        facility_id="fac-1", camera_id="cam-entry-1", source_event_id="evt-xyz",
        detected_at=datetime(2026, 7, 2, 14, 0, 0, tzinfo=timezone.utc),
        match_status="known", quality_score=0.9, match_confidence=0.87,
        encrypted=encrypted,
    )
    assert observation.match_status == "known"
    assert observation.match_confidence == 0.87


def test_observation_contract_fields_match_codex_ingest_endpoint():
    encryptor = EmbeddingEncryptor(key=os.urandom(32), key_id="key-1")
    encrypted = encryptor.encrypt([0.1])
    observation = build_visitor_observation(
        facility_id="fac-1", camera_id="cam-1", source_event_id="evt-1",
        detected_at=datetime(2026, 7, 2, 14, 0, 0, tzinfo=timezone.utc),
        match_status="unknown", quality_score=0.5, match_confidence=None,
        encrypted=encrypted,
    )
    payload = observation.model_dump(mode="json")
    for field in [
        "facility_id", "camera_id", "source_event_id", "detected_at",
        "face_embedding_ciphertext", "face_embedding_digest", "face_embedding_key_id",
        "face_embedding_nonce", "face_embedding_algorithm", "face_embedding_model",
        "face_embedding_dimensions",
    ]:
        assert field in payload
