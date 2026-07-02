# Biometric Enrollment Backend

Unknown visitor detection is not automatic enrollment. The backend stores unknown faces as pending review records, then requires explicit facility approval and face-recognition consent before a person can become recognized.

## Flow

1. The Hub detects a face that does not match the local approved-person store.
2. The Hub emits a `visitor_arrival`-style signal with `match_status: "unknown"` in metadata.
3. The Hub or a facility-controlled key service encrypts the ArcFace embedding before upload.
4. `ingest-unknown-person` rejects plaintext embeddings, raw images, video, and base64 media.
5. Supabase inserts `pending_person_enrollments.status = 'pending'` with ciphertext, digest, key ID, nonce, algorithm, model, dimensions, quality score, camera, detection time, and optional encrypted snapshot metadata.
6. An owner/admin can approve, reject, merge, or dismiss the row. Approve and merge require a same-facility person with active `face_recognition` consent.
7. Every created/reviewed status transition is written to `pending_person_enrollment_audit`.

## Tables

- `people`: facility-scoped residents, staff, visitors, and caregivers.
- `person_consents`: consent records, including face-recognition permission.
- `pending_person_enrollments`: encrypted embedding metadata, optional encrypted snapshot reference, detection metadata, and review status.
- `pending_person_enrollment_audit`: immutable review trail for created, approved, rejected, merged, and dismissed decisions.

## Key Custody

Supabase should not hold biometric decryption keys. Key custody belongs to the facility-controlled encryption path, such as a local Hub key sealed by TPM/DPAPI, a customer KMS, or a dedicated key service.

Supabase stores only ciphertext and metadata. If the database and buckets are stolen, the attacker should not have what they need to decrypt face embeddings or snapshots from Supabase alone.

## Consent Gate

`pending_person_enrollments` has a trigger that rejects `status = 'approved'` or `status = 'merged'` unless:

- `resolved_person_id` is set.
- The resolved person belongs to the same facility.
- The person has an active `face_recognition` consent record.

The trigger fills `consent_record_id`, `consent_verified_at`, and `consent_verified_by` when consent is verified. This encodes the PRD constraint directly in the database, so a future dashboard cannot bypass it with a UI bug.
