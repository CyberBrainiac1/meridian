# Supabase Setup

This project uses Supabase for authenticated event metadata, encrypted incident evidence storage, and Edge Function ingestion. Supabase is not the system of record for raw camera frames.

## Current Repository Setup

- `supabase/config.toml` keeps JWT verification on for `ingest-event` and `ingest-unknown-person`.
- `supabase/migrations/20260702220000_initial_security_and_ingest.sql` creates the first schema, RLS policies, grants, and the private `incident-evidence` Storage bucket.
- `supabase/functions/ingest-event/index.ts` accepts incident metadata only. It rejects raw frame, image, video, and base64 fields.
- `supabase/functions/ingest-unknown-person/index.ts` accepts unknown-face enrollment signals only after biometric embeddings have already been encrypted by the Hub or a facility-controlled key service.
- `docs/security/encrypted-evidence.md` defines the evidence encryption model.

## Apply To A Supabase Project

The Supabase CLI was not installed locally when this setup was added, and this repo was not linked to a Supabase project. After creating or choosing the private project, run:

```powershell
npx supabase link --project-ref <project-ref>
npx supabase db push
npx supabase functions deploy ingest-event --project-ref <project-ref>
npx supabase functions deploy ingest-unknown-person --project-ref <project-ref>
```

If the deployed function does not receive a default service-role secret in its runtime, set an explicit secret:

```powershell
npx supabase secrets set MERIDIAN_SUPABASE_SERVICE_ROLE_KEY=<service-role-or-secret-key> --project-ref <project-ref>
```

Keep service-role and secret keys out of browser apps, mobile apps, camera firmware, logs, and committed files.

## Access Model

- `anon` receives no table access.
- `authenticated` users can read only facilities, cameras, incidents, and device heartbeats for facilities where they have a `facility_members` row.
- `authenticated` caregivers/admins can update only the `status` column on incidents for their facility.
- Service-role access is reserved for backend ingestion and operations.
- Evidence objects live in a private Storage bucket and must be encrypted before upload.
- Unknown-person face embeddings are accepted only as ciphertext plus nonce, algorithm, key ID, digest, model, dimensions, quality score, and expiry metadata.
- Pending person enrollments require owner/admin review. Approval and merge are blocked unless the target person has an active `face_recognition` consent record.
- Enrollment review actions are written to `pending_person_enrollment_audit`.

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

## Unknown-Person Enrollment Shape

`POST /functions/v1/ingest-unknown-person` also requires a Supabase user JWT because `verify_jwt = true`.

```json
{
  "source_event_id": "event-20260702-visitor-0001",
  "facility_id": "fac-poc-001",
  "camera_id": "cam-entry-01",
  "match_status": "unknown",
  "person_id": null,
  "detected_at": "2026-07-02T21:00:00Z",
  "quality_score": 0.91,
  "match_threshold": 0.78,
  "match_confidence": 0.42,
  "face_embedding_ciphertext": "base64url-or-base64-ciphertext",
  "face_embedding_digest": "64 lowercase hex chars",
  "face_embedding_key_id": "facility-kms-key-id",
  "face_embedding_nonce": "base64url nonce",
  "face_embedding_algorithm": "AES-256-GCM",
  "face_embedding_model": "arcface",
  "face_embedding_dimensions": 512,
  "face_embedding_expires_at": "2026-08-01T21:00:00Z",
  "snapshot_ref": "local:2026-07-02T14-01-09_entry01.jpg",
  "metadata": {
    "entry_zone": "main-entrance"
  }
}
```

If an opt-in encrypted snapshot is uploaded, use the `person-enrollment-evidence` bucket and include `encrypted_snapshot_path`, `snapshot_sha256`, `snapshot_key_id`, `snapshot_nonce`, and `snapshot_algorithm`. Do not upload plaintext visitor snapshots.

Do not send `embedding`, `face_embedding`, `embedding_vector`, raw image fields, base64 media, or plaintext snapshots to the function.
