# Codex Notes

## Claude handoff watch

- Current project path: `C:\Users\emmad\Documents\meridian`.
- Claude Code project transcript folder: `C:\Users\emmad\.claude\projects\C--Users-emmad-Documents-meridian`.
- Known active/recent Claude transcript: `3280d276-e454-4a51-bd22-a23e1f488125.jsonl`.
- A newer Claude Code process may use session id `9070316f-1089-4e07-9839-70cbd2bdfe4b`; watch the transcript folder for any newly created `.jsonl` too.
- If Claude explicitly delegates work to Codex, especially Supabase/backend setup or other Meridian implementation tasks, Codex should act on the instruction in this repo and report back in the current Codex thread.
- Treat ordinary Claude discussion with the user as context only. Act only when the transcript contains a concrete instruction for Codex or a clear task handoff.

## Task handoff: new-person enrollment storage in Supabase (2026-07-02)

User request (explicit handoff): when the Hub detects a face that doesn't match any known/enrolled person, register that new person in a Supabase-backed database, with strong encryption. This is the Supabase/backend half of a feature Claude is building the AI-pipeline half of.

**What Claude is building on the Hub side (Part 2 of `docs/superpowers/plans/2026-07-02-meridian-hub-part1-core.md`, not yet started as of this note):** InsightFace-based face detection + embedding on entry-point cameras. When a detected face's embedding doesn't match anything in the local SQLite `VisitorStore` above a similarity threshold, the Hub emits a `visitor_arrival` event (PRD section 17 schema) with `match_status: "unknown"` and a locally-computed 512-d ArcFace embedding attached as evidence.

**What's being asked of Codex:** design and implement the Supabase side that receives that "unknown person" signal and persists it as a pending enrollment record. Concretely:
- A Supabase table (e.g., `pending_person_enrollments` or similar) scoped by `facility_id`, storing the face embedding vector, a quality-gated snapshot reference (local file path/reference, not necessarily the image itself — see privacy note below), detection timestamp, camera_id, and enrollment status (`pending` / `approved` / `rejected`).
- Encryption at rest for the embedding vector specifically -- it's biometric data, not a generic column. Use Postgres column-level encryption (pgcrypto) or Supabase Vault for the encryption key, not application-level storage of an unencrypted vector. Document whichever approach is chosen and why.
- Row-level security scoped to `facility_id`, consistent with the rest of the PRD's multi-tenant model (PRD section 12).

**Important constraint to respect, not skip:** PRD section 22 (non-goals) explicitly states "No facial recognition without explicit consent and facility approval," and section 20.4 requires tracking "face-recognition permission" as part of consent records. This means new faces should NOT be silently auto-enrolled as recognized people -- they should land in a `pending` state requiring an administrator to approve/reject via the admin dashboard (Dhairya's side, not yet built) before becoming a matchable enrolled person. Please design the schema and flow with this gate built in from the start, not bolted on later -- the PRD is explicit that this is a compliance requirement, not a nice-to-have.

Report back in the current Codex thread when this is scoped or if you have questions about the Hub-side event shape (the canonical event schema is in PRD section 17 and implemented at `meridian_hub/events/schemas.py` once Claude's Part 1 work lands).
