# Meridian Software Scope (Dhairya's part) — Design

Date: 2026-07-02
Status: Approved for planning

## Goal

Build the P0 demo path for the software side of Meridian per `PRD.md` and
`softwareguytodo.md`: Supabase backend completeness, Meridian Insights
(facility web dashboard), and a combined Meridian Care + Meridian Family
mobile app. Scope is bounded to what's needed for a live 2-camera,
2-resident demo, not full production coverage.

## Directory Layout

New top-level directory `meridian_software/`:

```
meridian_software/
  insights-dashboard/   # Next.js — Meridian Insights
  mobile/                # Expo/React Native — Meridian Care + Meridian Family
  shared/                 # TS types mirroring the Supabase schema + event contract, shared API client
```

Backend changes stay in the existing `supabase/` folder (new migration +
edits to existing Edge Functions) since that's where schema/RLS/functions
already live.

## Backend (extend existing Supabase scaffold)

New migration on top of `20260702220000_initial_security_and_ingest.sql`:

- Add `'family'` to the `facility_members.role` check constraint.
- New `family_member_links` table: `facility_id`, `user_id`, `resident_id`
  — a family account only ever sees data for its linked resident(s).
- New `resident_profiles` table: `id`, `facility_id`, `person_id` (FK to
  `people`), `display_name`, `room_id`, `photo path (optional, local
  reference only)`, `risk_flags jsonb`, `care_notes text`,
  `created_at`/`updated_at`. This is the caregiver-facing profile; `people`
  remains the identity/recognition record.
- Incident lifecycle columns on `incident_events`: `acknowledged_by`,
  `acknowledged_at`, `resolved_by`, `resolved_at`, `resolution_note`.
- New RPC `respond_to_incident(incident_id, new_status, note)` — validates
  caller is a facility member with role in
  (`owner`,`admin`,`caregiver`), stamps `acknowledged_by`/`acknowledged_at`
  or `resolved_by`/`resolved_at` from `auth.uid()` and `now()` server-side
  (never trusts client-supplied actor/timestamp), and enforces the status
  transition (`open`→`acknowledged`→`responding`→`resolved`, or
  `dismissed_false_alarm`/`escalated` from any open state).
- RLS: extend `incident_events` and `visitor_face_observations` select
  policies so a `family` role can read rows where the row's `resident_id`
  matches one of their `family_member_links`, restricted to
  non-evidence columns via a view (`family_incident_feed`,
  `family_visitor_feed`) that excludes `encrypted_evidence_path`,
  `face_embedding_*`, and `encrypted_face_image_path` entirely — families
  never get evidence paths even indirectly.
- New Edge Function `notify-family`: stub SMS provider behind a
  `sendSms(to, body)` interface (implementation just logs + records to a
  `notifications` table for demo purposes); triggered by the
  `respond_to_incident` RPC (via a `pg_net`/webhook call or the RPC just
  writing a `notifications` row that a scheduled/manual trigger reads —
  keep this simple, no real Twilio wiring, see Non-Goals).
- Seed script `supabase/seed/demo_two_room_seed.sql`: 1 facility, 2 cameras
  (`entry-cam`, `room-101-cam` or similar demo-appropriate names), 2
  `people` rows (residents) + matching `resident_profiles`, demo
  `facility_members` rows for an owner/caregiver/family test user each
  (referencing pre-created `auth.users` — documented as a manual step
  since seeding `auth.users` needs the Supabase Auth API, not raw SQL).

## Meridian Insights (`insights-dashboard/`, Next.js)

- Supabase Auth (email/password), role read from `facility_members`.
- Live floor view: one card/row per resident (not one global incident
  list) — pulls `incident_events` filtered/grouped by `resident_id`, live via
  Supabase Realtime subscription.
- Response-time metric: avg `acknowledged_at - detected_at` per shift,
  computed from the incident query result.
- Visitor observation timeline: `visitor_face_observations` list,
  metadata only (`match_status`, `camera_id`, `detected_at`,
  `quality_score`) — never renders embeddings or claims an identity.
- Resident detail page: profile (from `resident_profiles`) + that
  resident's own incident history and visitor activity, keeping the "each
  elder has their own record" separation even though it's one facility/hub.
- Incident detail: acknowledge/resolve buttons call the
  `respond_to_incident` RPC (admin/caregiver/owner only, enforced by RLS +
  UI role check).

## Mobile (`mobile/`, Expo/React Native)

- Single Expo app; after Supabase Auth login, role determines view mode:
  - **Care** (caregiver/admin/owner): realtime alert feed grouped by
    resident, acknowledge/resolve, resident list with profiles.
  - **Family** (family role): daily summary per linked resident (derived
    from that resident's incident/visitor activity), emergency
    push/notification banner on critical incidents with resolution
    follow-up text, visitor log as a generic count/timeline only (no
    images, no "unknown" framing beyond what PRD allows) — no live video
    anywhere in either mode.
- Supabase JS client + realtime subscription for the alert feed.
- Push notifications via Expo push service for critical incidents. Real
  APNs/production push credentials aren't available in this environment —
  implemented against Expo's push API and documented as needing real device
  testing by Dhairya.

## Non-Goals (explicitly out of scope for this pass)

- Real SMS delivery (Twilio) — `notify-family` is a stub interface only.
- Predictive fall-risk scoring, shift handoff auto-summary (P1/roadmap).
- Data retention/cleanup jobs, exportable audit trail (P1/roadmap).
- Facility onboarding UI — demo facility/cameras/residents are seeded via
  SQL, not created through a UI flow.
- iOS Simulator / real-device testing — verified via `expo start --web`
  and Supabase-side smoke tests only, since this machine has no Xcode.

## Testing Approach

- New migration: SQL applies cleanly against a local/dev Supabase instance
  (or via `supabase db lint`/dry-run if no live DB access); RLS behavior
  spot-checked with representative `auth.uid()` values per role, following
  whatever pattern the existing migration/tests already use in `tests/`.
- `respond_to_incident` RPC and `notify-family`: Deno tests colocated with
  the Edge Functions, matching the existing `ingest-event`/`ingest-visitor-face`
  test style.
- Dashboard: run locally, click through login → floor view → resident
  detail → acknowledge/resolve → confirm visitor timeline renders
  metadata only.
- Mobile: `expo start --web` smoke test of login → Care view alert feed →
  acknowledge → Family view daily summary, since no simulator is available
  here.
