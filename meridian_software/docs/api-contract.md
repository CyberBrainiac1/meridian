# Meridian Backend API Contract

For each PRD-described screen: which table/view/RPC to query, who can
call it, and what it returns. All types referenced here live in
`meridian_software/shared/types.ts` — import from there, don't
hand-derive types from the SQL.

Every query goes through the Supabase JS client, authenticated with the
signed-in user's session (never the service-role key from an app).

## Meridian Insights (facility dashboard — owner/admin/caregiver/viewer)

| Screen | Source | Notes |
| --- | --- | --- |
| Live floor view | `select * from facility_floor_view` | One row per resident. `open_incident_*` is null when nothing's open. Subscribe to `incident_events` (see realtime-channels.md) to refresh live. |
| Response-time analytics | `select * from facility_response_metrics order by shift_date desc` | `avg_ack_seconds` is null for a shift with zero acknowledged incidents. |
| Resident detail | `select * from resident_activity_view where resident_id = :id order by detected_at desc` | Incident history for one resident. |
| Visitor observation timeline | `select facility_id, camera_id, match_status, detected_at, quality_score, matched_person_id, body_description, body_description_model, body_description_generated_at from visitor_face_observations where facility_id = :id order by detected_at desc` | Never select `face_embedding_*`, `person_photo_*`, or `encrypted_face_image_path` into ordinary UI-bound queries — those exist for the encryption/evidence pipeline, not display. |
| Acknowledge / resolve an incident | `rpc('respond_to_incident', { p_incident_id, p_new_status, p_note })` | Only path that changes `incident_events.status`. Throws `not_authorized` (Postgres error code 42501) if the caller isn't owner/admin/caregiver at that facility, `invalid_transition` (22023) on an illegal status change. |

## Meridian Care (caregiver app — owner/admin/caregiver)

| Screen | Source | Notes |
| --- | --- | --- |
| Live alert feed | `select * from incident_events where facility_id = :id and status in ('open','acknowledged','responding') order by detected_at desc` | Realtime-subscribe to `incident_events` for push-like updates. |
| Acknowledge/resolve | same `respond_to_incident` RPC as above | |
| Resident profiles | `select * from resident_profiles where facility_id = :id` | |
| New-visitor push/banner | `select * from notifications where facility_id = :id and resident_id is null order by created_at desc` | Every `new_visitor`/`unknown` face at an entry camera auto-inserts one of these (see `notify_visitor_arrival` trigger) — you don't need to poll `visitor_face_observations` yourself to catch new arrivals, this table is the alert surface. Realtime-subscribe to `notifications` filtered by `facility_id` for a live banner. |

## Meridian Family (family app — family role only)

| Screen | Source | Notes |
| --- | --- | --- |
| Daily summary / alert feed | `select * from family_incident_feed order by detected_at desc` | Already scoped server-side to the caller's linked resident(s) — do not add a `resident_id` filter expecting it to restrict further access; the view's own `where exists (...)` against `family_member_links` is the actual security boundary. |
| Visitor log (generic) | `select * from family_visitor_feed order by detected_at desc` | Only returns rows if the linked resident has an active `family_visibility` consent — an empty result is expected/valid, not an error. Copy should read as a count/timeline ("3 visitors today"), never a name — the view has no name column, so this is structurally enforced. |
| New-visitor notification | `select body, created_at, sent_at from notifications where resident_id = :linked_resident_id order by created_at desc` | Same table/query shape as the "staff responded" follow-up below — a family user's `notifications` feed mixes incident-response updates and new-visitor alerts for their linked resident's facility; use `incident_id is not null` vs `is null` to tell them apart in the UI if you want separate sections. |
| "Staff reached her in 90 seconds" follow-up copy | `select body, created_at, sent_at from notifications where resident_id = :linked_resident_id order by created_at desc` | Populated by `respond_to_incident` → written by `notify-family`, see realtime-channels.md for how to know when a new one lands. |

## Roles reference

| Role | Can do |
| --- | --- |
| `owner` / `admin` | Everything caregiver can, plus manage `resident_profiles`, `family_member_links`, `person_consents`. |
| `caregiver` | Read facility incidents/residents/visitor observations, call `respond_to_incident`. |
| `viewer` | Read-only version of caregiver (dashboard-only role, e.g. an ops observer). |
| `family` | Read only `family_incident_feed` / `family_visitor_feed` / their own `notifications` rows, scoped to their linked resident(s) via `family_member_links`. Never reaches raw `incident_events`, `visitor_face_observations`, or any evidence/embedding column. |

## Real product lifecycle this backend enforces

This isn't a grab-bag of tables — every screen above is a step in one
real flow, and the backend enforces the order:

1. Facility, cameras, residents, and consent exist first (seeded for the
   demo, normally created through an onboarding process).
2. The Hub emits an event → lands in `incident_events` or
   `visitor_face_observations`, always scoped to `facility_id` and
   (for incidents) `resident_id`.
3. A caregiver acknowledges/resolves via `respond_to_incident` — the only
   write path, so `acknowledged_by`/`resolved_by`/`*_at` are always real
   (server-stamped from the session, never client-supplied).
4. That resolution — not a client action — is what inserts a row into
   `notifications`, which `notify-family` then delivers. The family app
   has nothing to show until a caregiver has actually responded. The same
   is true for visitor arrivals: a new/unknown face at an entry camera
   auto-inserts `notifications` rows (one for the care team, one per
   consented family link) via a database trigger, not an app-side call —
   no ingestion path can forget to notify.
5. Every screen reads from a single documented view/table, never a
   hand-joined query across raw tables.
