from datetime import datetime
from typing import Literal

from pydantic import BaseModel

from meridian_hub.face.embedding_encryption import EncryptedEmbedding


class VisitorFaceObservation(BaseModel):
    """Matches Codex's live ingest-visitor-face Supabase contract
    field-for-field (codex.md, "Task handoff: encrypted visitor-face
    observation storage" -- field names are prefixed face_embedding_* per
    Codex's finalized Edge Function, not the earlier unprefixed draft).
    No enrollment/approval workflow -- this is a plain observation
    record. Everything under face_embedding_* comes from
    EmbeddingEncryptor's output; this schema has no field for a plaintext
    embedding, so it's structurally impossible to send one by accident."""

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


def build_visitor_observation(
    *, facility_id: str, camera_id: str, source_event_id: str, detected_at: datetime,
    match_status: str, quality_score: float, match_confidence: float | None,
    encrypted: EncryptedEmbedding, embedding_model: str = "buffalo_s/arcface",
) -> VisitorFaceObservation:
    return VisitorFaceObservation(
        facility_id=facility_id, camera_id=camera_id, source_event_id=source_event_id,
        detected_at=detected_at, match_status=match_status, quality_score=quality_score,
        match_confidence=match_confidence, face_embedding_ciphertext=encrypted.ciphertext,
        face_embedding_digest=encrypted.digest, face_embedding_key_id=encrypted.key_id,
        face_embedding_nonce=encrypted.nonce, face_embedding_algorithm=encrypted.algorithm,
        face_embedding_model=embedding_model, face_embedding_dimensions=encrypted.dimensions,
    )
