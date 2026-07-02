# Encrypted Visitor Face Observations

New-person detection means a visitor arrives at the elderly resident's home and the entry camera sees a face that does not match the local known-person store. It is not a pending enrollment workflow.

## Flow

1. The Hub detects a face at an entry-point camera.
2. The Hub uses InsightFace to compute a local 512-dimensional ArcFace embedding from a quality-gated face crop.
3. The Hub compares the embedding against the local known resident, staff, and visitor store.
4. If no match clears the threshold, the Hub emits a `visitor_arrival` event with metadata such as `match_status: "new_visitor"` or `match_status: "unknown"`.
5. If `HACKCLUB_AI_API_KEY` is configured, the Hub sends a local person/full-body snapshot to Hack Club AI's vision endpoint to generate one caregiver-facing body/clothing description. This happens before encryption because the model needs pixels.
6. The Hub or a facility-controlled key service encrypts the face embedding, and optionally encrypts the face image and full-body/person photo, before upload.
7. `ingest-visitor-face` rejects plaintext face embeddings, raw images, video, base64 media, plaintext face crops, and plaintext full-body/person photos.
8. Supabase inserts `visitor_face_observations` with ciphertext, digest, key ID, nonce, algorithm, model, dimensions, quality score, camera, detection time, generated body description metadata, optional encrypted image metadata, and facility-scoped RLS.

## Tables And Buckets

- `visitor_face_observations`: encrypted visitor face embedding metadata, optional encrypted face image reference, optional encrypted full-body/person photo ciphertext, generated body description, match metadata, camera, and detection time.
- `visitor-face-evidence`: private Storage bucket for optional encrypted face image `.bin` objects.
- `incident_events`: can still receive the regular `visitor_arrival` event envelope for timelines and notifications.
- `people` and `person_consents`: remain the facility-scoped identity and consent tables, but the visitor-face observation path does not silently create or modify person records.

## Key Custody

Supabase must not hold biometric decryption keys. Key custody belongs to the facility-controlled encryption path, such as a local Hub key sealed by TPM/DPAPI, a customer KMS, or a dedicated key service.

Supabase stores only ciphertext and metadata for biometric/photo material. If the database and buckets are stolen, the attacker should not have what they need to decrypt face encodings, face images, or full-body/person photos from Supabase alone.

## Product Boundary

Unknown visitors are logged as observations, not identity claims. A dashboard can show "New visitor detected at Main Entrance" and related metadata, but it must not imply that the person has been identified or enrolled.

The backend deduplicates by `source_event_id` only. Repeated sightings may still be logged as separate observations because visits are operationally meaningful; any higher-level repeat-visitor grouping should happen in a local/facility-controlled matching layer before upload.
