# Realtime Channels

Meridian's live feeds use Supabase Realtime's Postgres Changes feature —
subscribe directly to table changes, filtered server-side by RLS (the
same policies documented in api-contract.md apply to realtime payloads:
a `family`-role session will not receive `incident_events` change events
at all, since that role has no select policy on the base table — build
the Family app's live updates against a poll/refetch of
`family_incident_feed` instead of a raw subscription, since Supabase
Realtime does not support subscribing to a *view*).

| Channel | Table | Who subscribes | Payload use |
| --- | --- | --- | --- |
| `incident-events-<facility_id>` | `incident_events`, filter `facility_id=eq.<id>` | Insights dashboard, Care app (owner/admin/caregiver/viewer) | New/updated incident → refresh floor view / alert feed. |
| `notifications-<facility_id>` | `notifications`, filter `facility_id=eq.<id>` | Insights dashboard (audit trail), Care app (new-visitor banner: filter client-side for `resident_id is null`) | New row → notification was queued; `status` flips `pending`→`sent` once `notify-family` processes it. Rows come from two sources now: `respond_to_incident` (incident-linked, `incident_id` set) and the `notify_visitor_arrival` trigger (visitor-linked, `incident_id` null). |

MeridianHub polls its three resident-safe views every 10 seconds rather than
subscribing to raw rows. This is intentional: its security boundary is the
`resident_hub_devices` JWT mapping, and polling first calls the expiry RPC so
an unanswered visitor prompt becomes `no_response` on the server before it is
shown. The status surface then reflects actual `assistance_requests` transitions
(`open` → `acknowledged` → `en_route` → `resolved`), never a local timer.

For the Family app: since it can't subscribe to `incident_events`
directly (no RLS access) or to a view (Realtime limitation), poll
`family_incident_feed` and `notifications` (filtered to the signed-in
family user's linked resident) on an interval — every 15-30s is enough
for a daily-summary-style app and avoids needing a realtime channel at
all for that role.
