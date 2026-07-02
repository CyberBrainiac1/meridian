# Front-End Guy Todo

Owner assumption: you own all UI/UX for Meridian Care (caregiver app),
Meridian Family (family app), and Meridian Insights (facility dashboard).
The backend (Supabase schema, RLS, RPCs, Edge Functions) is done and
described for you in `meridian_software/docs/api-contract.md` and
`meridian_software/docs/realtime-channels.md` — read those two files
first, they tell you exactly which table/view/RPC to call for every
screen. `meridian_software/shared/types.ts` has the TypeScript types to
import instead of guessing shapes from SQL.

Nothing here has been applied to a live Supabase project yet — the dev
environment that built it has no `supabase` CLI/Docker/psql. Someone with
the project's real keys needs to run `supabase db push` and
`supabase/seed/demo_two_room_seed.sql` before any of this is queryable.
Ping in the shared chat once that's done so this list can be de-blocked.

## Before you start

- [ ] Read `meridian_software/docs/api-contract.md` end to end — it maps
      every PRD screen to the exact backend call.
- [ ] Read `meridian_software/docs/realtime-channels.md` — Family app
      cannot subscribe to `incident_events` directly (no RLS access) or
      to a view (Realtime limitation); it must poll instead.
- [ ] Import types from `meridian_software/shared/types.ts`, don't
      hand-derive them from migrations.
- [ ] Get the Supabase project URL + anon key (never the service-role
      key) for client-side auth. Ask in chat once the project is live.

## Meridian Insights (facility dashboard)

- [ ] Auth screen: Supabase Auth email/password sign-in.
- [ ] Live floor view: `select * from facility_floor_view`, one
      card/row per resident, not a single merged incident list.
- [ ] Response-time analytics: `select * from facility_response_metrics
      order by shift_date desc`, grouped by shift (night/day/evening).
      `avg_ack_seconds` is null for a shift with nothing acknowledged —
      handle that as "no data," not an error.
- [ ] Resident detail page: `select * from resident_activity_view where
      resident_id = :id`, that resident's own incident history.
- [ ] Visitor observation timeline: query `visitor_face_observations`
      directly (metadata columns only — see api-contract.md for the
      exact column list). Copy must read "New visitor detected at Main
      Entrance," never a name or "unknown person identified."
- [ ] Incident detail screen: acknowledge/resolve buttons call
      `rpc('respond_to_incident', { p_incident_id, p_new_status, p_note })`.
      Handle `not_authorized` and `invalid_transition` errors with real
      UI states, not a generic failure toast.
- [ ] Realtime refresh: subscribe to `incident_events` filtered by
      `facility_id` to update the floor view/alert feed live.

## Meridian Care (caregiver app)

- [ ] Auth + role gate: only owner/admin/caregiver see this app's full
      feature set.
- [ ] Live alert feed: incidents with `status in ('open','acknowledged',
      'responding')`, ordered by `detected_at desc`, grouped by resident.
- [ ] Acknowledge/resolve flow: same `respond_to_incident` RPC as above.
      This is the only write path for incident status — do not attempt a
      direct `update incident_events set status = ...`, it's blocked.
- [ ] Resident profiles screen: `select * from resident_profiles where
      facility_id = :id`.
- [ ] Copy rule from the PRD: "Maggie needs help in Room 12," never
      "Event #4471 triggered." The `summary` field on incidents already
      follows this pattern in the seed data — match its tone.
- [ ] No live video anywhere in this app.

## Meridian Family (family app)

- [ ] Auth + role gate: family role only.
- [ ] Daily summary / alert feed: `select * from family_incident_feed
      order by detected_at desc`. This view is already scoped server-side
      to the signed-in user's linked resident(s) — don't add a
      `resident_id` filter expecting it to restrict access further, it's
      not the security boundary, `family_member_links` is.
- [ ] Visitor log: `select * from family_visitor_feed order by
      detected_at desc`. An empty result is expected/valid (no active
      `family_visibility` consent yet), not an error state. Show a
      count/timeline ("3 visitors today"), never a name — the view has no
      name column, so don't try to join one in.
- [ ] "Staff reached her in 90 seconds" follow-up copy: `select body,
      created_at, sent_at from notifications where resident_id =
      :linked_resident_id order by created_at desc`.
- [ ] Live updates: poll `family_incident_feed` + `notifications` every
      15-30s. No realtime subscription for this role (see
      realtime-channels.md for why).
- [ ] Push notifications: `notifications` rows are the source of truth
      for what to alert on. Wiring real push (Expo/APNs) is on you — the
      backend only guarantees the row exists and flips `pending` →
      `sent`.
- [ ] No live video anywhere in this app.

## Things you should NOT build

- [ ] No facility onboarding UI — demo facility/cameras/residents are
      seeded via SQL for now (`supabase/seed/`).
- [ ] No direct writes to `incident_events`, `visitor_face_observations`,
      `person_consents`, or `facility_members` from any app — those are
      either read-only from the client or owner/admin-managed later.
- [ ] No rendering of `face_embedding_*`, `encrypted_face_image_path`, or
      `encrypted_evidence_path` values anywhere in any UI, even for
      debugging.
- [ ] No screen that names or shows an unknown/new visitor as an
      identified person.
