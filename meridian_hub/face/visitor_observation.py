from datetime import datetime
from typing import Literal

from pydantic import BaseModel

from meridian_hub.face.embedding_encryption import EncryptedEmbedding


class VisitorFaceObservation(BaseModel):
    """Matches Codex's ingest-unknown-person Supabase contract field-for-
    field (see codex.md's corrected task handoff). No enrollment/approval
    workflow -- this is a plain observation record. face_embedding_ciphertext
    and friends come from EmbeddingEncryptor; this schema never accepts a
    plaintext embedding field, so it's structurally impossible to send one
    by accident."""

    facility_id: str
    camera_id: str
    source_event_id: str
    detected_at: datetime
    match_status: Literal["known", "unknown"]
    quality_score: float
    match_confidence: float | None = None
    face_embedding_ciphertext: str
    digest: str
    key_id: str
    nonce: str
    algorithm: str
    dimensions: int


def build_visitor_observation(
    *, facility_id: str, camera_id: str, source_event_id: str, detected_at: datetime,
    match_status: str, quality_score: float, match_confidence: float | None,
    encrypted: EncryptedEmbedding,
) -> VisitorFaceObservation:
    return VisitorFaceObservation(
        facility_id=facility_id, camera_id=camera_id, source_event_id=source_event_id,
        detected_at=detected_at, match_status=match_status, quality_score=quality_score,
        match_confidence=match_confidence, face_embedding_ciphertext=encrypted.ciphertext,
        digest=encrypted.digest, key_id=encrypted.key_id, nonce=encrypted.nonce,
        algorithm=encrypted.algorithm, dimensions=encrypted.dimensions,
    )
