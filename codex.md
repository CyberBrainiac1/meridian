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

## Task handoff: encrypted visitor-face observation storage (corrected 2026-07-02, supersedes the enrollment version below)

**User correction, explicit:** "new person" means an unrecognized visitor arriving at the elderly resident's home -- not an admin enrollment/approval workflow. The `pending_person_enrollments` + approve/reject/merge framing in the section below is deleted/superseded. Per chat, Codex is already replacing that backend contract with encrypted visitor-face **observation** storage (no pending/approval state machine).

**What the Hub sends (Part 2, `meridian_hub/face/`, now implemented and tested -- InsightFace, not face_recognition/dlib, per final decision this session):**
- `meridian_hub/face/recognizer.py`: InsightFace (buffalo_s) detection + 512-d ArcFace embedding.
- `meridian_hub/face/detector.py`: quality gate (blur/size/frontal) picks the one clean snapshot worth acting on.
- `meridian_hub/face/visitor_store.py`: local SQLite match against enrolled residents/staff. On no match (`match_status: "unknown"`), the Hub is expected to encrypt the embedding *before* it ever leaves the device and send an encrypted visitor-face observation, matching Codex's `ingest-unknown-person` contract shape: `facility_id`, `camera_id`, `source_event_id`, `detected_at`, quality/match scores, plus `face_embedding_ciphertext`, `digest`, `key_id`, `nonce`, `algorithm`, `dimensions`. Plaintext embeddings are never sent.
- The Hub-side encryption step (AES-256-GCM, key never leaves the Hub) and the observation-event builder matching this exact field shape are the next piece of Hub work, not yet implemented as of this note.

Report questions in chat; canonical event schema for everything else is `meridian_hub/events/schemas.py` (PRD section 17).

<details>
<summary>Superseded: original enrollment-workflow framing (kept for history, do not implement)</summary>

Original ask was a `pending_person_enrollments` table with approve/reject/merge/dismiss admin review and a consent gate before a face becomes "recognized." The user corrected this away -- no enrollment state machine, just encrypted observation logging of visitor arrivals.

</details>
