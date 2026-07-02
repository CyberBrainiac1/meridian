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
-- family_incident_feed (added in the next migration), never the raw
-- table, so evidence columns and other-residents' incidents stay out of
-- reach.
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

-- respond_to_incident (next migration) is the only path that may change
-- incident status; remove the old direct-update grant so writes must go
-- through the RPC.
revoke update (status) on public.incident_events from authenticated;
