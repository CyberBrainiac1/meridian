import base64
import hashlib
import json
import os

import pytest
from cryptography.exceptions import InvalidTag

from meridian_hub.face.embedding_encryption import EmbeddingEncryptor, ALGORITHM


def _encryptor():
    return EmbeddingEncryptor(key=os.urandom(32), key_id="test-key-1")


def test_encrypt_then_decrypt_round_trips():
    encryptor = _encryptor()
    embedding = [0.1, -0.2, 0.3, 0.55]
    encrypted = encryptor.encrypt(embedding)
    decrypted = encryptor.decrypt(encrypted)
    assert decrypted == embedding


def test_ciphertext_never_contains_plaintext_embedding_values():
    encryptor = _encryptor()
    embedding = [0.123456, -0.654321]
    encrypted = encryptor.encrypt(embedding)
    assert "0.123456" not in encrypted.ciphertext
    assert str(embedding) != encrypted.ciphertext


def test_digest_matches_sha256_of_plaintext_json():
    encryptor = _encryptor()
    embedding = [1.0, 2.0, 3.0]
    encrypted = encryptor.encrypt(embedding)
    expected_digest = hashlib.sha256(json.dumps(embedding).encode("utf-8")).hexdigest()
    assert encrypted.digest == expected_digest


def test_metadata_fields_are_populated_correctly():
    encryptor = EmbeddingEncryptor(key=os.urandom(32), key_id="hub-facility-42")
    embedding = [0.0] * 512
    encrypted = encryptor.encrypt(embedding)
    assert encrypted.key_id == "hub-facility-42"
    assert encrypted.algorithm == ALGORITHM
    assert encrypted.dimensions == 512
    assert len(encrypted.nonce) > 0


def test_wrong_key_fails_to_decrypt():
    embedding = [0.5, 0.5]
    encrypted = EmbeddingEncryptor(key=os.urandom(32), key_id="key-a").encrypt(embedding)
    wrong_key_encryptor = EmbeddingEncryptor(key=os.urandom(32), key_id="key-b")
    with pytest.raises(InvalidTag):
        wrong_key_encryptor.decrypt(encrypted)


def test_rejects_non_32_byte_key():
    with pytest.raises(ValueError):
        EmbeddingEncryptor(key=b"too-short", key_id="bad")


def test_from_env_raises_clear_error_when_key_missing(monkeypatch):
    monkeypatch.delenv("VISITOR_EMBEDDING_ENCRYPTION_KEY", raising=False)
    monkeypatch.delenv("VISITOR_EMBEDDING_KEY_ID", raising=False)
    with pytest.raises(RuntimeError, match="VISITOR_EMBEDDING_ENCRYPTION_KEY"):
        EmbeddingEncryptor.from_env(env_file=None)


def test_from_env_loads_local_env_file(monkeypatch, tmp_path):
    monkeypatch.delenv("VISITOR_EMBEDDING_ENCRYPTION_KEY", raising=False)
    monkeypatch.delenv("VISITOR_EMBEDDING_KEY_ID", raising=False)
    key = base64.b64encode(os.urandom(32)).decode("ascii")
    env_file = tmp_path / ".env"
    env_file.write_text(
        f"VISITOR_EMBEDDING_ENCRYPTION_KEY={key}\nVISITOR_EMBEDDING_KEY_ID=file-key\n",
        encoding="utf-8",
    )

    encryptor = EmbeddingEncryptor.from_env(env_file=env_file)
    encrypted = encryptor.encrypt([0.1, 0.2])

    assert encrypted.key_id == "file-key"


def test_image_encrypt_then_decrypt_round_trips():
    encryptor = _encryptor()
    fake_jpeg_bytes = b"\xff\xd8\xff\xe0fake-jpeg-bytes-for-testing\xff\xd9"
    encrypted = encryptor.encrypt_image(fake_jpeg_bytes)
    decrypted = encryptor.decrypt_image(encrypted)
    assert decrypted == fake_jpeg_bytes


def test_image_ciphertext_never_contains_plaintext_bytes():
    encryptor = _encryptor()
    fake_jpeg_bytes = b"a-very-recognizable-marker-sequence" * 4
    encrypted = encryptor.encrypt_image(fake_jpeg_bytes)
    decoded_ciphertext = base64.b64decode(encrypted.ciphertext)
    assert decoded_ciphertext != fake_jpeg_bytes
    assert b"a-very-recognizable-marker-sequence" not in decoded_ciphertext


def test_image_metadata_fields_populated():
    encryptor = EmbeddingEncryptor(key=os.urandom(32), key_id="hub-facility-42")
    image_bytes = b"\x00" * 2048
    encrypted = encryptor.encrypt_image(image_bytes, content_type="image/jpeg")
    assert encrypted.key_id == "hub-facility-42"
    assert encrypted.algorithm == ALGORITHM
    assert encrypted.content_type == "image/jpeg"
    assert encrypted.size_bytes == 2048


def test_image_digest_matches_sha256_of_plaintext_bytes():
    encryptor = _encryptor()
    image_bytes = b"some-jpeg-bytes"
    encrypted = encryptor.encrypt_image(image_bytes)
    assert encrypted.digest == hashlib.sha256(image_bytes).hexdigest()
