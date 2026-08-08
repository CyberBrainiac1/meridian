-- A daily, privacy-bounded room-camera summary.  This intentionally stores
-- categories only: no pose, track ID, coordinates, per-window timestamps, or
-- numeric movement counts leave the Hub.  The Hub compares its local counts
-- to a local recent-history baseline before invoking the RPC below.

create table if not exists public.resident_activity_rollups (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    rollup_date date not null,
    daytime_pattern text not null check (daytime_pattern in (
        'usual', 'lower_than_usual', 'higher_than_usual',
        'not_compared', 'insufficient_observation'
    )),
    nighttime_pattern text not null check (nighttime_pattern in (
        'usual', 'lower_than_usual', 'higher_than_usual',
        'not_compared', 'insufficient_observation'
    )),
    baseline_status text not null check (baseline_status in ('ready', 'building')),
    observation_status text not null check (observation_status in ('sufficient', 'limited')),
    source_version text not null default 'activity-rollup-v1',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (facility_id, resident_id, rollup_date)
);

create index if not exists resident_activity_rollups_resident_date_idx
    on public.resident_activity_rollups (resident_id, rollup_date desc);

drop trigger if exists set_resident_activity_rollups_updated_at on public.resident_activity_rollups;
create trigger set_resident_activity_rollups_updated_at
before update on public.resident_activity_rollups
for each row execute function public.set_updated_at();

-- The Hub supplies category labels and a date, but never a facility or
-- resident identifier.  Those are derived from its provisioned device JWT,
-- eliminating cross-resident writes from a compromised room unit.
create or replace function public.record_resident_activity_rollup(
    p_rollup_date date,
    p_daytime_pattern text,
    p_nighttime_pattern text,
    p_baseline_status text,
    p_observation_status text
)
returns public.resident_activity_rollups
language plpgsql
security definer
set search_path = public
as $$
declare
    v_device public.resident_hub_devices;
    v_rollup public.resident_activity_rollups;
begin
    if p_daytime_pattern not in ('usual', 'lower_than_usual', 'higher_than_usual', 'not_compared', 'insufficient_observation')
       or p_nighttime_pattern not in ('usual', 'lower_than_usual', 'higher_than_usual', 'not_compared', 'insufficient_observation')
       or p_baseline_status not in ('ready', 'building')
       or p_observation_status not in ('sufficient', 'limited') then
        raise exception 'invalid_activity_rollup' using errcode = '22023';
    end if;

    select * into v_device
    from public.resident_hub_devices d
    where d.hub_user_id = auth.uid()
    and d.active
    for update;

    if not found then
        raise exception 'resident_hub_not_authorized' using errcode = '42501';
    end if;

    insert into public.resident_activity_rollups (
        facility_id, resident_id, rollup_date, daytime_pattern, nighttime_pattern,
        baseline_status, observation_status
    ) values (
        v_device.facility_id, v_device.resident_id, p_rollup_date,
        p_daytime_pattern, p_nighttime_pattern, p_baseline_status,
        p_observation_status
    ) on conflict (facility_id, resident_id, rollup_date) do update set
        daytime_pattern = excluded.daytime_pattern,
        nighttime_pattern = excluded.nighttime_pattern,
        baseline_status = excluded.baseline_status,
        observation_status = excluded.observation_status
    returning * into v_rollup;

    return v_rollup;
end;
$$;

alter table public.resident_activity_rollups enable row level security;

revoke all on public.resident_activity_rollups from anon, authenticated;
grant all on public.resident_activity_rollups to service_role;

create policy "care team can read resident activity rollups"
on public.resident_activity_rollups
for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = resident_activity_rollups.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin', 'caregiver', 'viewer')
));

-- Like family_incident_feed and family_visitor_feed, this is the sole family
-- read path.  It admits only linked family with active family-visibility
-- consent, and projects no room/camera/track information or numeric counts.
create or replace view public.family_activity_rollup_feed
as
select
    rar.facility_id,
    rar.resident_id,
    rar.rollup_date,
    rar.daytime_pattern,
    rar.nighttime_pattern,
    rar.baseline_status,
    rar.observation_status
from public.resident_activity_rollups rar
where exists (
    select 1
    from public.family_member_links fml
    join public.person_consents pc
        on pc.person_id = fml.resident_id
        and pc.facility_id = fml.facility_id
        and pc.consent_scope = 'family_visibility'
        and pc.consent_status = 'active'
    where fml.resident_id = rar.resident_id
    and fml.facility_id = rar.facility_id
    and fml.user_id = auth.uid()
);

grant select on public.family_activity_rollup_feed to authenticated;
revoke all on function public.record_resident_activity_rollup(date, text, text, text, text) from public;
grant execute on function public.record_resident_activity_rollup(date, text, text, text, text) to authenticated;
