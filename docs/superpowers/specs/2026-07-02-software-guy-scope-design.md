# Meridian Software Scope (Dhairya's part) — Design

Date: 2026-07-02
Status: Approved for planning

## Goal

Build the **backend only** for the software side of Meridian per `PRD.md`
and `softwareguytodo.md`: a complete, coherent Supabase backend (schema,
RLS, RPCs, Edge Functions) plus a documented API contract, for the
Meridian Care app, Meridian Family app, and Meridian Insights dashboard.
All UI/frontend is owned by the front-end guy — nothing in this scope
renders a screen. Scope is bounded to what's needed for a live 2-camera,
2-resident demo, not full production coverage.

**Coherence requirement:** the backend must model one real product
lifecycle end to end, not a grab-bag of isolated tables. A person walks
through the system in this order, and the schema/RPCs must support that
order without gaps or dead ends:

1. A facility exists, has members with roles, has cameras, has residents
   with profiles and consent on file.
2. The Hub emits an event (fall, visitor arrival, etc.) → it lands as an
   `incident_events` or `visitor_face_observations` row, scoped to a
   facility, camera, and resident.
3. A caregiver (via Care app) sees it in their live feed, acknowledges it,
   resolves it — each transition is a real, server-verified state change
   with an actor and a timestamp, not a client-asserted flag.
4. That resolution is what triggers the family notification — the family
   app has nothing to poll for until the caregiver has actually acted, so
   the "Staff reached her in 90 seconds" copy in the PRD is backed by real
   data, not a fabricated field.
5. Everything a dashboard or app screen needs (floor view, response-time
   metric, resident detail, visitor timeline, family daily summary) must
   be answerable by a single documented query/view/RPC — the front-end
   guy should never have to reverse-engineer a join across raw tables to
   build a PRD-described screen.

## Directory Layout

New top-level directory `meridian_software/`:

```
meridian_software/
  shared/    # TypeScript types mirroring the Supabase schema + event contract
  docs/      # API contract: endpoints, RPC signatures, realtime channels, screen-to-query mapping
```

No `insights-dashboard/` or `mobile/` app code — those are the front-end
guy's. Backend changes themselves stay in the existing `supabase/` folder
(new migration + edits to existing Edge Functions) since that's where
schema/RLS/functions already live.

## Backend (extend existing Supabase scaffold)

New migration on top of `20260702220000_initial_security_and_ingest.sql`:

- Add `'family'` to the `facility_members.role` check constraint.
- New `family_member_links` table: `facility_id`, `user_id`, `resident_id`
  — a family account only ever sees data for its linked resident(s).
- New `resident_profiles` table: `id`, `facility_id`, `person_id` (FK to
  `people`), `display_name`, `room_id`, `risk_flags jsonb`, `care_notes
  text`, `created_at`/`updated_at`. This is the caregiver-facing profile;
  `people` remains the identity/recognition record. Every incident and
  visitor observation resolves to a `resident_profiles` row, so each
  elder's activity is queryable as its own record even though it's one
  facility/hub.
- Incident lifecycle columns on `incident_events`: `acknowledged_by`,
  `acknowledged_at`, `resolved_by`, `resolved_at`, `resolution_note`.
- New RPC `respond_to_incident(incident_id, new_status, note)` — validates
  caller is a facility member with role in (`owner`,`admin`,`caregiver`),
  stamps `acknowledged_by`/`acknowledged_at` or `resolved_by`/`resolved_at`
  from `auth.uid()` and `now()` server-side (never trusts a client-supplied
  actor/timestamp), and enforces the status transition
  (`open`→`acknowledged`→`responding`→`resolved`, or
  `dismissed_false_alarm`/`escalated` from any open state). This is the
  single write path for incident state — no other function or policy
  allows a status change, so "who responded and how fast" is always real.
- `notifications` table (`facility_id`, `resident_id`, `incident_id`,
  `channel`, `body`, `status`, `created_at`, `sent_at`) — the durable
  record of what a family was told and when, so the family app's feed and
  the dashboard's audit trail read from the same source of truth.
- New Edge Function `notify-family`: called by `respond_to_incident` (via
  direct invocation, not a webhook, to keep the demo simple and
  synchronous) when an incident reaches `acknowledged` or `resolved` at
  severity ≥ `warning`. Writes a `notifications` row and calls a
  `sendSms(to, body)` stub (logs only — see Non-Goals) behind an interface
  the front-end guy or a later pass can swap for real Twilio.
- RLS: extend `incident_events` and `visitor_face_observations` read
  access so a `family` role only sees rows for residents in their
  `family_member_links`, via two views (`family_incident_feed`,
  `family_visitor_feed`) that omit `encrypted_evidence_path`,
  `face_embedding_*`, and `encrypted_face_image_path` entirely — families
  can never reach evidence paths, even indirectly.
- Read-optimized views for the documented screen contract (see API
  contract below): `facility_floor_view` (one row per resident: latest
  open incident, room, risk flags), `facility_response_metrics` (avg
  acknowledge latency per shift window), `resident_activity_view` (a
  resident's incidents + visitor observations, one query).
- Seed script `supabase/seed/demo_two_room_seed.sql`: 1 facility, 2
  cameras, 2 `people` rows (residents) + matching `resident_profiles`, one
  `person_consents` row per resident (monitoring + family_visibility),
  demo `facility_members` rows for an owner/caregiver/family test user
  each (referencing pre-created `auth.users` — documented as a manual
  step since seeding `auth.users` needs the Supabase Auth API, not raw
  SQL), and 2-3 sample `incident_events` in different lifecycle states so
  the front-end guy has real acknowledge/resolve data to build against
  immediately.

## API Contract Package (`meridian_software/shared/` + `meridian_software/docs/`)

- `shared/types.ts`: TypeScript types generated/hand-mirrored from the
  schema (tables + views + RPC argument/return shapes) — single source of
  truth the front-end guy imports instead of re-deriving types from raw
  SQL.
- `docs/api-contract.md`: for each PRD-described screen (Care alert feed,
  resident profile, Family daily summary, Insights floor view,
  response-time analytics, visitor timeline), the exact
  table/view/RPC/realtime-channel to use, expected shape, and which role
  can call it. This is the walkthrough that keeps the two sides of the
  team in sync without either side reading the other's code.
- `docs/realtime-channels.md`: which Supabase Realtime channels/tables to
  subscribe to for live updates (incident feed, notifications), and what
  payload to expect.

## Non-Goals (explicitly out of scope for this pass)

- Any UI/frontend code (Next.js dashboard, Expo/React Native app) — owned
  by the front-end guy.
- Real SMS delivery (Twilio) — `notify-family`'s `sendSms()` is a stub
  interface only.
- Predictive fall-risk scoring, shift handoff auto-summary (P1/roadmap).
- Data retention/cleanup jobs, exportable audit trail (P1/roadmap).
- Facility onboarding flow — demo facility/cameras/residents are seeded
  via SQL, not created through any flow.
- Push notification service wiring (Expo/APNs) — that's mobile-app-side,
  front-end guy's responsibility; `notifications` table gives them
  something to build push off of.

## Testing Approach

- New migration: SQL applies cleanly against a local/dev Supabase instance
  (or via `supabase db lint`/dry-run if no live DB access); RLS behavior
  spot-checked with representative `auth.uid()` values per role
  (owner/admin/caregiver/viewer/family), following whatever pattern the
  existing migration/tests already use in `tests/`.
- `respond_to_incident` RPC and `notify-family`: Deno tests colocated with
  the Edge Functions, matching the existing
  `ingest-event`/`ingest-visitor-face` test style — cover the full
  lifecycle (open → acknowledged → resolved), invalid transitions
  rejected, family notification only fires at the right severity/status,
  family views never leak evidence columns.
- Seed script + views: a smoke script that seeds the demo data, then
  queries each of `facility_floor_view`, `facility_response_metrics`,
  `resident_activity_view`, `family_incident_feed`, `family_visitor_feed`
  and asserts the shape/row counts match what's documented in
  `api-contract.md` — this is the check that the backend is actually
  demo-ready end to end, not just schema-valid.
