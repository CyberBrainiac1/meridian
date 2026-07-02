# Software Guy Todo

Owner assumption: Dhairya owns backend, apps, dashboard, auth, and software integration. Pranav owns cameras/Hub AI event generation; Megan owns product design and visuals.

## Immediate Backend And Supabase

- [ ] Create/link the private Supabase project for Meridian.
- [ ] Apply the repo migrations from `supabase/migrations/`.
- [ ] Deploy `supabase/functions/ingest-event`.
- [ ] Set Supabase secrets for service-role/server-only access; never put service keys in mobile apps, browser apps, firmware, logs, or committed files.
- [ ] Confirm RLS works by facility: users from Facility A cannot read Facility B incidents, cameras, heartbeats, evidence, or pending enrollments.
- [ ] Add a migration for `pending_person_enrollments`:
  - [ ] `id`
  - [ ] `facility_id`
  - [ ] `camera_id`
  - [ ] `detected_at`
  - [ ] `status` = `pending`, `approved`, `rejected`, `merged`, `dismissed`
  - [ ] encrypted face embedding fields: ciphertext, nonce, algorithm, key ID
  - [ ] optional encrypted snapshot path and digest
  - [ ] quality score / confidence / match threshold metadata
  - [ ] review fields: reviewed_by, reviewed_at, review_note
  - [ ] consent verification fields
- [ ] Add RLS for pending enrollments so only facility admins/owners can approve or reject, and caregivers can see only what the product needs them to see.
- [ ] Add audit logging for every enrollment review action.

## New-Person Detection Flow

- [ ] Define the exact event contract with Pranav's Hub code once `meridian_hub/events/schemas.py` is stable.
- [ ] Accept unknown-person events from the Hub through an authenticated backend path.
- [ ] Reject raw image/base64 payloads in backend APIs unless they are going through the encrypted evidence upload path.
- [ ] Store unknown faces as pending records only; do not auto-enroll.
- [ ] Add deduplication so the same unknown person walking past the camera five times does not create five noisy review items.
- [ ] Decide the retention policy for rejected/dismissed pending records.
- [ ] Decide whether family users can ever see unknown visitor snapshots; default should be no.

## Encryption And Privacy

- [ ] Keep raw video and frames local by default.
- [ ] Encrypt uploaded evidence before it reaches Supabase Storage.
- [ ] Keep decryption keys outside Supabase, or use a facility-controlled key-wrapping service.
- [ ] Encrypt face embeddings as biometric data; do not store plaintext vectors.
- [ ] Store only key IDs, nonces, algorithm names, ciphertext, hashes, and expiry metadata in Supabase.
- [ ] Implement evidence expiration cleanup for old encrypted snapshots/clips.
- [ ] Document the breach story: if Supabase is stolen, attacker gets ciphertext and metadata, not usable resident images or biometric templates.

## Caregiver App

- [ ] Real-time alert feed.
- [ ] Acknowledge/respond/resolve incident states.
- [ ] Resident profiles.
- [ ] Push notification path for critical incidents.
- [ ] Clear copy for unknown-person events: "Unknown visitor detected at Main Entrance", not an identity claim.
- [ ] Do not show live video.

## Family App And SMS

- [ ] Emergency SMS/push with response follow-up.
- [ ] Daily summary feed.
- [ ] Visitor log visibility for approved visitor events.
- [ ] Privacy controls so families see summaries/events only, not live video.
- [ ] Decide whether unknown/pending visitors are hidden from family view until approved.

## Insights Dashboard

- [ ] Live floor status.
- [ ] Response-time analytics by shift.
- [ ] Incident report generation.
- [ ] Device/camera health view.
- [ ] Admin pending-person enrollment queue.
- [ ] Admin actions: approve, reject, merge, dismiss, add consent verification, add notes.
- [ ] Search/filter/audit history for visitor and enrollment decisions.

## Auth, Roles, And Compliance

- [ ] Roles: owner, admin, caregiver, viewer, family.
- [ ] Facility membership model in Supabase.
- [ ] Consent tracking for residents and legal representatives.
- [ ] Face-recognition permission flag per resident/person.
- [ ] Data retention policy for incidents, heartbeats, visitor logs, pending enrollments, and encrypted evidence.
- [ ] Exportable audit trail for admin actions and incident handling.

## Integration With Pranav's Hub

- [ ] Confirm canonical `MeridianEvent` schema field names.
- [ ] Implement backend endpoint shape matching the Hub offline queue.
- [ ] Deduplicate by `event_id`.
- [ ] Keep latency under the PRD target: staged fall detected in under 5 seconds, alert emitted in under 15 seconds.
- [ ] Provide local/mock backend endpoint for Hub testing before real Supabase deployment.
- [ ] Provide test credentials/config docs that do not expose production secrets.

## Testing And Demo Readiness

- [ ] Test RLS with multiple fake facilities.
- [ ] Test encrypted evidence upload/read path.
- [ ] Test that raw media fields are rejected by ingestion.
- [ ] Test unknown-person pending enrollment creation.
- [ ] Test admin approve/reject/merge flow.
- [ ] Test mobile push/SMS path.
- [ ] Test offline queue retries and event deduplication.
- [ ] Create a demo script: fall alert, skeleton privacy view, caregiver response, family SMS, dashboard incident report, unknown visitor pending review.

## Do Not Do

- [ ] Do not put service-role keys in the app, frontend, firmware, or Git.
- [ ] Do not store plaintext face embeddings.
- [ ] Do not store raw video in the cloud by default.
- [ ] Do not auto-enroll unknown people.
- [ ] Do not show families live video.
- [ ] Do not make medical/diagnostic claims.
