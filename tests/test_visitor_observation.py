from datetime import datetime, timezone
import os

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


def test_image_is_optional_and_absent_by_default():
    encryptor = EmbeddingEncryptor(key=os.urandom(32), key_id="key-1")
    encrypted = encryptor.encrypt([0.1])
    observation = build_visitor_observation(
        facility_id="fac-1", camera_id="cam-1", source_event_id="evt-1",
        detected_at=datetime(2026, 7, 2, 14, 0, 0, tzinfo=timezone.utc),
        match_status="unknown", quality_score=0.5, match_confidence=None,
        encrypted=encrypted,
    )
    assert observation.face_image_ciphertext is None


def test_encrypted_image_included_when_provided_never_carries_plaintext():
    encryptor = EmbeddingEncryptor(key=os.urandom(32), key_id="key-1")
    encrypted_embedding = encryptor.encrypt([0.1])
    fake_jpeg = b"\xff\xd8\xff\xe0-recognizable-marker-bytes-\xff\xd9"
    encrypted_image = encryptor.encrypt_image(fake_jpeg)

    observation = build_visitor_observation(
        facility_id="fac-1", camera_id="cam-entry-1", source_event_id="evt-with-photo",
        detected_at=datetime(2026, 7, 2, 14, 0, 0, tzinfo=timezone.utc),
        match_status="unknown", quality_score=0.9, match_confidence=None,
        encrypted=encrypted_embedding, encrypted_image=encrypted_image,
    )

    payload = observation.model_dump(mode="json")
    assert payload["face_image_ciphertext"] == encrypted_image.ciphertext
    assert payload["face_image_digest"] == encrypted_image.digest
    assert payload["face_image_content_type"] == "image/jpeg"
    assert payload["face_image_size_bytes"] == len(fake_jpeg)
    assert b"recognizable-marker-bytes" not in str(payload).encode("utf-8", errors="ignore")


def test_body_description_and_encrypted_person_photo_are_included():
    encryptor = EmbeddingEncryptor(key=os.urandom(32), key_id="key-1")
    encrypted_embedding = encryptor.encrypt([0.1])
    fake_body_photo = b"\xff\xd8full-body-photo-marker\xff\xd9"
    encrypted_person_photo = encryptor.encrypt_image(fake_body_photo)
    generated_at = datetime(2026, 7, 2, 14, 1, 0, tzinfo=timezone.utc)

    observation = build_visitor_observation(
        facility_id="fac-1", camera_id="cam-entry-1", source_event_id="evt-body-photo",
        detected_at=datetime(2026, 7, 2, 14, 0, 0, tzinfo=timezone.utc),
        match_status="unknown", quality_score=0.9, match_confidence=None,
        encrypted=encrypted_embedding,
        body_description="wearing a red jacket and carrying a black backpack",
        body_description_model="google/gemini-2.5-flash",
        body_description_generated_at=generated_at,
        encrypted_person_photo=encrypted_person_photo,
    )

    payload = observation.model_dump(mode="json")
    assert payload["body_description"] == "wearing a red jacket and carrying a black backpack"
    assert payload["body_description_model"] == "google/gemini-2.5-flash"
    assert payload["body_description_generated_at"] == "2026-07-02T14:01:00Z"
    assert payload["person_photo_ciphertext"] == encrypted_person_photo.ciphertext
    assert payload["person_photo_sha256"] == encrypted_person_photo.digest
    assert payload["person_photo_key_id"] == "key-1"
    assert b"full-body-photo-marker" not in str(payload).encode("utf-8", errors="ignore")
