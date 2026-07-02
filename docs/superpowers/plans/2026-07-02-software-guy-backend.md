# Meridian Software Backend (P0 demo) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing Supabase backend so it supports the full P0
incident lifecycle (open → acknowledged → resolved, family notification,
family/caregiver data separation per resident) and ship a documented API
contract package for the front-end engineer, with no UI code.

**Architecture:** One new migration on top of
`20260702220000_initial_security_and_ingest.sql` adds resident profiles,
family linkage, incident lifecycle columns, a `notifications` table, a
single RPC (`respond_to_incident`) as the only write path for incident
status, and five read views that map 1:1 to PRD-described screens. A new
`notify-family` Edge Function drains pending notifications through a
swappable stub SMS interface. A seed script populates one demo facility
with 2 cameras/2 residents. `meridian_software/shared/` and
`meridian_software/docs/` give the front-end engineer types and a
screen-to-query contract instead of raw SQL to reverse-engineer.

**Tech Stack:** Supabase Postgres (SQL migrations, RLS, plpgsql), Deno
(Edge Functions, `npx -y deno` for local test runs), TypeScript (shared
types package, no framework).

**Environment note:** This machine has no `supabase` CLI, `docker`, or
`psql` installed, so migrations cannot be applied to a live database from
here. `npx -y deno` **is** available and used for Edge Function tests.
Every SQL task below is verified by careful manual review against the
existing migration's proven patterns (same file) rather than execution;
applying the migration to the real project (`supabase db push` or the
Supabase SQL editor) is a follow-up step once Pranav/Dhairya have the
project's `SUPABASE_ACCESS_TOKEN`/DB password, which are not available in
this session.

---

### Task 1: Migration — resident profiles, family linkage, incident lifecycle, notifications

**Files:**
- Create: `supabase/migrations/20260703000000_care_lifecycle_and_family.sql`

- [ ] **Step 1: Write the migration file**

```sql
-- Extends 20260702220000_initial_security_and_ingest.sql with:
--   * a 'family' facility_members role
--   * resident_profiles (caregiver-facing profile per resident)
--   * family_member_links (which family users see which resident)
--   * incident_events lifecycle columns (acknowledged/resolved actor+time)
--   * notifications (durable record of what a family was told and when)
-- All new tables get RLS enabled and locked to facility membership.

alter table public.facility_members drop constraint if exists facility_members_role_check;
alter table public.facility_members add constraint facility_members_role_check
    check (role in ('owner', 'admin', 'caregiver', 'viewer', 'family'));

create table if not exists public.resident_profiles (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    person_id text not null references public.people(id) on delete cascade,
    room_id text,
    display_name text not null,
    risk_flags jsonb not null default '[]'::jsonb,
    care_notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (person_id)
);

create table if not exists public.family_member_links (
    facility_id text not null references public.facilities(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (user_id, resident_id)
);

create table if not exists public.notifications (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    resident_id text references public.people(id) on delete set null,
    incident_id uuid references public.incident_events(id) on delete set null,
    channel text not null check (channel in ('sms', 'push')),
    body text not null,
    status text not null default 'pending' check (status in ('pending', 'sent', 'failed')),
    created_at timestamptz not null default now(),
    sent_at timestamptz
);

alter table public.incident_events
    add column if not exists acknowledged_by uuid references auth.users(id) on delete set null,
    add column if not exists acknowledged_at timestamptz,
    add column if not exists resolved_by uuid references auth.users(id) on delete set null,
    add column if not exists resolved_at timestamptz,
    add column if not exists resolution_note text;

create index if not exists resident_profiles_facility_idx
    on public.resident_profiles (facility_id);

create index if not exists family_member_links_resident_idx
    on public.family_member_links (resident_id);

create index if not exists notifications_facility_created_idx
    on public.notifications (facility_id, created_at desc);

create index if not exists notifications_pending_idx
    on public.notifications (status)
    where status = 'pending';

create index if not exists incident_events_resident_idx
    on public.incident_events (resident_id, detected_at desc);

drop trigger if exists set_resident_profiles_updated_at on public.resident_profiles;
create trigger set_resident_profiles_updated_at
before update on public.resident_profiles
for each row execute function public.set_updated_at();

alter table public.resident_profiles enable row level security;
alter table public.family_member_links enable row level security;
alter table public.notifications enable row level security;

revoke all on public.resident_profiles from anon, authenticated;
revoke all on public.family_member_links from anon, authenticated;
revoke all on public.notifications from anon, authenticated;

grant select on public.resident_profiles to authenticated;
grant select on public.family_member_links to authenticated;
grant select on public.notifications to authenticated;

grant all on public.resident_profiles to service_role;
grant all on public.family_member_links to service_role;
grant all on public.notifications to service_role;

-- resident_profiles: care team (not family) reads; owner/admin manage.
drop policy if exists "care team can read resident profiles" on public.resident_profiles;
create policy "care team can read resident profiles"
on public.resident_profiles
for select
to authenticated
using (
    exists (
        select 1 from public.facility_members fm
        where fm.facility_id = resident_profiles.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin', 'caregiver', 'viewer')
    )
);

drop policy if exists "facility admins can manage resident profiles" on public.resident_profiles;
create policy "facility admins can manage resident profiles"
on public.resident_profiles
for all
to authenticated
using (
    exists (
        select 1 from public.facility_members fm
        where fm.facility_id = resident_profiles.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin')
    )
)
with check (
    exists (
        select 1 from public.facility_members fm
        where fm.facility_id = resident_profiles.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin')
    )
);

-- family_member_links: a family user reads only their own link rows.
drop policy if exists "family can read own links" on public.family_member_links;
create policy "family can read own links"
on public.family_member_links
for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "facility admins can manage family links" on public.family_member_links;
create policy "facility admins can manage family links"
on public.family_member_links
for all
to authenticated
using (
    exists (
        select 1 from public.facility_members fm
        where fm.facility_id = family_member_links.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin')
    )
)
with check (
    exists (
        select 1 from public.facility_members fm
        where fm.facility_id = family_member_links.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin')
    )
);

-- notifications: care team reads facility notifications (audit trail);
-- family reads only notifications tied to their own linked resident.
drop policy if exists "care team can read notifications" on public.notifications;
create policy "care team can read notifications"
on public.notifications
for select
to authenticated
using (
    exists (
        select 1 from public.facility_members fm
        where fm.facility_id = notifications.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin', 'caregiver')
    )
);

drop policy if exists "family can read own resident notifications" on public.notifications;
create policy "family can read own resident notifications"
on public.notifications
for select
to authenticated
using (
    notifications.resident_id is not null
    and exists (
        select 1 from public.family_member_links fml
        where fml.resident_id = notifications.resident_id
        and fml.user_id = (select auth.uid())
    )
);

-- Tighten the original incident policy: family must go through
-- family_incident_feed (Task 2), never the raw table, so evidence columns
-- and other-residents' incidents stay out of reach.
drop policy if exists "members can read facility incidents" on public.incident_events;
create policy "members can read facility incidents"
on public.incident_events
for select
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = incident_events.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin', 'caregiver', 'viewer')
    )
);

-- respond_to_incident is the only path that may change incident status;
-- remove the old direct-update grant so writes must go through the RPC.
revoke update (status) on public.incident_events from authenticated;
```

- [ ] **Step 2: Manual review checklist (no live DB in this environment)**

Read the new file back and confirm, line by line:
- Every `create table`/`alter table` matches the naming and constraint
  style of `20260702220000_initial_security_and_ingest.sql` (text PKs use
  the `isMeridianId`-compatible check where relevant, timestamps default
  `now()`, `updated_at` triggers attached).
- Every new table has RLS enabled AND at least one `select` policy AND
  appears in the `revoke`/`grant` block — a table with RLS enabled but no
  policy silently denies all access, which is correct for tables with no
  policy yet, but every table here must have one.
- The `family` role never appears in `role in (...)` lists for
  `resident_profiles`, `incident_events` (base table), or
  `visitor_face_observations` (unchanged, already excludes family) — this
  is the enforcement point for "family only sees their linked resident
  via the dedicated views."

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260703000000_care_lifecycle_and_family.sql
git commit -m "Add resident profiles, family linkage, incident lifecycle, notifications"
```

---

### Task 2: Migration — respond_to_incident RPC and read views

**Files:**
- Create: `supabase/migrations/20260703000100_incident_rpc_and_views.sql`

- [ ] **Step 1: Write the RPC**

```sql
-- Single write path for incident state. Security definer so it can write
-- acknowledged_by/resolved_by/*_at columns that authenticated users have
-- no direct column grant on (see Task 1's revoke), and so it can insert
-- into notifications regardless of the caller's own grants.
create or replace function public.respond_to_incident(
    p_incident_id uuid,
    p_new_status text,
    p_note text default null
)
returns public.incident_events
language plpgsql
security definer
set search_path = public
as $$
declare
    v_incident public.incident_events;
    v_role text;
    v_allowed_next text[];
begin
    select ie.* into v_incident
    from public.incident_events ie
    where ie.id = p_incident_id
    for update;

    if not found then
        raise exception 'incident_not_found' using errcode = 'P0002';
    end if;

    select fm.role into v_role
    from public.facility_members fm
    where fm.facility_id = v_incident.facility_id
    and fm.user_id = auth.uid();

    if v_role is null or v_role not in ('owner', 'admin', 'caregiver') then
        raise exception 'not_authorized' using errcode = '42501';
    end if;

    if p_new_status not in ('acknowledged', 'responding', 'resolved', 'dismissed_false_alarm', 'escalated') then
        raise exception 'invalid_status' using errcode = '22023';
    end if;

    v_allowed_next := case v_incident.status
        when 'open' then array['acknowledged', 'responding', 'resolved', 'dismissed_false_alarm', 'escalated']
        when 'acknowledged' then array['responding', 'resolved', 'dismissed_false_alarm', 'escalated']
        when 'responding' then array['resolved', 'dismissed_false_alarm', 'escalated']
        else array[]::text[]
    end;

    if not (p_new_status = any(v_allowed_next)) then
        raise exception 'invalid_transition' using errcode = '22023';
    end if;

    update public.incident_events
    set status = p_new_status,
        acknowledged_by = coalesce(acknowledged_by, case when p_new_status = 'acknowledged' then auth.uid() else acknowledged_by end),
        acknowledged_at = coalesce(acknowledged_at, case when p_new_status = 'acknowledged' then now() else acknowledged_at end),
        resolved_by = case when p_new_status in ('resolved', 'dismissed_false_alarm') then auth.uid() else resolved_by end,
        resolved_at = case when p_new_status in ('resolved', 'dismissed_false_alarm') then now() else resolved_at end,
        resolution_note = coalesce(p_note, resolution_note)
    where id = p_incident_id
    returning * into v_incident;

    if p_new_status in ('acknowledged', 'resolved')
       and v_incident.severity in ('warning', 'critical')
       and v_incident.resident_id is not null then
        insert into public.notifications (facility_id, resident_id, incident_id, channel, body, status)
        select v_incident.facility_id, v_incident.resident_id, v_incident.id, 'sms',
               case p_new_status
                   when 'acknowledged' then 'Staff is responding to an alert for your family member.'
                   else 'Staff resolved the alert for your family member.'
               end,
               'pending'
        from public.family_member_links fml
        where fml.resident_id = v_incident.resident_id;
    end if;

    return v_incident;
end;
$$;

revoke all on function public.respond_to_incident(uuid, text, text) from public;
grant execute on function public.respond_to_incident(uuid, text, text) to authenticated;
```

- [ ] **Step 2: Write the read views**

```sql
-- Care-team views: security_invoker so they inherit the RLS we already
-- attached to resident_profiles / incident_events (family excluded there).
create or replace view public.facility_floor_view
with (security_invoker = true)
as
select
    rp.facility_id,
    rp.person_id as resident_id,
    rp.display_name,
    rp.room_id,
    rp.risk_flags,
    ie.id as open_incident_id,
    ie.event_type as open_incident_type,
    ie.severity as open_incident_severity,
    ie.status as open_incident_status,
    ie.detected_at as open_incident_detected_at
from public.resident_profiles rp
left join lateral (
    select ie2.*
    from public.incident_events ie2
    where ie2.resident_id = rp.person_id
    and ie2.status in ('open', 'acknowledged', 'responding')
    order by ie2.detected_at desc
    limit 1
) ie on true;

create or replace view public.facility_response_metrics
with (security_invoker = true)
as
select
    ie.facility_id,
    date_trunc('day', ie.detected_at at time zone f.timezone) as shift_date,
    case
        when extract(hour from ie.detected_at at time zone f.timezone) < 8 then 'night'
        when extract(hour from ie.detected_at at time zone f.timezone) < 16 then 'day'
        else 'evening'
    end as shift,
    count(*) as incident_count,
    avg(extract(epoch from (ie.acknowledged_at - ie.detected_at))) as avg_ack_seconds
from public.incident_events ie
join public.facilities f on f.id = ie.facility_id
where ie.acknowledged_at is not null
group by ie.facility_id, shift_date, shift;

create or replace view public.resident_activity_view
with (security_invoker = true)
as
select
    rp.facility_id,
    rp.person_id as resident_id,
    rp.display_name,
    ie.id as incident_id,
    ie.event_type,
    ie.severity,
    ie.status,
    ie.detected_at,
    ie.acknowledged_at,
    ie.resolved_at,
    ie.resolution_note
from public.resident_profiles rp
join public.incident_events ie on ie.resident_id = rp.person_id;

-- Family views: NOT security_invoker. They run with the view owner's
-- privileges (bypassing the family-excluded base-table RLS) and instead
-- gate access themselves via family_member_links + auth.uid(), while only
-- projecting non-evidence columns. This is the intended, sole read path
-- for the family role.
create or replace view public.family_incident_feed
as
select
    ie.facility_id,
    ie.resident_id,
    ie.event_type,
    ie.severity,
    ie.status,
    ie.detected_at,
    ie.acknowledged_at,
    ie.resolved_at,
    ie.resolution_note,
    ie.summary
from public.incident_events ie
where exists (
    select 1
    from public.family_member_links fml
    where fml.resident_id = ie.resident_id
    and fml.user_id = auth.uid()
);

create or replace view public.family_visitor_feed
as
select
    vfo.facility_id,
    vfo.camera_id,
    vfo.match_status,
    vfo.detected_at,
    vfo.quality_score
from public.visitor_face_observations vfo
where exists (
    select 1
    from public.family_member_links fml
    join public.person_consents pc
        on pc.person_id = fml.resident_id
        and pc.consent_scope = 'family_visibility'
        and pc.consent_status = 'active'
    where fml.user_id = auth.uid()
    and fml.facility_id = vfo.facility_id
);

grant select on public.facility_floor_view to authenticated;
grant select on public.facility_response_metrics to authenticated;
grant select on public.resident_activity_view to authenticated;
grant select on public.family_incident_feed to authenticated;
grant select on public.family_visitor_feed to authenticated;
```

- [ ] **Step 3: Manual review checklist**

- Confirm `respond_to_incident`'s status-transition `case` covers every
  value in the `incident_events.status` check constraint from the base
  migration (`open, acknowledged, responding, resolved,
  dismissed_false_alarm, escalated`) — it does, `open` is the only
  "from" state not itself a possible `p_new_status`, which is correct
  (nothing transitions back to `open`).
- Confirm `family_incident_feed` and `family_visitor_feed` select lists
  contain no column named `*_ciphertext`, `*_embedding*`, `*_path`, or
  `evidence` — grep the view definitions for those substrings before
  committing.
- Confirm every view has a matching `grant select ... to authenticated`
  line, otherwise it's unreachable from the API even though it's valid
  SQL.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260703000100_incident_rpc_and_views.sql
git commit -m "Add respond_to_incident RPC and facility/resident/family read views"
```

---

### Task 3: notify-family Edge Function

**Files:**
- Create: `supabase/functions/notify-family/deno.json`
- Create: `supabase/functions/notify-family/index.ts`
- Create: `supabase/functions/notify-family/index.test.ts`
- Modify: `supabase/config.toml`
- Modify: `supabase/functions/.env.example`

- [ ] **Step 1: Write the failing test**

```ts
// supabase/functions/notify-family/index.test.ts
import { buildSendResult } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown, msg?: string) {
  if (actual !== expected) {
    throw new Error(msg ?? `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

Deno.test("buildSendResult marks a pending notification sent with a timestamp", () => {
  const result = buildSendResult({
    id: "11111111-1111-1111-1111-111111111111",
    facility_id: "fac-poc-001",
    resident_id: "res-1",
    incident_id: "inc-1",
    channel: "sms",
    body: "Staff resolved the alert for your family member.",
  });

  assertEquals(result.id, "11111111-1111-1111-1111-111111111111");
  assertEquals(result.status, "sent");
  assertEquals(typeof result.sent_at, "string");
  assertEquals(Number.isNaN(Date.parse(result.sent_at)), false);
});

Deno.test("buildSendResult logs the channel and body for the stub provider", () => {
  const logs: string[] = [];
  const originalLog = console.log;
  console.log = (msg: string) => logs.push(msg);
  try {
    buildSendResult({
      id: "22222222-2222-2222-2222-222222222222",
      facility_id: "fac-poc-001",
      resident_id: "res-2",
      incident_id: "inc-2",
      channel: "sms",
      body: "Staff is responding to an alert for your family member.",
    });
  } finally {
    console.log = originalLog;
  }
  assertEquals(logs.length, 1);
  assertEquals(logs[0].includes("res-2"), true);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx -y deno test --allow-net supabase/functions/notify-family/index.test.ts`
Expected: FAIL — `index.ts` does not exist yet (module not found).

- [ ] **Step 3: Write the implementation**

```ts
// supabase/functions/notify-family/index.ts
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-internal-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PendingNotification {
  id: string;
  facility_id: string;
  resident_id: string | null;
  incident_id: string | null;
  channel: string;
  body: string;
}

interface SendResult {
  id: string;
  status: "sent";
  sent_at: string;
}

// Stub SMS/push provider: logs only. Swap this function body for a real
// Twilio (or Expo push) call once credentials are available — the caller
// (Deno.serve handler below) doesn't need to change.
export function buildSendResult(notification: PendingNotification): SendResult {
  console.log(
    `[notify-family] would send ${notification.channel} to family of resident ${notification.resident_id}: ${notification.body}`,
  );
  return { id: notification.id, status: "sent", sent_at: new Date().toISOString() };
}

export async function fetchPendingNotifications(
  supabaseUrl: string,
  serviceKey: string,
  limit: number,
): Promise<PendingNotification[]> {
  const params = new URLSearchParams({
    select: "id,facility_id,resident_id,incident_id,channel,body",
    status: "eq.pending",
    order: "created_at.asc",
    limit: String(limit),
  });

  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/rest/v1/notifications?${params.toString()}`,
    {
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error(`fetch_pending_failed:${response.status}`);
  }

  return await response.json() as PendingNotification[];
}

export async function markSent(
  supabaseUrl: string,
  serviceKey: string,
  id: string,
  sentAt: string,
): Promise<void> {
  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/rest/v1/notifications?id=eq.${id}`,
    {
      method: "PATCH",
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "content-type": "application/json",
        prefer: "return=minimal",
      },
      body: JSON.stringify({ status: "sent", sent_at: sentAt }),
    },
  );

  if (!response.ok) {
    throw new Error(`mark_sent_failed:${response.status}`);
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("MERIDIAN_SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SECRET_KEY");
  const internalSecret = Deno.env.get("MERIDIAN_INTERNAL_FUNCTION_SECRET");

  if (!supabaseUrl || !serviceKey || !internalSecret) {
    return jsonResponse({ error: "server_not_configured" }, 500);
  }

  if (request.headers.get("x-internal-secret") !== internalSecret) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let pending: PendingNotification[];
  try {
    pending = await fetchPendingNotifications(supabaseUrl, serviceKey, 25);
  } catch (error) {
    console.error("fetch pending notifications failed", error);
    return jsonResponse({ error: "fetch_failed" }, 502);
  }

  const results: Array<{ id: string; status: string }> = [];
  for (const notification of pending) {
    const result = buildSendResult(notification);
    try {
      await markSent(supabaseUrl, serviceKey, result.id, result.sent_at);
      results.push({ id: result.id, status: "sent" });
    } catch (error) {
      console.error("mark sent failed", notification.id, error);
      results.push({ id: notification.id, status: "failed" });
    }
  }

  return jsonResponse({ processed: results.length, results }, 200);
});

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}
```

```json
// supabase/functions/notify-family/deno.json
{
  "fmt": {
    "lineWidth": 100,
    "semiColons": true,
    "singleQuote": false
  },
  "lint": {
    "rules": {
      "exclude": []
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `npx -y deno test --allow-net supabase/functions/notify-family/index.test.ts`
Expected: PASS — both tests green. (`--allow-net` is required because
two tests touch no filesystem/network permissions; `Deno.serve` at module
scope does not start listening during `deno test`, so no network
permission is required either.)

- [ ] **Step 5: Register the function and document its secret**

Add to `supabase/config.toml` (after the `ingest-visitor-face` block):

```toml
[functions.notify-family]
verify_jwt = false
```

(`verify_jwt = false` because this is an internal/cron-triggered function
authenticated by `x-internal-secret`, not an end-user JWT — it's never
called directly by the Care/Family apps.)

Append to `supabase/functions/.env.example`:

```
# Shared secret for internal-only functions (e.g. notify-family) that are
# triggered by a scheduler/ops call, not an end-user session.
MERIDIAN_INTERNAL_FUNCTION_SECRET=replace-with-a-random-32-byte-hex-value
```

- [ ] **Step 6: Commit**

```bash
git add supabase/functions/notify-family supabase/config.toml supabase/functions/.env.example
git commit -m "Add notify-family Edge Function (stub SMS provider) with tests"
```

---

### Task 4: Demo seed script

**Files:**
- Create: `supabase/seed/demo_two_room_seed.sql`
- Create: `supabase/seed/README.md`

- [ ] **Step 1: Write the seed script**

```sql
-- supabase/seed/demo_two_room_seed.sql
-- Idempotent demo data for a 2-camera, 2-resident pitch demo.
-- Run AFTER migrations. Requires three auth.users to already exist
-- (create them via Supabase Auth first — see supabase/seed/README.md) —
-- this script does not and cannot create auth.users rows itself.
--
-- Usage: replace the three UUID placeholders below with the real
-- auth.users ids for your demo owner/caregiver/family accounts, then run
-- this file via the Supabase SQL editor or `psql`.

insert into public.facilities (id, slug, display_name, timezone)
values ('fac-demo-001', 'demo-facility', 'Meridian Demo Facility', 'America/Los_Angeles')
on conflict (id) do update set display_name = excluded.display_name;

insert into public.cameras (id, facility_id, external_id, display_name, location_label, status)
values
    ('cam-entry-001', 'fac-demo-001', 'entry-001', 'Main Entrance', 'Front Door', 'online'),
    ('cam-room-101', 'fac-demo-001', 'room-101', 'Room 101', 'Room 101', 'online')
on conflict (id) do update set status = excluded.status;

insert into public.people (id, facility_id, display_name, person_type, external_ref)
values
    ('person-maggie', 'fac-demo-001', 'Maggie R.', 'resident', 'demo-resident-1'),
    ('person-walter', 'fac-demo-001', 'Walter S.', 'resident', 'demo-resident-2')
on conflict (id) do update set display_name = excluded.display_name;

insert into public.resident_profiles (facility_id, person_id, room_id, display_name, risk_flags, care_notes)
values
    ('fac-demo-001', 'person-maggie', 'room-101', 'Maggie R.', '["fall_history"]'::jsonb, 'Prefers morning walks; mild dementia.'),
    ('fac-demo-001', 'person-walter', 'room-102', 'Walter S.', '[]'::jsonb, 'Independent, low fall risk.')
on conflict (person_id) do update set risk_flags = excluded.risk_flags;

insert into public.person_consents (facility_id, person_id, consent_scope, consent_status, consent_source)
values
    ('fac-demo-001', 'person-maggie', 'monitoring', 'active', 'admission_agreement'),
    ('fac-demo-001', 'person-maggie', 'family_visibility', 'active', 'admission_agreement'),
    ('fac-demo-001', 'person-walter', 'monitoring', 'active', 'admission_agreement'),
    ('fac-demo-001', 'person-walter', 'family_visibility', 'active', 'admission_agreement')
on conflict do nothing;

-- Replace these three UUIDs with real auth.users ids before running.
insert into public.facility_members (facility_id, user_id, role)
values
    ('fac-demo-001', '00000000-0000-0000-0000-000000000001', 'owner'),
    ('fac-demo-001', '00000000-0000-0000-0000-000000000002', 'caregiver'),
    ('fac-demo-001', '00000000-0000-0000-0000-000000000003', 'family')
on conflict (facility_id, user_id) do update set role = excluded.role;

insert into public.family_member_links (facility_id, user_id, resident_id)
values ('fac-demo-001', '00000000-0000-0000-0000-000000000003', 'person-maggie')
on conflict (user_id, resident_id) do nothing;

-- Sample incidents across lifecycle states so the demo has real data to
-- click through immediately.
insert into public.incident_events (
    source_event_id, facility_id, room_id, resident_id, camera_id,
    event_type, severity, status, confidence, detected_at, generated_at,
    reason_codes, summary
)
values
    (
        'demo-evt-open-1', 'fac-demo-001', 'room-101', 'person-maggie', 'cam-room-101',
        'fall_suspected', 'warning', 'open', 0.72, now() - interval '3 minutes', now() - interval '3 minutes',
        '["pose_low_confidence"]'::jsonb, 'Maggie may need help in Room 101'
    ),
    (
        'demo-evt-resolved-1', 'fac-demo-001', 'room-101', 'person-maggie', 'cam-room-101',
        'fall_confirmed', 'critical', 'open', 0.94, now() - interval '2 hours', now() - interval '2 hours',
        '["pose_fall_pattern", "gemini_confirmed"]'::jsonb, 'Maggie needs help in Room 101'
    ),
    (
        'demo-evt-visitor-1', 'fac-demo-001', null, null, 'cam-entry-001',
        'visitor_arrival', 'info', 'resolved', null, now() - interval '1 hour', now() - interval '1 hour',
        '[]'::jsonb, 'New visitor detected at Main Entrance'
    )
on conflict (source_event_id) do nothing;

-- Walk demo-evt-resolved-1 through the real RPC-shaped lifecycle so
-- acknowledged_by/resolved_by are populated the same way the app would
-- populate them (direct update here only because this is seed data, not
-- an app write path).
update public.incident_events
set status = 'resolved',
    acknowledged_by = '00000000-0000-0000-0000-000000000002',
    acknowledged_at = detected_at + interval '90 seconds',
    resolved_by = '00000000-0000-0000-0000-000000000002',
    resolved_at = detected_at + interval '5 minutes',
    resolution_note = 'Staff reached her in 90 seconds. Assisted back to bed, no injury.'
where source_event_id = 'demo-evt-resolved-1';
```

- [ ] **Step 2: Write the README explaining the manual auth.users step**

```markdown
<!-- supabase/seed/README.md -->
# Demo seed data

`demo_two_room_seed.sql` seeds one facility, two cameras, two residents,
and a handful of incidents in different lifecycle states, for a live
2-camera pitch demo.

## Before running it

Supabase's raw SQL cannot create `auth.users` rows — those must exist
first via Supabase Auth. Create three demo accounts (owner, caregiver,
family) however you prefer:

- Supabase Dashboard → Authentication → Users → Add user, or
- `supabase.auth.admin.createUser(...)` from a trusted script using the
  service-role key (never from a mobile/web app).

Then open `demo_two_room_seed.sql` and replace the three placeholder
UUIDs (`00000000-0000-0000-0000-00000000000{1,2,3}`) with the real
`auth.users.id` values for those three accounts before running the
script.

## Running it

Via the Supabase SQL editor (paste the file contents), or:

```bash
psql "$SUPABASE_DB_URL" -f supabase/seed/demo_two_room_seed.sql
```

The script is idempotent (`on conflict do update/nothing`) — safe to
re-run after editing.
```

- [ ] **Step 3: Commit**

```bash
git add supabase/seed/demo_two_room_seed.sql supabase/seed/README.md
git commit -m "Add demo seed script for 2-camera/2-resident pitch demo"
```

---

### Task 5: Shared API contract package

**Files:**
- Create: `meridian_software/shared/types.ts`
- Create: `meridian_software/docs/api-contract.md`
- Create: `meridian_software/docs/realtime-channels.md`

- [ ] **Step 1: Write the shared types**

```ts
// meridian_software/shared/types.ts
// Hand-mirrored from supabase/migrations/*.sql. If you change a table or
// view's shape in a migration, update the matching type here in the same
// commit — this file (not the raw SQL) is what the app code should import.

export type FacilityRole = "owner" | "admin" | "caregiver" | "viewer" | "family";

export type IncidentEventType =
    | "fall_suspected"
    | "fall_confirmed"
    | "long_lie"
    | "unusual_inactivity"
    | "wandering"
    | "exit_risk"
    | "night_activity"
    | "device_offline"
    | "stream_degraded"
    | "medication_visit_missing"
    | "visitor_arrival"
    | "visitor_departure";

export type IncidentSeverity = "info" | "warning" | "critical";

export type IncidentStatus =
    | "open"
    | "acknowledged"
    | "responding"
    | "resolved"
    | "dismissed_false_alarm"
    | "escalated";

export type VisitorMatchStatus = "new_visitor" | "repeat_visitor" | "known_visitor" | "unknown";

export interface ResidentProfile {
    id: string;
    facility_id: string;
    person_id: string;
    room_id: string | null;
    display_name: string;
    risk_flags: string[];
    care_notes: string | null;
    created_at: string;
    updated_at: string;
}

/** public.facility_floor_view — Insights live floor view, one row per resident. */
export interface FloorViewRow {
    facility_id: string;
    resident_id: string;
    display_name: string;
    room_id: string | null;
    risk_flags: string[];
    open_incident_id: string | null;
    open_incident_type: IncidentEventType | null;
    open_incident_severity: IncidentSeverity | null;
    open_incident_status: IncidentStatus | null;
    open_incident_detected_at: string | null;
}

/** public.facility_response_metrics — Insights response-time analytics by shift. */
export interface ResponseMetricRow {
    facility_id: string;
    shift_date: string;
    shift: "night" | "day" | "evening";
    incident_count: number;
    avg_ack_seconds: number | null;
}

/** public.resident_activity_view — Insights resident detail incident history. */
export interface ResidentActivityRow {
    facility_id: string;
    resident_id: string;
    display_name: string;
    incident_id: string;
    event_type: IncidentEventType;
    severity: IncidentSeverity;
    status: IncidentStatus;
    detected_at: string;
    acknowledged_at: string | null;
    resolved_at: string | null;
    resolution_note: string | null;
}

/** public.family_incident_feed — Family app daily summary / alert source. */
export interface FamilyIncidentRow {
    facility_id: string;
    resident_id: string;
    event_type: IncidentEventType;
    severity: IncidentSeverity;
    status: IncidentStatus;
    detected_at: string;
    acknowledged_at: string | null;
    resolved_at: string | null;
    resolution_note: string | null;
    summary: string | null;
}

/** public.family_visitor_feed — Family app visitor log (metadata only). */
export interface FamilyVisitorRow {
    facility_id: string;
    camera_id: string | null;
    match_status: VisitorMatchStatus;
    detected_at: string;
    quality_score: number | null;
}

/** public.notifications — audit trail of what a family was told and when. */
export interface NotificationRow {
    id: string;
    facility_id: string;
    resident_id: string | null;
    incident_id: string | null;
    channel: "sms" | "push";
    body: string;
    status: "pending" | "sent" | "failed";
    created_at: string;
    sent_at: string | null;
}

/** Args/return for the public.respond_to_incident RPC. */
export interface RespondToIncidentArgs {
    p_incident_id: string;
    p_new_status: Extract<IncidentStatus, "acknowledged" | "responding" | "resolved" | "dismissed_false_alarm" | "escalated">;
    p_note?: string | null;
}
```

- [ ] **Step 2: Write the API contract doc**

```markdown
<!-- meridian_software/docs/api-contract.md -->
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
| Visitor observation timeline | `select facility_id, camera_id, match_status, detected_at, quality_score, matched_person_id from visitor_face_observations where facility_id = :id order by detected_at desc` | Never select `face_embedding_*` or `encrypted_face_image_path` into any UI-bound query — those exist for the encryption/evidence pipeline, not display. |
| Acknowledge / resolve an incident | `rpc('respond_to_incident', { p_incident_id, p_new_status, p_note })` | Only path that changes `incident_events.status`. Throws `not_authorized` (Postgres error code 42501) if the caller isn't owner/admin/caregiver at that facility, `invalid_transition` (22023) on an illegal status change. |

## Meridian Care (caregiver app — owner/admin/caregiver)

| Screen | Source | Notes |
| --- | --- | --- |
| Live alert feed | `select * from incident_events where facility_id = :id and status in ('open','acknowledged','responding') order by detected_at desc` | Realtime-subscribe to `incident_events` for push-like updates. |
| Acknowledge/resolve | same `respond_to_incident` RPC as above | |
| Resident profiles | `select * from resident_profiles where facility_id = :id` | |

## Meridian Family (family app — family role only)

| Screen | Source | Notes |
| --- | --- | --- |
| Daily summary / alert feed | `select * from family_incident_feed order by detected_at desc` | Already scoped server-side to the caller's linked resident(s) — do not add a `resident_id` filter expecting it to restrict further access; the view's own `where exists (...)` against `family_member_links` is the actual security boundary. |
| Visitor log (generic) | `select * from family_visitor_feed order by detected_at desc` | Only returns rows if the linked resident has an active `family_visibility` consent — an empty result is expected/valid, not an error. Copy should read as a count/timeline ("3 visitors today"), never a name — the view has no name column, so this is structurally enforced. |
| "Staff reached her in 90 seconds" follow-up copy | `select body, created_at, sent_at from notifications where resident_id = :linked_resident_id order by created_at desc` | Populated by `respond_to_incident` → written by `notify-family`, see realtime-channels.md for how to know when a new one lands. |

## Roles reference

| Role | Can do |
| --- | --- |
| `owner` / `admin` | Everything caregiver can, plus manage `resident_profiles`, `family_member_links`, `person_consents`. |
| `caregiver` | Read facility incidents/residents/visitor observations, call `respond_to_incident`. |
| `viewer` | Read-only version of caregiver (dashboard-only role, e.g. an ops observer). |
| `family` | Read only `family_incident_feed` / `family_visitor_feed` / their own `notifications` rows, scoped to their linked resident(s) via `family_member_links`. Never reaches raw `incident_events`, `visitor_face_observations`, or any evidence/embedding column. |
```

- [ ] **Step 3: Write the realtime channels doc**

```markdown
<!-- meridian_software/docs/realtime-channels.md -->
# Realtime Channels

Meridian's live feeds use Supabase Realtime's Postgres Changes feature —
subscribe directly to table changes, filtered server-side by RLS (the
same policies documented in api-contract.md apply to realtime payloads:
a `family`-role session will not receive `incident_events` change events
at all, since that role has no select policy on the base table — build
the Family app's live updates against `family_incident_feed`'s
underlying table (`incident_events`) via a comparable poll/refetch
instead of a raw subscription, since Supabase Realtime does not support
subscribing to a *view*).

| Channel | Table | Who subscribes | Payload use |
| --- | --- | --- | --- |
| `incident-events-<facility_id>` | `incident_events`, filter `facility_id=eq.<id>` | Insights dashboard, Care app (owner/admin/caregiver/viewer) | New/updated incident → refresh floor view / alert feed. |
| `notifications-<facility_id>` | `notifications`, filter `facility_id=eq.<id>` | Insights dashboard (audit trail) | New row → notification was queued; `status` flips `pending`→`sent` once `notify-family` processes it. |

For the Family app: since it can't subscribe to `incident_events`
directly (no RLS access) or to a view (Realtime limitation), poll
`family_incident_feed` and `notifications` (filtered to the signed-in
family user's linked resident) on an interval — every 15-30s is enough
for a daily-summary-style app and avoids needing a realtime channel at
all for that role.
```

- [ ] **Step 4: Commit**

```bash
git add meridian_software/shared/types.ts meridian_software/docs/api-contract.md meridian_software/docs/realtime-channels.md
git commit -m "Add shared TS types and API contract docs for front-end integration"
```

---

### Task 6: Backend smoke-test script (for once real credentials exist)

**Files:**
- Create: `supabase/scripts/smoke_test_backend.md`

- [ ] **Step 1: Write the smoke test checklist**

This can't run in this environment (no `SUPABASE_ACCESS_TOKEN`/DB
credentials available). Write it as a runnable checklist for whoever has
the real project keys (Dhairya, or Codex once handed the keys) to execute
once, and to re-run before the pitch demo.

```markdown
<!-- supabase/scripts/smoke_test_backend.md -->
# Backend smoke test (run once real Supabase credentials are available)

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
   (column privilege was revoked in Task 1).
6. **notify-family drains the queue.** Invoke the `notify-family`
   function with the `x-internal-secret` header set to
   `MERIDIAN_INTERNAL_FUNCTION_SECRET`. Confirm the pending notification
   from step 3 flips to `status = 'sent'` with a `sent_at` timestamp, and
   the function logs the stub-send line.
7. **Family isolation.** As the demo `family` user, confirm
   `select * from family_incident_feed` returns only Maggie's incidents
   (not Walter's), and `select * from incident_events` (raw table)
   returns zero rows (blocked by RLS, per Task 1's tightened policy).
8. **Family visitor feed respects consent.** As the demo `family` user,
   confirm `select * from family_visitor_feed` returns the seeded visitor
   row (Maggie has an active `family_visibility` consent). Revoke that
   consent (`update person_consents set consent_status = 'revoked' ...`)
   and confirm the same query now returns zero rows.
9. **No evidence leakage.** Grep the JSON result of every family-role
   query above for `ciphertext`, `embedding`, `nonce`, and `_path` —
   none should appear.
```

- [ ] **Step 2: Commit**

```bash
git add supabase/scripts/smoke_test_backend.md
git commit -m "Add backend smoke-test checklist for post-credentials verification"
```

---

## Spec Coverage Check

- Family role + linkage: Task 1 (`family_member_links`, role constraint).
- Resident-separated data model: Task 1 (`resident_profiles`),
  Task 2 (`facility_floor_view`, `resident_activity_view`,
  `family_incident_feed` all key off `resident_id`/`person_id`).
- Incident lifecycle with real actor/timestamp: Task 1 (columns) + Task 2
  (`respond_to_incident`, column-grant revocation).
- Family notification triggered by real resolution: Task 2 (RPC inserts
  `notifications`) + Task 3 (`notify-family` drains them).
- Demo-ready seed data for 2 cameras/2 residents: Task 4.
- API contract for front-end guy, no UI code from this plan: Task 5.
- Verification despite no local Supabase/Docker: Task 1–3 manual review
  steps + Deno tests (Task 3) + Task 6 checklist for once real
  credentials exist.
