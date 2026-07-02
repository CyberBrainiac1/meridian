# Software Guy Todo

Owner assumption: Dhairya owns backend, apps, dashboard, auth, and software integration. Pranav owns cameras/Hub AI event generation; Megan owns product design and visuals.

## Immediate Backend And Supabase

- [ ] Create/link the private Supabase project for Meridian.
- [ ] Apply the repo migrations from `supabase/migrations/`.
- [ ] Deploy `supabase/functions/ingest-event`.
- [ ] Deploy `supabase/functions/ingest-visitor-face`.
- [ ] Set Supabase secrets for service-role/server-only access; never put service keys in mobile apps, browser apps, firmware, logs, or committed files.
- [ ] Confirm RLS works by facility: users from Facility A cannot read Facility B incidents, cameras, heartbeats, evidence, or visitor-face observations.
- [ ] Confirm `visitor_face_observations` stores encrypted face observation metadata only:
  - [ ] `facility_id`
  - [ ] `camera_id`
  - [ ] `source_event_id`
  - [ ] `detected_at`
  - [ ] `match_status` = `new_visitor`, `repeat_visitor`, `known_visitor`, or `unknown`
  - [ ] encrypted `face_embedding_*` fields: ciphertext, nonce, algorithm, key ID, digest, model, dimensions
  - [ ] optional encrypted face image path and digest
  - [ ] quality score / confidence / match threshold metadata
- [ ] Add evidence expiration cleanup for old encrypted visitor face images.

## New-Person Visitor Detection Flow

- [ ] Coordinate with Pranav's Hub code to keep using InsightFace for entry-camera visitor face detection.
- [ ] Define the exact event contract with Pranav's Hub code once `meridian_hub/events/schemas.py` is stable.
- [ ] Accept visitor/new-person face observations from the Hub through `ingest-visitor-face`.
- [ ] Reject raw image/base64 payloads in backend APIs unless they are going through the encrypted evidence upload path.
- [ ] Store unknown visitor faces as encrypted observation records only; do not create identity profiles automatically.
- [ ] Deduplicate ingestion by `source_event_id`.
- [ ] Decide the retention policy for old encrypted visitor observations and face-image evidence.
- [ ] Decide whether family users can ever see unknown visitor snapshots; default should be no.

## Encryption And Privacy

- [ ] Keep raw video and frames local by default.
- [ ] Encrypt uploaded incident evidence before it reaches Supabase Storage.
- [ ] Encrypt optional visitor face images before they reach Supabase Storage.
- [ ] Keep decryption keys outside Supabase, or use a facility-controlled key-wrapping service.
- [ ] Encrypt face embeddings as biometric data; do not store plaintext vectors.
- [ ] Store only key IDs, nonces, algorithm names, ciphertext, hashes, dimensions, model names, and expiry metadata in Supabase.
- [ ] Document the breach story: if Supabase is stolen, attacker gets ciphertext and metadata, not usable resident images, visitor images, or biometric templates.

## Caregiver App

- [ ] Real-time alert feed.
- [ ] Acknowledge/respond/resolve incident states.
- [ ] Resident profiles.
- [ ] Push notification path for critical incidents.
- [ ] Clear copy for visitor events: "New visitor detected at Main Entrance", not an identity claim.
- [ ] Do not show live video.

## Family App And SMS

- [ ] Emergency SMS/push with response follow-up.
- [ ] Daily summary feed.
- [ ] Visitor log visibility for facility-approved visitor event summaries.
- [ ] Privacy controls so families see summaries/events only, not live video.
- [ ] Decide whether new/unknown visitors are hidden from family view or shown only as a generic visitor count.

## Insights Dashboard

- [ ] Live floor status.
- [ ] Response-time analytics by shift.
- [ ] Incident report generation.
- [ ] Device/camera health view.
- [ ] Encrypted visitor observation timeline.
- [ ] Search/filter/audit history for incidents, visitor observations, and evidence retention.

## Auth, Roles, And Compliance

- [ ] Roles: owner, admin, caregiver, viewer, family.
- [ ] Facility membership model in Supabase.
- [ ] Consent tracking for residents and legal representatives.
- [ ] Face-recognition permission flag per resident/person when a facility uses local known-person matching.
- [ ] Data retention policy for incidents, heartbeats, visitor logs, encrypted visitor observations, and encrypted evidence.
- [ ] Exportable audit trail for admin actions and incident handling.

## Integration With Pranav's Hub

- [ ] Confirm canonical `MeridianEvent` schema field names.
- [ ] Implement backend endpoint shape matching the Hub offline queue.
- [ ] Deduplicate incident ingestion by `event_id`.
- [ ] Deduplicate visitor-face ingestion by `source_event_id`.
- [ ] Keep latency under the PRD target: staged fall detected in under 5 seconds, alert emitted in under 15 seconds.
- [ ] Provide local/mock backend endpoint for Hub testing before real Supabase deployment.
- [ ] Provide test credentials/config docs that do not expose production secrets.

## Testing And Demo Readiness

- [ ] Test RLS with multiple fake facilities.
- [ ] Test encrypted evidence upload/read path.
- [ ] Test encrypted visitor face observation insert/read path.
- [ ] Test that raw media and plaintext face fields are rejected by ingestion.
- [ ] Test mobile push/SMS path.
- [ ] Test offline queue retries and event deduplication.
- [ ] Create a demo script: fall alert, skeleton privacy view, caregiver response, family SMS, dashboard incident report, new visitor detection.

## Do Not Do

- [ ] Do not put service-role keys in the app, frontend, firmware, or Git.
- [ ] Do not store plaintext face embeddings.
- [ ] Do not store plaintext visitor face images.
- [ ] Do not store raw video in the cloud by default.
- [ ] Do not create identity profiles automatically from unknown visitor faces.
- [ ] Do not show families live video.
- [ ] Do not make medical/diagnostic claims.
