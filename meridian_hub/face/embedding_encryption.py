import base64
import hashlib
import json
import os
from dataclasses import dataclass

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ALGORITHM = "AES-256-GCM"
NONCE_SIZE_BYTES = 12


@dataclass(frozen=True)
class EncryptedEmbedding:
    ciphertext: str  # base64
    digest: str  # sha256 hex of the plaintext embedding, for dedup/integrity checks without decrypting
    key_id: str
    nonce: str  # base64
    algorithm: str
    dimensions: int


class EmbeddingEncryptor:
    """Encrypts a face embedding on the Hub before it ever leaves the
    device -- Codex's ingest-unknown-person Supabase endpoint rejects
    plaintext embeddings outright. The AES key never leaves the Hub;
    Supabase only ever receives ciphertext plus enough metadata (nonce,
    algorithm, key_id, digest) to be decrypted later by something that
    holds the key, which is never Supabase itself."""

    def __init__(self, key: bytes, key_id: str):
        if len(key) != 32:
            raise ValueError("AES-256-GCM requires a 32-byte key")
        self._aesgcm = AESGCM(key)
        self._key_id = key_id

    @classmethod
    def from_env(
        cls, env_var: str = "VISITOR_EMBEDDING_ENCRYPTION_KEY",
        key_id_env_var: str = "VISITOR_EMBEDDING_KEY_ID",
    ) -> "EmbeddingEncryptor":
        key_b64 = os.environ.get(env_var)
        if not key_b64:
            raise RuntimeError(f"{env_var} is not set -- cannot encrypt visitor face data without a key")
        key = base64.b64decode(key_b64)
        key_id = os.environ.get(key_id_env_var, "hub-default")
        return cls(key=key, key_id=key_id)

    def encrypt(self, embedding: list[float]) -> EncryptedEmbedding:
        plaintext = json.dumps(embedding).encode("utf-8")
        digest = hashlib.sha256(plaintext).hexdigest()
        nonce = os.urandom(NONCE_SIZE_BYTES)
        ciphertext = self._aesgcm.encrypt(nonce, plaintext, associated_data=None)
        return EncryptedEmbedding(
            ciphertext=base64.b64encode(ciphertext).decode("ascii"),
            digest=digest,
            key_id=self._key_id,
            nonce=base64.b64encode(nonce).decode("ascii"),
            algorithm=ALGORITHM,
            dimensions=len(embedding),
        )

    def decrypt(self, encrypted: EncryptedEmbedding) -> list[float]:
        """Local-only utility (e.g. for tests or Hub-side debugging) --
        Supabase never calls this, it doesn't hold the key."""
        nonce = base64.b64decode(encrypted.nonce)
        ciphertext = base64.b64decode(encrypted.ciphertext)
        plaintext = self._aesgcm.decrypt(nonce, ciphertext, associated_data=None)
        return json.loads(plaintext.decode("utf-8"))
