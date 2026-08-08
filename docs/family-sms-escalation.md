# Family emergency SMS escalation

MeridianFamily remains push/in-app first. SMS is a deliberately narrow backup
channel for a **critical incident that staff have not acknowledged**. It is not
used for daily summaries, visitor updates, warning-level incidents, resolution
updates, or ordinary app notifications. This preserves the 17a60d4 decision to
avoid treating SMS as the default notification transport while covering the
real failure case: a family phone is locked, the app is absent, or push was
suppressed during an unacknowledged emergency.

## Rule and guardrails

The database is the authority, not a client clock. On each authenticated
`notify-family` worker run, `queue_family_sms_escalations()` selects an incident
only when all of these hold:

1. It is `critical`, `open` (or already `escalated`), has a resident, and has
   neither `acknowledged_at` nor `resolved_at`.
2. It has remained so for the facility's delay. The default is **300 seconds
   (five minutes)**; a facility owner/admin can set 60–900 seconds in
   `facility_sms_escalation_policies`. Five minutes gives on-site care staff a
   realistic chance to acknowledge a midnight fall before waking family, while
   still making the missed-alert fallback prompt.
3. The exact linked family account has an active, explicit phone opt-in.
4. The resident's existing `family_visibility` consent is active; a family
   link alone is not permission to reveal an emergency over a new channel.
5. There is no existing `(incident_id, preference_id)` escalation and that
   recipient has not exhausted the facility's fixed 24-hour rate window
   (default three reservations, configurable 1–10).

Quiet hours intentionally do **not** apply to this path: a late critical,
unacknowledged fall is exactly when a fallback channel is needed. Non-critical
messages never enter this queue, so they remain quiet-hour/push product work,
not SMS exceptions.

The unique escalation row is the idempotency key. Claiming it writes a delivery
attempt before Twilio is called. Network uncertainty becomes
`unknown_outcome`, never an automatic retry, because retrying after a timeout
could send two emergency texts. A failed/unknown attempt must be reconciled
from Twilio's message logs before any manual follow-up. The recipient rate
reservation also prevents a flapping sensor from generating a text burst.

## Consent and audit model

`family_sms_preferences` is per `family_member_links` relationship and stores
an E.164 number, consent text version/source, opt-in time, and revocation time.
The security-definer `set_my_family_sms_consent` RPC is the only family write
path. It validates the signed-in user's resident link, requires an explicit
source and consent-version on opt-in, and never edits or deletes old consent:
revocation changes the active row to `revoked`; later opt-in creates a new row.

Each transition is written to immutable `family_sms_consent_events`. A claim
checks active consent a second time; if consent was revoked after queueing, the
escalation is recorded as `suppressed_consent_revoked`, not sent. Family users
can read their own consent/audit history; facility owners/admins can audit it.
The worker also rechecks the resident's `family_visibility` consent at claim
time and records `suppressed_resident_visibility_revoked` if it changed.

`family_sms_escalations` records the durable decision and
`family_sms_delivery_attempts` records the Twilio SID, provider status, error,
and terminal delivery state. Twilio status callbacks update `delivered`,
`undelivered`, or `failed`; an accepted-but-not-yet-callbacked send stays
`provider_accepted` rather than being falsely claimed as delivered.

## Deployment

1. Apply `20260807000100_family_sms_escalation.sql` to the Supabase project
   after all earlier migrations. Do not edit or re-run deployed migrations.
2. Deploy `notify-family`. Arrange a trusted scheduler to POST it at least once
   per minute with `x-internal-secret`; that frequency bounds practical
   escalation delay to the configured threshold plus one minute. Use the same
   scheduler for the existing in-app notification queue.
3. Set these **Supabase Edge Function secrets**, never repository values:

   - `SUPABASE_URL`
   - `MERIDIAN_SUPABASE_SERVICE_ROLE_KEY` (or the existing supported service
     key fallback)
   - `MERIDIAN_INTERNAL_FUNCTION_SECRET`
   - `TWILIO_ACCOUNT_SID`
   - `TWILIO_AUTH_TOKEN`
   - `TWILIO_FROM_NUMBER` (a Twilio SMS-capable E.164 sender)
   - `MERIDIAN_SMS_STATUS_CALLBACK_URL`, exactly the deployed
     `notify-family` endpoint followed by `?twilio_status=1`

4. In Twilio, use that same callback URL for message status callbacks. The
   Edge Function validates Twilio's `X-Twilio-Signature` using
   `TWILIO_AUTH_TOKEN`; do not put the internal worker secret in the callback
   URL. Configure the Twilio sender and opt-in language for the facility's
   jurisdiction and messaging use case before enabling SMS.
5. Have a linked family user call `set_my_family_sms_consent` with an E.164
   number, an actual consent source, and the released consent text version.
   Verify a row and an `opted_in` audit event, then set a facility policy if the
   default five-minute/three-per-24-hour limits are unsuitable.

If Twilio configuration is missing, the function still processes normal
in-app notifications. Claimed SMS rows become visible `failed` attempts with
`provider_not_configured`; no fallback text is simulated or silently marked
sent.

## Verification boundary

`tests/test_family_sms_escalation.py` executes the decision contract for
missing/revoked consent, acknowledgement, the threshold, idempotency after a
failed attempt, rate limiting, and quiet-hours emergency behavior.
`tests/test_supabase_migrations.py` parses the additive migration and verifies
its tables/functions exist in the SQL AST.

This machine has no Docker, Supabase CLI, PostgreSQL client, Deno runtime, live
Supabase project access, or Twilio account. It could **not** execute the SQL,
exercise RLS/locking/RPCs, invoke the Edge Function, send an SMS, validate a
Twilio signature against a real callback, or observe final carrier delivery.
Those are required pre-demo deployment checks; until they pass, do not claim
live SMS delivery has been demonstrated.
