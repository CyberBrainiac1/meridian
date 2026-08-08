
-- Resident care detail: the clinical context a caregiver needs at the bedside,
-- the medication schedule that drives reminders on both surfaces, and the
-- structured shift handoff that replaces "ask whoever is leaving".
--
-- Privacy split, deliberate and enforced by RLS below:
--   * Care team  -> everything (they administer the care).
--   * Resident Hub -> only its own resident's medication times and a plain
--     "time for your medication" prompt. Never dose, never diagnosis, never
--     another resident.
--   * Family -> nothing here at all. Medication and code status are clinical
--     records; the family surface stays deliberately non-clinical, matching
--     the existing family_* feed boundary.

alter table public.resident_profiles
    add column if not exists date_of_birth date,
    add column if not exists dietary_needs text,
    add column if not exists allergies jsonb not null default '[]'::jsonb,
    add column if not exists code_status text check (
        code_status is null or code_status in ('full_code', 'dnr', 'dni', 'comfort_care')
    ),
    add column if not exists mobility_status text,
    add column if not exists communication_notes text;

-- Standing medication orders. schedule_times is local wall-clock time in the
-- facility's timezone -- a 22:00 dose means 22:00 where the resident lives,
-- which is what a caregiver reads off a MAR, not a UTC instant.
create table if not exists public.resident_medications (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    medication_name text not null,
    dose text not null,
    route text not null default 'oral',
    schedule_times time[] not null default '{}',
    instructions text,
    is_prn boolean not null default false,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    -- A scheduled (non-PRN) medication without times would silently never
    -- generate a due dose, which reads as "no meds" rather than "misconfigured".
    check (is_prn or array_length(schedule_times, 1) > 0)
);

create index if not exists resident_medications_resident_idx
    on public.resident_medications (resident_id, active);

-- One row per dose actually acted on. Absence of a row for a due time is what
-- makes a dose "outstanding" -- we never pre-create rows, so a missed dose is
-- the default state rather than something a job has to remember to write.
create table if not exists public.medication_administrations (
    id uuid primary key default gen_random_uuid(),
    medication_id uuid not null references public.resident_medications(id) on delete cascade,
    facility_id text not null references public.facilities(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    scheduled_for timestamptz not null,
    status text not null check (status in ('given', 'refused', 'held', 'missed')),
    administered_by uuid references auth.users(id) on delete set null,
    administered_at timestamptz not null default now(),
    note text,
    created_at timestamptz not null default now(),
    unique (medication_id, scheduled_for)
);

create index if not exists medication_administrations_resident_idx
    on public.medication_administrations (resident_id, scheduled_for desc);

create table if not exists public.resident_emergency_contacts (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    display_name text not null,
    relationship text not null,
    phone_e164 text not null check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
    is_primary boolean not null default false,
    notes text,
    created_at timestamptz not null default now()
);

create index if not exists resident_emergency_contacts_resident_idx
    on public.resident_emergency_contacts (resident_id, is_primary desc);

-- Who is on now and who is on next. The handoff screen's "call the next
-- caregiver" affordance needs a phone number attached to a shift window, not
-- just a facility_members role.
create table if not exists public.caregiver_shifts (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    user_id uuid references auth.users(id) on delete set null,
    display_name text not null,
    phone_e164 text check (phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
    role_label text not null default 'Caregiver',
    starts_at timestamptz not null,
    ends_at timestamptz not null,
    created_at timestamptz not null default now(),
    check (ends_at > starts_at)
);

create index if not exists caregiver_shifts_window_idx
    on public.caregiver_shifts (facility_id, starts_at, ends_at);

-- Free-text handoff, attributable and acknowledgeable. Tied to a resident so
-- it can surface on that resident's profile too, not only in the handoff list.
create table if not exists public.handoff_notes (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    resident_id text references public.people(id) on delete cascade,
    author_user_id uuid references auth.users(id) on delete set null,
    author_name text not null,
    body text not null,
    priority text not null default 'routine' check (priority in ('routine', 'watch', 'urgent')),
    created_at timestamptz not null default now(),
    acknowledged_by uuid references auth.users(id) on delete set null,
    acknowledged_at timestamptz
);

create index if not exists handoff_notes_facility_created_idx
    on public.handoff_notes (facility_id, created_at desc);

drop trigger if exists set_resident_medications_updated_at on public.resident_medications;
create trigger set_resident_medications_updated_at
before update on public.resident_medications
for each row execute function public.set_updated_at();

-- Expand every active scheduled medication into today's and yesterday's dose
-- slots, then left-join what was actually administered. Yesterday is included
-- so a 22:00 dose is still visibly outstanding to the night shift at 01:00.
create or replace view public.facility_medication_schedule
with (security_invoker = true)
as
select
    m.id as medication_id,
    m.facility_id,
    m.resident_id,
    rp.display_name as resident_name,
    rp.room_id,
    m.medication_name,
    m.dose,
    m.route,
    m.instructions,
    ((d.day + t.slot) at time zone f.timezone) as scheduled_for,
    coalesce(a.status, 'outstanding') as status,
    a.administered_at,
    a.note as administration_note
from public.resident_medications m
join public.facilities f on f.id = m.facility_id
join public.resident_profiles rp on rp.person_id = m.resident_id
cross join lateral unnest(m.schedule_times) as t(slot)
cross join lateral (
    select generate_series(
        (timezone(f.timezone, now())::date - 1),
        (timezone(f.timezone, now())::date),
        interval '1 day'
    )::date as day
) d
left join public.medication_administrations a
    on a.medication_id = m.id
    and a.scheduled_for = ((d.day + t.slot) at time zone f.timezone)
where m.active and not m.is_prn;

-- The Hub's own read path: its resident, its times, and nothing clinical.
-- Deliberately omits dose, route, instructions and every other resident --
-- a room display is not a medication record.
create or replace view public.resident_hub_medication_feed
as
select
    s.medication_id,
    s.scheduled_for,
    s.status
from public.facility_medication_schedule s
where exists (
    select 1 from public.resident_hub_devices dv
    where dv.facility_id = s.facility_id
    and dv.resident_id = s.resident_id
    and dv.hub_user_id = auth.uid()
    and dv.active
);

create or replace function public.record_medication_administration(
    p_medication_id uuid,
    p_scheduled_for timestamptz,
    p_status text,
    p_note text default null
)
returns public.medication_administrations
language plpgsql
security definer
set search_path = public
as $$
declare
    v_med public.resident_medications;
    v_role text;
    v_row public.medication_administrations;
begin
    if p_status not in ('given', 'refused', 'held', 'missed') then
        raise exception 'invalid_administration_status' using errcode = '22023';
    end if;

    select * into v_med from public.resident_medications where id = p_medication_id;
    if not found then
        raise exception 'medication_not_found' using errcode = 'P0002';
    end if;

    select fm.role into v_role
    from public.facility_members fm
    where fm.facility_id = v_med.facility_id and fm.user_id = auth.uid();

    if v_role is null or v_role not in ('owner', 'admin', 'caregiver') then
        raise exception 'not_authorized' using errcode = '42501';
    end if;

    insert into public.medication_administrations (
        medication_id, facility_id, resident_id, scheduled_for, status, administered_by, note
    ) values (
        p_medication_id, v_med.facility_id, v_med.resident_id, p_scheduled_for,
        p_status, auth.uid(), p_note
    )
    on conflict (medication_id, scheduled_for) do update set
        status = excluded.status,
        administered_by = excluded.administered_by,
        administered_at = now(),
        note = coalesce(excluded.note, public.medication_administrations.note)
    returning * into v_row;

    return v_row;
end;
$$;

create or replace function public.acknowledge_handoff_note(p_note_id uuid)
returns public.handoff_notes
language plpgsql
security definer
set search_path = public
as $$
declare
    v_note public.handoff_notes;
    v_role text;
begin
    select * into v_note from public.handoff_notes where id = p_note_id;
    if not found then
        raise exception 'handoff_note_not_found' using errcode = 'P0002';
    end if;

    select fm.role into v_role
    from public.facility_members fm
    where fm.facility_id = v_note.facility_id and fm.user_id = auth.uid();

    if v_role is null or v_role not in ('owner', 'admin', 'caregiver') then
        raise exception 'not_authorized' using errcode = '42501';
    end if;

    update public.handoff_notes
    set acknowledged_by = auth.uid(), acknowledged_at = now()
    where id = p_note_id and acknowledged_at is null
    returning * into v_note;

    -- Already acknowledged is not an error: the second caregiver's intent
    -- (this note is seen) already holds, same idempotency rule as
    -- respond_to_incident.
    if v_note.id is null then
        select * into v_note from public.handoff_notes where id = p_note_id;
    end if;
    return v_note;
end;
$$;

alter table public.resident_medications enable row level security;
alter table public.medication_administrations enable row level security;
alter table public.resident_emergency_contacts enable row level security;
alter table public.caregiver_shifts enable row level security;
alter table public.handoff_notes enable row level security;

revoke all on public.resident_medications from anon, authenticated;
revoke all on public.medication_administrations from anon, authenticated;
revoke all on public.resident_emergency_contacts from anon, authenticated;
revoke all on public.caregiver_shifts from anon, authenticated;
revoke all on public.handoff_notes from anon, authenticated;

grant select on public.resident_medications to authenticated;
grant select on public.medication_administrations to authenticated;
grant select on public.resident_emergency_contacts to authenticated;
grant select on public.caregiver_shifts to authenticated;
grant select, insert on public.handoff_notes to authenticated;

grant all on public.resident_medications to service_role;
grant all on public.medication_administrations to service_role;
grant all on public.resident_emergency_contacts to service_role;
grant all on public.caregiver_shifts to service_role;
grant all on public.handoff_notes to service_role;

create policy "care team can read medications"
on public.resident_medications for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = resident_medications.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin', 'caregiver', 'viewer')
));

-- The Hub reads through resident_hub_medication_feed, but that view is
-- security_invoker via facility_medication_schedule, so the device still
-- needs a row-level grant on the base table -- scoped to its own resident.
create policy "resident hub can read own medications"
on public.resident_medications for select to authenticated
using (exists (
    select 1 from public.resident_hub_devices dv
    where dv.facility_id = resident_medications.facility_id
    and dv.resident_id = resident_medications.resident_id
    and dv.hub_user_id = auth.uid()
    and dv.active
));

create policy "care team can read administrations"
on public.medication_administrations for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = medication_administrations.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin', 'caregiver', 'viewer')
));

create policy "resident hub can read own administrations"
on public.medication_administrations for select to authenticated
using (exists (
    select 1 from public.resident_hub_devices dv
    where dv.facility_id = medication_administrations.facility_id
    and dv.resident_id = medication_administrations.resident_id
    and dv.hub_user_id = auth.uid()
    and dv.active
));

create policy "care team can read emergency contacts"
on public.resident_emergency_contacts for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = resident_emergency_contacts.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin', 'caregiver')
));

create policy "care team can read shifts"
on public.caregiver_shifts for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = caregiver_shifts.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin', 'caregiver', 'viewer')
));

create policy "care team can read handoff notes"
on public.handoff_notes for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = handoff_notes.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin', 'caregiver', 'viewer')
));

create policy "care team can write handoff notes"
on public.handoff_notes for insert to authenticated
with check (
    author_user_id = auth.uid()
    and exists (
        select 1 from public.facility_members fm
        where fm.facility_id = handoff_notes.facility_id
        and fm.user_id = auth.uid()
        and fm.role in ('owner', 'admin', 'caregiver')
    )
);

grant select on public.facility_medication_schedule to authenticated;
grant select on public.resident_hub_medication_feed to authenticated;

revoke all on function public.record_medication_administration(uuid, timestamptz, text, text) from public;
revoke all on function public.acknowledge_handoff_note(uuid) from public;
grant execute on function public.record_medication_administration(uuid, timestamptz, text, text) to authenticated;
grant execute on function public.acknowledge_handoff_note(uuid) to authenticated;
