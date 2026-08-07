# MeridianHub — implemented resident surface

MeridianHub is now a real, room-bound product surface, not a deck mock. It is
the standalone Next.js app in `meridian_hub_ui/`, backed by
`20260807000000_meridian_hub_resident_surface.sql` and the existing durable Hub
delivery queue.

## What is built

- Residents can create `assistance`, `family_contact`, and `emergency`
  `assistance_requests` through a security-definer RPC. The request's facility,
  resident, and room come from the authenticated device mapping, never from a
  browser parameter.
- A new `fall_confirmed` `incident_events` row creates exactly one
  `auto_fall_dispatch` emergency request through an idempotent database trigger.
  This inserts the same care-team notification as a resident request, so the
  resident can see a real help request before pressing anything.
- Care staff control the only legal dispatch transitions: `open` →
  `acknowledged` → `en_route` → `resolved`; cancellation is possible only
  before en route. Each transition writes the authenticated actor and server
  timestamp. Direct client status updates are not granted.
- Unknown/new encrypted `visitor_face_observations` create a two-minute,
  resident-safe `visitor_verification_prompt` only for the active Hub mapped to
  that observation's entry camera. The Hub sees only the description, time,
  and camera ID. It never gets face ciphertext, encrypted images, embeddings,
  digests, nonces, or key IDs. A denied answer inserts a care-team notification.
- The Hub UI has large touch targets, solid WCAG-AA-or-better token colors,
  keyboard focus visibility, reduced-motion support, explicit offline failure
  messaging, help status, and the three requested actions plus emergency.

## Auth and RLS model

Each physical device has one dedicated Supabase Auth user in
`resident_hub_devices`. An active mapping is unique per Hub user and resident,
and is validated against the resident profile's facility and room plus its
optional entry camera. It is intentionally separate from `facility_members`
and `family_member_links`.

The UI has direct read access only to `resident_hub_profile`,
`resident_hub_assistance_feed`, and `resident_hub_visitor_prompt_feed`. Each
view gates on `auth.uid()` and the active device mapping. Raw Hub tables have no
authenticated grant; policies are still included as defense in depth. This
means a compromised room-101 JWT cannot select, request for, answer for, or
learn from room 102.

## ETA semantics

`estimate_assistance_eta` calculates the average acknowledged-incident latency
for the preceding 30 days, clamped to 30–1800 seconds to avoid pathological
outliers. Five or more samples return `data_derived`; one to four returns
`limited_history`; no history returns a clearly labelled conservative
five-minute `facility_default`. It is not a fabricated 60-second promise. The
app explains the confidence beside every active request.

## Edge delivery

`HubDeliveryQueue` writes endpoint-tagged envelopes into the existing SQLite
`QueueStore`. Confirmed fall events route to `ingest-event`; encrypted unknown
visitor observations route to `ingest-visitor-face`. `NotificationDispatcher`
unwraps and delivers those routes only after a successful response, preserving
the old incident route for pre-existing queue entries. `UnknownVisitorReporter`
is the dependency-injected final hop after the existing encrypted observation
builder; known visitors do not enter the resident-prompt path.

## Verification and limits

- Python baseline: 170 tests passed before this work. `python -m pytest -q`
  now passes **186/186** tests, including durable routing, every-migration
  parsing, claimed-table AST assertions, and a computed WCAG contrast test for
  the Hub's body and control color pairs.
- `tests/test_supabase_migrations.py` parses **every** migration with SQLGlot's
  PostgreSQL dialect and asserts the three MeridianHub tables exist in the AST.
  SQLGlot represents unsupported PostgreSQL policy/function syntax as command
  nodes, but raises on a malformed migration; table creation is AST-asserted.
- `test_resident_hub_views_never_expose_face_crypto_material` enforces the
  privacy boundary at the least-trusted screen in the building: the resident's
  Hub sits in an unlocked room, so its views may expose the caregiver-facing
  description and timing and nothing else. Adding a ciphertext, embedding,
  digest, nonce or key-id column to a `resident_hub_*` view fails the suite.
  Both this guard and the frame-leak guard in `tests/test_claim_guards.py` have
  been mutation-tested — a deliberately injected leak makes each one fail.

### A note on the SQL static check

SQLGlot's PostgreSQL dialect cannot parse `drop trigger ... on public.foo`,
which is valid PostgreSQL and is this repo's house style. The correct response
is to shim the parser (`_parseable()` in `tests/test_supabase_migrations.py`),
**not** to de-qualify the migrations — several are already deployed against the
live project, and rewriting deployed SQL to satisfy a linter would be changing
the artifact to fit the measuring instrument.
`test_migrations_keep_schema_qualified_drop_targets` guards against exactly
that mistake being made later.
- `npm run lint` and `npm run build` in `meridian_hub_ui/` both complete with
  zero errors.

No Docker, Supabase CLI, PostgreSQL client, or Deno runtime is available here,
so this machine cannot execute the migration against a live Supabase project,
exercise actual RLS policies with distinct JWTs, invoke database triggers, or
deliver a notification through an external provider. `notify-family` itself
still explicitly logs a stub provider result rather than placing a real phone
call/push; therefore **Call family** reliably creates the consent-scoped
notification record, but a live external call or push provider remains a
deployment task. The UI states that it asks a family contact to call rather
than claiming it can place a telephone call directly.
