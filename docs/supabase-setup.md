# Supabase Setup

This project uses Supabase for authenticated event metadata, encrypted incident evidence storage, encrypted visitor-face observation storage, and Edge Function ingestion. Supabase is not the system of record for raw camera frames, plaintext face images, or plaintext face encodings.

## Current Repository Setup

- `supabase/config.toml` keeps JWT verification on for `ingest-event` and `ingest-visitor-face`.
- `supabase/migrations/20260702220000_initial_security_and_ingest.sql` creates the first schema, RLS policies, grants, and the private `incident-evidence` and `visitor-face-evidence` Storage buckets.
- `supabase/functions/ingest-event/index.ts` accepts incident metadata only. It rejects raw frame, image, video, and base64 fields.
- `supabase/functions/ingest-visitor-face/index.ts` accepts visitor/new-person face observations only after the InsightFace embedding and optional face image have already been encrypted by the Hub or a facility-controlled key service.
- `docs/security/encrypted-evidence.md` defines the evidence encryption model.
- `docs/security/encrypted-visitor-faces.md` defines the visitor-face encryption model.

## Apply To A Supabase Project

The Supabase CLI was not installed locally when this setup was added, and this repo was not linked to a Supabase project. After creating or choosing the private project, run:

```powershell
npx supabase link --project-ref <project-ref>
npx supabase db push
npx supabase functions deploy ingest-event --project-ref <project-ref>
npx supabase functions deploy ingest-visitor-face --project-ref <project-ref>
```

If the deployed function does not receive a default service-role secret in its runtime, set an explicit secret:

```powershell
npx supabase secrets set MERIDIAN_SUPABASE_SERVICE_ROLE_KEY=<service-role-or-secret-key> --project-ref <project-ref>
```

Keep service-role and secret keys out of browser apps, mobile apps, camera firmware, logs, and committed files.

## Access Model

- `anon` receives no table access.
- `authenticated` users can read only facilities, cameras, incidents, device heartbeats, people, consents, and visitor-face observations for facilities where they have a `facility_members` row.
- `authenticated` caregivers/admins can update only the `status` column on incidents for their facility.
- Service-role access is reserved for backend ingestion and operations.
- Evidence objects live in private Storage buckets and must be encrypted before upload.
- Visitor face embeddings are accepted only as ciphertext plus nonce, algorithm, key ID, digest, model, dimensions, quality score, and expiry metadata.
- Optional visitor face images are accepted only as encrypted `.bin` objects in `visitor-face-evidence`, with SHA-256 digest and external key metadata.
- Decryption keys and wrapping authority must stay outside Supabase or be facility-controlled.

This follows Supabase's current guidance to explicitly grant database permissions and rely on RLS policies instead of assuming tables are safely hidden by default. See:

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/functions/auth-headers
- https://supabase.com/docs/guides/functions/secrets
- https://supabase.com/changelog

## Incident Event Shape

`POST /functions/v1/ingest-event` requires a Supabase user JWT because `verify_jwt = true`.

```json
{
  "event_id": "event-20260702-0001",
  "schema_version": "1.0",
  "facility_id": "fac-poc-001",
  "building_id": "bld-poc-001",
  "floor_id": "floor-1",
  "room_id": "room-12",
  "resident_id": "res-0298",
  "camera_id": "cam-entry-01",
  "event_type": "fall_confirmed",
  "severity": "critical",
  "confidence": 0.94,
  "detected_at": "2026-07-02T21:00:00Z",
  "generated_at": "2026-07-02T21:00:01Z",
  "status": "open",
  "reason_codes": ["rapid_vertical_drop", "horizontal_torso"],
  "evidence": {
    "skeleton_available": true,
    "incident_clip_available_locally": true,
    "cloud_video_available": false
  },
  "device_health": {
    "stream_fps": 15.0,
    "wifi_rssi": -58
  },
  "summary": "Fall classifier crossed threshold in living room",
  "encrypted_evidence_path": "fac-poc-001/cam-entry-01/incident.bin",
  "evidence_sha256": "64 lowercase hex chars",
  "evidence_key_id": "customer-kms-key-or-local-key-id",
  "evidence_nonce": "base64url nonce",
  "evidence_algorithm": "AES-256-GCM",
  "evidence_expires_at": "2026-07-09T21:00:00Z",
  "metadata": {
    "model": "pose-fall-v0",
    "score": 0.94
  }
}
```

Do not send `image`, `frame`, `raw_image`, `jpeg`, `png`, `video`, `clip`, `base64`, or `bytes` fields to the function.

## Encrypted Visitor Face Observation Shape

`POST /functions/v1/ingest-visitor-face` requires a Supabase user JWT because `verify_jwt = true`.

This is not an enrollment endpoint. It records that a visitor/new person was observed at an entry camera, while keeping biometric material encrypted before Supabase.

```json
{
  "source_event_id": "event-20260702-visitor-0001",
  "facility_id": "fac-poc-001",
  "camera_id": "cam-entry-01",
  "match_status": "new_visitor",
  "matched_person_id": null,
  "detected_at": "2026-07-02T21:00:00Z",
  "quality_score": 0.91,
  "match_threshold": 0.6,
  "match_confidence": 0.42,
  "face_embedding_ciphertext": "base64url-or-base64-ciphertext",
  "face_embedding_digest": "64 lowercase hex chars",
  "face_embedding_key_id": "facility-kms-key-id",
  "face_embedding_nonce": "base64url nonce",
  "face_embedding_algorithm": "AES-256-GCM",
  "face_embedding_model": "insightface:buffalo_s:arcface",
  "face_embedding_dimensions": 512,
  "face_embedding_expires_at": "2026-08-01T21:00:00Z",
  "face_location": {
    "top": 82,
    "right": 224,
    "bottom": 226,
    "left": 81
  },
  "body_description": "wearing a red jacket, dark pants, and carrying a black backpack",
  "body_description_model": "google/gemini-2.5-flash",
  "body_description_generated_at": "2026-07-02T21:00:01Z",
  "person_photo_ciphertext": "base64 encrypted full-body/person photo",
  "person_photo_sha256": "64 lowercase hex chars",
  "person_photo_key_id": "facility-kms-key-id",
  "person_photo_nonce": "base64url nonce",
  "person_photo_algorithm": "AES-256-GCM",
  "person_photo_content_type": "image/jpeg",
  "person_photo_size_bytes": 88431,
  "metadata": {
    "entry_zone": "main-entrance"
  }
}
```

If an opt-in encrypted face image is uploaded, use the `visitor-face-evidence` bucket and include `encrypted_face_image_path`, `face_image_sha256`, `face_image_key_id`, `face_image_nonce`, and `face_image_algorithm`. Do not upload plaintext visitor snapshots.

When Hack Club AI body description is enabled on the Hub, send `body_description`, `body_description_model`, and `body_description_generated_at` with the observation. The full-body/person photo must be encrypted before upload and sent through `person_photo_*`; never send a plaintext `person_photo`, `body_photo`, raw image field, or base64 media field.

Do not send `face_encoding`, `encoding`, `embedding`, `face_embedding`, `face_image`, `face_crop`, raw image fields, base64 media, plaintext full-body photos, or plaintext snapshots to the function.
