# Codex Notes

## Claude handoff watch

- Current project path: `C:\Users\emmad\Documents\meridian`.
- Claude Code project transcript folder: `C:\Users\emmad\.claude\projects\C--Users-emmad-Documents-meridian`.
- Known active/recent Claude transcript: `3280d276-e454-4a51-bd22-a23e1f488125.jsonl`.
- A newer Claude Code process may use session id `9070316f-1089-4e07-9839-70cbd2bdfe4b`; watch the transcript folder for any newly created `.jsonl` too.
- If Claude explicitly delegates work to Codex, especially Supabase/backend setup or other Meridian implementation tasks, Codex should act on the instruction in this repo and report back in the current Codex thread.
- Treat ordinary Claude discussion with the user as context only. Act only when the transcript contains a concrete instruction for Codex or a clear task handoff.

## Agent chat bridge

- Do not inject prompts into Claude's live session for coordination.
- Shared local chat path: `C:\Users\emmad\Documents\meridian\.agents\bridge\chat.md`.
- Helper command: `powershell -ExecutionPolicy Bypass -File .agents\bridge\agent-chat.ps1 post -From codex -Message "message"`.
- The other Codex thread for Supabase/backend/encryption work is `019f24c7-7712-7b51-9928-ee469961be94`.
- Bridge behavior: Codex posts status updates to the chat; Claude can read and reply there when it chooses. Do not assume Claude has seen a chat message until Claude replies in `chat.md`.
- Active bridge heartbeat automation: `meridian-agent-chat-bridge`; it watches the Supabase Codex thread and updates the file-backed chat without injecting prompts into Claude.

## Supabase backend setup

- Supabase CLI was not installed and the repo was not linked to a live Supabase project when the backend scaffold was added.
- Repo-owned Supabase setup lives in `supabase/`, with deployment notes in `docs/supabase-setup.md`.
- The first backend boundary stores authenticated incident metadata and encrypted evidence blobs only. Raw camera frames should remain local to the Hub by default.
- Evidence encryption rule: Supabase may store ciphertext, object path, hash, nonce, algorithm, key ID, and expiry metadata, but decryption keys must stay outside Supabase.
- Unknown-person enrollment backend lives in `pending_person_enrollments`. The `ingest-unknown-person` Edge Function accepts only pre-encrypted face embedding ciphertext and metadata; plaintext vectors are rejected.
- Approval or merge of an unknown face into a recognized person is blocked in the database unless a same-facility person has active `face_recognition` consent. Review actions are audited in `pending_person_enrollment_audit`.

## Task handoff: new-person enrollment storage in Supabase (2026-07-02)

User request (explicit handoff): when the Hub detects a face that doesn't match any known/enrolled person, register that new person in a Supabase-backed database, with strong encryption. This is the Supabase/backend half of a feature Claude is building the AI-pipeline half of.

Documentation update: `PRD.md` now includes this as the new-person detection / encrypted Supabase pending-enrollment feature, and `softwareguytodo.md` tracks Dhairya's backend/app/dashboard work. Keep the consent gate: unknown faces become pending review records only, never silent enrollment.

**What Claude is building on the Hub side (Part 2 of `docs/superpowers/plans/2026-07-02-meridian-hub-part1-core.md`, not yet started as of this note):** InsightFace-based face detection + embedding on entry-point cameras. When a detected face's embedding doesn't match anything in the local SQLite `VisitorStore` above a similarity threshold, the Hub emits a `visitor_arrival` event (PRD section 17 schema) with `match_status: "unknown"` metadata. Per PRD v1.1, the backend contract expects any biometric embedding sent to Supabase to already be encrypted by the Hub or a facility-controlled key service.

**What's being asked of Codex:** design and implement the Supabase side that receives that "unknown person" signal and persists it as a pending enrollment record. Concretely:
- A Supabase table (`pending_person_enrollments`) scoped by `facility_id`, storing encrypted face embedding ciphertext and metadata, a quality-gated snapshot reference or encrypted snapshot path, detection timestamp, camera_id, and enrollment status (`pending` / `approved` / `rejected` / `merged` / `dismissed`).
- Encryption rule: no plaintext face embeddings or plaintext images in Supabase. Store ciphertext, nonce, algorithm, key ID, digest/hash, expiry metadata, and quality score only. Decryption authority stays outside Supabase or facility-controlled.
- Row-level security scoped to `facility_id`, consistent with the rest of the PRD's multi-tenant model (PRD section 12).

**Important constraint to respect, not skip:** PRD section 22 (non-goals) explicitly states "No facial recognition without explicit consent and facility approval," and section 20.4 requires tracking "face-recognition permission" as part of consent records. This means new faces should NOT be silently auto-enrolled as recognized people -- they should land in a `pending` state requiring an administrator to approve/reject via the admin dashboard (Dhairya's side, not yet built) before becoming a matchable enrolled person. Please design the schema and flow with this gate built in from the start, not bolted on later -- the PRD is explicit that this is a compliance requirement, not a nice-to-have.

Report back in the current Codex thread when this is scoped or if you have questions about the Hub-side event shape (the canonical event schema is in PRD section 17 and implemented at `meridian_hub/events/schemas.py` once Claude's Part 1 work lands).
