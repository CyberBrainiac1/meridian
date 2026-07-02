# Encrypted Evidence Model

Meridian should avoid cloud images by default. Routine monitoring should keep raw frames on the Hub, derive events locally, and upload only metadata such as timestamps, camera IDs, model scores, pose summaries, and device health.

When an incident needs review evidence, the Hub should encrypt the still or short clip before it reaches Supabase.

## Threat Model

The design assumes an attacker may steal:

- The Supabase database.
- The private Storage bucket contents.
- A user's authenticated session with ordinary read access.

The attacker should still receive only ciphertext for resident imagery unless they also compromise the external key authority.

## Encryption Flow

1. The Hub keeps a short local ring buffer and overwrites raw frames quickly.
2. For an incident, the Hub creates a random per-incident data encryption key.
3. The Hub encrypts the evidence with `AES-256-GCM` or `XCHACHA20-POLY1305`.
4. The Hub uploads only the ciphertext as `application/octet-stream` to the private `incident-evidence` bucket.
5. The Hub writes event metadata through `ingest-event`, including object path, SHA-256 digest, nonce, algorithm, external key ID, and expiry time.
6. The data encryption key is wrapped or escrowed outside Supabase, for example in a customer-held KMS, a facility key service, TPM-backed local storage, or admin-controlled recovery escrow.

Supabase should not store plaintext images, plaintext clips, data encryption keys, or key-wrapping secrets.

## Visitor Face Encodings

Face embeddings are biometric data. For visitor/new-person detection, the Hub or a facility-controlled key service must encrypt the 512-dimensional InsightFace/ArcFace embedding before calling `ingest-visitor-face`. Supabase stores only:

- `face_embedding_ciphertext`.
- `face_embedding_digest`, used for integrity and facility-controlled matching references without exposing the raw embedding.
- `face_embedding_key_id`, nonce, algorithm, model name, dimension count, quality score, expiry metadata, and match status.
- Optional encrypted face image object metadata in the private `visitor-face-evidence` bucket.

The plaintext embedding, face crop, and visitor image must not be sent to Supabase, stored in JSONB/vector columns, logs, object storage, analytics tools, or app telemetry. New-person detection is an observation log, not a pending enrollment queue.

## "Cannot Be Decrypted" Rule

Encrypted data can always be decrypted by someone who has the key. If the requirement is that stolen images cannot be decrypted by anyone from Supabase data alone, the key must stay out of Supabase.

If the requirement is stricter, use non-reversible data instead of encrypted images:

- Upload pose/keypoint tracks instead of frames.
- Upload redacted or blurred thumbnails only when operationally acceptable.
- Upload classifier outputs and timestamps only.
- Delete raw local evidence after the retention window.

The safest default is metadata-only cloud storage and short local retention for raw video.

## Operational Requirements

- No service-role key in camera firmware, browser code, mobile apps, or logs.
- No raw frame payloads in Edge Functions or PostgREST requests.
- Evidence object paths must be facility-prefixed and end in `.bin`.
- Evidence should have a short `evidence_expires_at` retention timestamp.
- A scheduled cleanup job should delete expired evidence objects and old metadata once retention policy is decided.
