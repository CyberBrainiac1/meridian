from datetime import datetime
from typing import Literal

from pydantic import BaseModel

from meridian_hub.face.embedding_encryption import EncryptedEmbedding, EncryptedImage


class VisitorFaceObservation(BaseModel):
    """Matches Codex's live ingest-visitor-face Supabase contract
    field-for-field (codex.md, "Task handoff: encrypted visitor-face
    observation storage" -- field names are prefixed face_embedding_*/
    face_image_* per Codex's finalized Edge Function). No enrollment/
    approval workflow -- this is a plain observation record. Nothing
    under face_embedding_*/face_image_* is ever plaintext; this schema
    has no field for either, so it's structurally impossible to send one
    by accident.

    face_image_* is optional (a quality-gated snapshot may not always be
    worth sending), but when present it's what lets a caregiver/admin/
    resident later attach a real name to this observation from the app --
    source_event_id is the stable key the app uses to find and update the
    record. The Hub never assigns or receives a name itself; naming is
    entirely an app/Supabase-side action taken after the fact."""

    facility_id: str
    camera_id: str
    source_event_id: str
    detected_at: datetime
    match_status: Literal["known", "unknown"]
    quality_score: float
    match_confidence: float | None = None

    face_embedding_ciphertext: str
    face_embedding_digest: str
    face_embedding_key_id: str
    face_embedding_nonce: str
    face_embedding_algorithm: str
    face_embedding_model: str
    face_embedding_dimensions: int

    face_image_ciphertext: str | None = None
    face_image_digest: str | None = None
    face_image_key_id: str | None = None
    face_image_nonce: str | None = None
    face_image_algorithm: str | None = None
    face_image_content_type: str | None = None
    face_image_size_bytes: int | None = None

    body_description: str | None = None
    body_description_model: str | None = None
    body_description_generated_at: datetime | None = None

    person_photo_ciphertext: str | None = None
    person_photo_sha256: str | None = None
    person_photo_key_id: str | None = None
    person_photo_nonce: str | None = None
    person_photo_algorithm: str | None = None
    person_photo_content_type: str | None = None
    person_photo_size_bytes: int | None = None


def build_visitor_observation(
    *, facility_id: str, camera_id: str, source_event_id: str, detected_at: datetime,
    match_status: str, quality_score: float, match_confidence: float | None,
    encrypted: EncryptedEmbedding, embedding_model: str = "buffalo_s/arcface",
    encrypted_image: EncryptedImage | None = None,
    body_description: str | None = None,
    body_description_model: str | None = None,
    body_description_generated_at: datetime | None = None,
    encrypted_person_photo: EncryptedImage | None = None,
) -> VisitorFaceObservation:
    image_fields = {}
    if encrypted_image is not None:
        image_fields = dict(
            face_image_ciphertext=encrypted_image.ciphertext,
            face_image_digest=encrypted_image.digest,
            face_image_key_id=encrypted_image.key_id,
            face_image_nonce=encrypted_image.nonce,
            face_image_algorithm=encrypted_image.algorithm,
            face_image_content_type=encrypted_image.content_type,
            face_image_size_bytes=encrypted_image.size_bytes,
        )
    person_photo_fields = {}
    if encrypted_person_photo is not None:
        person_photo_fields = dict(
            person_photo_ciphertext=encrypted_person_photo.ciphertext,
            person_photo_sha256=encrypted_person_photo.digest,
            person_photo_key_id=encrypted_person_photo.key_id,
            person_photo_nonce=encrypted_person_photo.nonce,
            person_photo_algorithm=encrypted_person_photo.algorithm,
            person_photo_content_type=encrypted_person_photo.content_type,
            person_photo_size_bytes=encrypted_person_photo.size_bytes,
        )
    return VisitorFaceObservation(
        facility_id=facility_id, camera_id=camera_id, source_event_id=source_event_id,
        detected_at=detected_at, match_status=match_status, quality_score=quality_score,
        match_confidence=match_confidence, face_embedding_ciphertext=encrypted.ciphertext,
        face_embedding_digest=encrypted.digest, face_embedding_key_id=encrypted.key_id,
        face_embedding_nonce=encrypted.nonce, face_embedding_algorithm=encrypted.algorithm,
        face_embedding_model=embedding_model, face_embedding_dimensions=encrypted.dimensions,
        body_description=body_description,
        body_description_model=body_description_model,
        body_description_generated_at=body_description_generated_at,
        **image_fields,
        **person_photo_fields,
    )
