# Backend smoke test (run once real Supabase credentials are available)

This checklist can't be executed from the dev environment that wrote it —
there's no `supabase` CLI, `docker`, or `psql` available there, so nothing
in `supabase/migrations/` or `supabase/functions/notify-family/` has
touched a live database yet. Run this once whoever holds the project's
`SUPABASE_ACCESS_TOKEN`/DB password has applied the migrations, and again
before the pitch demo.

Prerequisites: `supabase` CLI logged in, migrations applied
(`supabase db push`), demo seed run per `supabase/seed/README.md`.

1. **RLS isolation across facilities.** Create a second facility
   (`fac-other-001`) with its own member. Confirm that member's session
   gets zero rows from `select * from facility_floor_view` and
   `select * from incident_events where facility_id = 'fac-demo-001'`.
2. **Floor view reflects seed data.** As the demo `caregiver` user,
   `select * from facility_floor_view` returns 2 rows (Maggie, Walter);
   Maggie's row shows `open_incident_status = 'open'` for
   `demo-evt-open-1`.
3. **respond_to_incident lifecycle.** As the demo `caregiver` user, call
   `rpc('respond_to_incident', { p_incident_id: <demo-evt-open-1's id>, p_new_status: 'acknowledged' })`.
   Confirm the returned row has `acknowledged_by` = that user's id and
   `acknowledged_at` set. Call again with `p_new_status: 'resolved'` and
   confirm `resolved_by`/`resolved_at` set and a new row appears in
   `notifications` with `status = 'pending'`.
4. **Invalid transition rejected.** Call `respond_to_incident` on the
   same now-`resolved` incident again with `p_new_status: 'acknowledged'`;
   confirm it raises `invalid_transition`.
5. **Direct status update blocked.** As the demo `caregiver` user, run
   `update incident_events set status = 'resolved' where id = ...`
   directly (not via RPC); confirm it fails with a permission error
   (the column privilege was revoked in the lifecycle migration).
6. **notify-family drains the queue.** Invoke the `notify-family`
   function with the `x-internal-secret` header set to
   `MERIDIAN_INTERNAL_FUNCTION_SECRET`. Confirm the pending notification
   from step 3 flips to `status = 'sent'` with a `sent_at` timestamp, and
   the function logs the stub-send line.
7. **Family isolation.** As the demo `family` user, confirm
   `select * from family_incident_feed` returns only Maggie's incidents
   (not Walter's), and `select * from incident_events` (raw table)
   returns zero rows (blocked by RLS).
8. **Family visitor feed respects consent.** As the demo `family` user,
   confirm `select * from family_visitor_feed` returns the seeded visitor
   row (Maggie has an active `family_visibility` consent). Revoke that
   consent (`update person_consents set consent_status = 'revoked' ...`)
   and confirm the same query now returns zero rows.
9. **No evidence leakage.** Grep the JSON result of every family-role
   query above for `ciphertext`, `embedding`, `nonce`, and `_path` —
   none should appear.
