import base64
import hashlib
import json
import os
from pathlib import Path
from dataclasses import dataclass

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ALGORITHM = "AES-256-GCM"
NONCE_SIZE_BYTES = 12


@dataclass(frozen=True)
class EncryptedBlob:
    ciphertext: str  # base64
    digest: str  # sha256 hex of the plaintext bytes, for dedup/integrity checks without decrypting
    key_id: str
    nonce: str  # base64
    algorithm: str
    size_bytes: int


@dataclass(frozen=True)
class EncryptedEmbedding:
    ciphertext: str
    digest: str
    key_id: str
    nonce: str
    algorithm: str
    dimensions: int


@dataclass(frozen=True)
class EncryptedImage:
    ciphertext: str
    digest: str
    key_id: str
    nonce: str
    algorithm: str
    content_type: str
    size_bytes: int


class EmbeddingEncryptor:
    """Encrypts visitor face data on the Hub before any of it leaves the
    device -- Codex's Supabase ingest endpoint rejects plaintext
    embeddings and plaintext images outright. The AES key never leaves
    the Hub; Supabase only ever receives ciphertext plus enough metadata
    (nonce, algorithm, key_id, digest) to be decrypted later by something
    that holds the key, which is never Supabase itself.

    Handles both the face embedding (a float vector) and the quality-
    gated face crop/snapshot (raw image bytes) -- same AES-256-GCM
    primitive underneath, since a face image sent for a caregiver/admin
    to later attach a name to is exactly as sensitive as the embedding
    used to match it."""

    def __init__(self, key: bytes, key_id: str):
        if len(key) != 32:
            raise ValueError("AES-256-GCM requires a 32-byte key")
        self._aesgcm = AESGCM(key)
        self._key_id = key_id

    @classmethod
    def from_env(
        cls, env_var: str = "VISITOR_EMBEDDING_ENCRYPTION_KEY",
        key_id_env_var: str = "VISITOR_EMBEDDING_KEY_ID",
        env_file: str | os.PathLike[str] | None = ".env",
    ) -> "EmbeddingEncryptor":
        env_file_values = _read_env_file(env_file) if env_file is not None else {}
        key_b64 = os.environ.get(env_var) or env_file_values.get(env_var)
        if not key_b64:
            raise RuntimeError(f"{env_var} is not set -- cannot encrypt visitor face data without a key")
        key = base64.b64decode(key_b64)
        key_id = os.environ.get(key_id_env_var) or env_file_values.get(key_id_env_var) or "hub-default"
        return cls(key=key, key_id=key_id)

    def _encrypt_bytes(self, plaintext: bytes) -> EncryptedBlob:
        digest = hashlib.sha256(plaintext).hexdigest()
        nonce = os.urandom(NONCE_SIZE_BYTES)
        ciphertext = self._aesgcm.encrypt(nonce, plaintext, associated_data=None)
        return EncryptedBlob(
            ciphertext=base64.b64encode(ciphertext).decode("ascii"),
            digest=digest,
            key_id=self._key_id,
            nonce=base64.b64encode(nonce).decode("ascii"),
            algorithm=ALGORITHM,
            size_bytes=len(plaintext),
        )

    def _decrypt_bytes(self, ciphertext_b64: str, nonce_b64: str) -> bytes:
        nonce = base64.b64decode(nonce_b64)
        ciphertext = base64.b64decode(ciphertext_b64)
        return self._aesgcm.decrypt(nonce, ciphertext, associated_data=None)

    def encrypt(self, embedding: list[float]) -> EncryptedEmbedding:
        blob = self._encrypt_bytes(json.dumps(embedding).encode("utf-8"))
        return EncryptedEmbedding(
            ciphertext=blob.ciphertext, digest=blob.digest, key_id=blob.key_id,
            nonce=blob.nonce, algorithm=blob.algorithm, dimensions=len(embedding),
        )

    def decrypt(self, encrypted: EncryptedEmbedding) -> list[float]:
        """Local-only utility (e.g. for tests or Hub-side debugging) --
        Supabase never calls this, it doesn't hold the key."""
        plaintext = self._decrypt_bytes(encrypted.ciphertext, encrypted.nonce)
        return json.loads(plaintext.decode("utf-8"))

    def encrypt_image(self, image_bytes: bytes, content_type: str = "image/jpeg") -> EncryptedImage:
        blob = self._encrypt_bytes(image_bytes)
        return EncryptedImage(
            ciphertext=blob.ciphertext, digest=blob.digest, key_id=blob.key_id,
            nonce=blob.nonce, algorithm=blob.algorithm, content_type=content_type,
            size_bytes=blob.size_bytes,
        )

    def decrypt_image(self, encrypted: EncryptedImage) -> bytes:
        """Local-only utility, same caveat as decrypt()."""
        return self._decrypt_bytes(encrypted.ciphertext, encrypted.nonce)


def _read_env_file(env_file: str | os.PathLike[str]) -> dict[str, str]:
    path = Path(env_file)
    if not path.exists():
        return {}

    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if not key:
            continue
        values[key] = value.strip().strip('"').strip("'")
    return values
