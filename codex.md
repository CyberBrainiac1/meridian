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

- Live Supabase project URL provided by the user: `https://wgpvaazhpfceountxxel.supabase.co`.
- Do not store the database password, service-role key, access token, or any other Supabase secret in this repo.
- Repo-owned Supabase setup lives in `supabase/`, with deployment notes in `docs/supabase-setup.md`.
- The first backend boundary stores authenticated incident metadata, encrypted incident evidence blobs, and encrypted visitor-face observations only. Raw camera frames should remain local to the Hub by default.
- Evidence encryption rule: Supabase may store ciphertext, object path, hash, nonce, algorithm, key ID, and expiry metadata, but decryption keys must stay outside Supabase.
- Corrected visitor/new-person backend lives in `visitor_face_observations`. The `ingest-visitor-face` Edge Function accepts only pre-encrypted InsightFace/ArcFace embedding ciphertext and metadata; plaintext vectors and plaintext face images are rejected.
- There is no `pending_person_enrollments` table, no approve/reject/merge/dismiss workflow, and no automatic identity-profile creation for unknown visitors.

## Task handoff: encrypted visitor-face observation storage

**User correction, explicit:** "new person" means an unrecognized visitor arriving at the elderly resident's home -- not an admin enrollment/approval workflow.

**Final face stack decision:** keep InsightFace. The user briefly asked about `ageitgey/face_recognition`, but corrected the stack back to InsightFace. Do not switch the Hub or Supabase contract to dlib/face_recognition unless the user explicitly reverses this later.

**What the Hub sends (Part 2, `meridian_hub/face/`):**

- `meridian_hub/face/recognizer.py`: InsightFace (`buffalo_s`) detection + 512-dimensional ArcFace embedding.
- `meridian_hub/face/detector.py`: quality gate picks the one clean snapshot worth acting on.
- `meridian_hub/face/visitor_store.py`: local SQLite match against known residents/staff/visitors.
- `meridian_hub/face/embedding_encryption.py`: AES-256-GCM encryption; key stays on the Hub/facility-controlled side.
- `meridian_hub/face/visitor_observation.py`: builds the encrypted visitor observation payload.

On no match (`match_status: "new_visitor"` or `"unknown"`), the Hub should encrypt the embedding before it leaves the device and send an encrypted visitor-face observation to `ingest-visitor-face` with:

- `facility_id`
- `camera_id`
- `source_event_id`
- `detected_at`
- `match_status`
- quality/match scores
- `face_embedding_ciphertext`
- `face_embedding_digest`
- `face_embedding_key_id`
- `face_embedding_nonce`
- `face_embedding_algorithm`
- `face_embedding_model`
- `face_embedding_dimensions`
- optional encrypted face image metadata

Plaintext embeddings, plaintext face crops, raw images, video, and base64 media must never be sent to Supabase.

Report questions in chat; canonical event schema for everything else is `meridian_hub/events/schemas.py` (PRD section 17).
