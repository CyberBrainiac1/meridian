-- MeridianHub is a resident-facing, room-bound surface.  A Hub runs with a
-- dedicated Supabase Auth user provisioned for one physical device; it is not
-- a shared caregiver/family account.  resident_hub_devices is the complete
-- authorization boundary: a JWT can be active for at most one device, and a
-- device is bound to one facility, resident, room, and optional entry camera.
--
-- The device never receives a direct grant on these tables.  Its only read
-- surfaces are the safe resident_hub_* views below, which filter by auth.uid()
-- and intentionally omit visitor ciphertext, embedding, key, image, and
-- observation metadata.  Consequently, a compromised Hub in room 101 cannot
-- enumerate or act on room 102, even at the same facility.

create table if not exists public.resident_hub_devices (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    room_id text not null,
    hub_user_id uuid not null references auth.users(id) on delete cascade,
    visitor_camera_id text references public.cameras(id) on delete set null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists resident_hub_devices_active_user_idx
    on public.resident_hub_devices (hub_user_id)
    where active;

create unique index if not exists resident_hub_devices_active_resident_idx
    on public.resident_hub_devices (facility_id, resident_id)
    where active;

create index if not exists resident_hub_devices_visitor_camera_idx
    on public.resident_hub_devices (facility_id, visitor_camera_id)
    where active and visitor_camera_id is not null;

-- A device binding must refer to the same facility everywhere and only to a
-- resident profile.  Provisioning is care-admin/service-role work; this guard
-- prevents an accidental cross-facility binding from becoming an RLS leak.
create or replace function public.validate_resident_hub_device_scope()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if not exists (
        select 1 from public.people p
        where p.id = new.resident_id
        and p.facility_id = new.facility_id
        and p.person_type = 'resident'
    ) then
        raise exception 'resident_hub_device_resident_scope_invalid' using errcode = '23514';
    end if;

    if not exists (
        select 1 from public.resident_profiles rp
        where rp.person_id = new.resident_id
        and rp.facility_id = new.facility_id
        and rp.room_id = new.room_id
    ) then
        raise exception 'resident_hub_device_room_scope_invalid' using errcode = '23514';
    end if;

    if new.visitor_camera_id is not null and not exists (
        select 1 from public.cameras c
        where c.id = new.visitor_camera_id
        and c.facility_id = new.facility_id
    ) then
        raise exception 'resident_hub_device_camera_scope_invalid' using errcode = '23514';
    end if;

    return new;
end;
$$;

drop trigger if exists validate_resident_hub_device_scope on public.resident_hub_devices;
create trigger validate_resident_hub_device_scope
before insert or update on public.resident_hub_devices
for each row execute function public.validate_resident_hub_device_scope();

create table if not exists public.assistance_requests (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    room_id text not null,
    incident_id uuid references public.incident_events(id) on delete set null,
    request_kind text not null check (request_kind in ('assistance', 'family_contact', 'emergency')),
    source text not null check (source in ('resident_hub', 'auto_fall_dispatch')),
    status text not null default 'open'
        check (status in ('open', 'acknowledged', 'en_route', 'resolved', 'cancelled')),
    requested_at timestamptz not null default now(),
    acknowledged_by uuid references auth.users(id) on delete set null,
    acknowledged_at timestamptz,
    en_route_by uuid references auth.users(id) on delete set null,
    en_route_at timestamptz,
    resolved_by uuid references auth.users(id) on delete set null,
    resolved_at timestamptz,
    cancelled_by uuid references auth.users(id) on delete set null,
    cancelled_at timestamptz,
    resolution_note text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check ((source = 'auto_fall_dispatch') = (incident_id is not null))
);

-- One confirmed incident can create exactly one automatic dispatch, including
-- when the Hub retries the same source event and ingest-event deduplicates it.
create unique index if not exists assistance_requests_auto_fall_incident_idx
    on public.assistance_requests (incident_id)
    where source = 'auto_fall_dispatch';

create index if not exists assistance_requests_resident_status_idx
    on public.assistance_requests (resident_id, status, requested_at desc);

create table if not exists public.visitor_verification_prompts (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    room_id text not null,
    observation_id uuid not null references public.visitor_face_observations(id) on delete cascade,
    camera_id text references public.cameras(id) on delete set null,
    status text not null default 'pending'
        check (status in ('pending', 'approved', 'denied', 'no_response')),
    prompted_at timestamptz not null default now(),
    expires_at timestamptz not null,
    answered_at timestamptz,
    answered_by uuid references auth.users(id) on delete set null,
    escalation_notified_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (observation_id, resident_id),
    check (expires_at > prompted_at),
    check (
        (status = 'pending' and answered_at is null and answered_by is null)
        or (status in ('approved', 'denied') and answered_at is not null and answered_by is not null)
        or (status = 'no_response' and answered_at is null and answered_by is null)
    )
);

create index if not exists visitor_verification_prompts_resident_status_idx
    on public.visitor_verification_prompts (resident_id, status, prompted_at desc);

-- Link notifications to their source without overloading incident_id.  The
-- existing notification processor remains the delivery path for care staff
-- and consented family members.
alter table public.notifications
    add column if not exists assistance_request_id uuid references public.assistance_requests(id) on delete set null,
    add column if not exists visitor_verification_prompt_id uuid references public.visitor_verification_prompts(id) on delete set null;

create index if not exists notifications_assistance_request_idx
    on public.notifications (assistance_request_id)
    where assistance_request_id is not null;

create index if not exists notifications_visitor_prompt_idx
    on public.notifications (visitor_verification_prompt_id)
    where visitor_verification_prompt_id is not null;

drop trigger if exists set_resident_hub_devices_updated_at on public.resident_hub_devices;
create trigger set_resident_hub_devices_updated_at
before update on public.resident_hub_devices
for each row execute function public.set_updated_at();

drop trigger if exists set_assistance_requests_updated_at on public.assistance_requests;
create trigger set_assistance_requests_updated_at
before update on public.assistance_requests
for each row execute function public.set_updated_at();

drop trigger if exists set_visitor_verification_prompts_updated_at on public.visitor_verification_prompts;
create trigger set_visitor_verification_prompts_updated_at
before update on public.visitor_verification_prompts
for each row execute function public.set_updated_at();

-- The 5-minute fallback is deliberately conservative and is not represented
-- as a measured ETA.  Recent acknowledged incident history supplies the real
-- estimate; the confidence tells the Hub whether the estimate has enough data.
create or replace function public.estimate_assistance_eta(p_facility_id text)
returns table (eta_seconds integer, eta_confidence text)
language sql
stable
set search_path = public
as $$
    with recent as (
        select extract(epoch from (ie.acknowledged_at - ie.detected_at)) as ack_seconds
        from public.incident_events ie
        where ie.facility_id = p_facility_id
        and ie.acknowledged_at is not null
        and ie.acknowledged_at >= now() - interval '30 days'
        and ie.acknowledged_at >= ie.detected_at
    ), aggregate as (
        select count(*)::integer as sample_count, avg(ack_seconds) as average_seconds
        from recent
    )
    select
        case
            when sample_count = 0 then 300
            else greatest(30, least(1800, ceil(average_seconds)::integer))
        end,
        case
            when sample_count >= 5 then 'data_derived'
            when sample_count > 0 then 'limited_history'
            else 'facility_default'
        end
    from aggregate;
$$;

-- The Hub may create only a request for the resident bound to its JWT.  It
-- supplies no facility, resident, room, actor, or timestamp inputs, removing
-- the opportunity to forge a cross-room request.
create or replace function public.create_resident_assistance_request(
    p_request_kind text
)
returns public.assistance_requests
language plpgsql
security definer
set search_path = public
as $$
declare
    v_device public.resident_hub_devices;
    v_request public.assistance_requests;
begin
    if p_request_kind not in ('assistance', 'family_contact', 'emergency') then
        raise exception 'invalid_request_kind' using errcode = '22023';
    end if;

    select * into v_device
    from public.resident_hub_devices
    where hub_user_id = auth.uid() and active
    for update;

    if not found then
        raise exception 'resident_hub_not_authorized' using errcode = '42501';
    end if;

    insert into public.assistance_requests (
        facility_id, resident_id, room_id, request_kind, source
    ) values (
        v_device.facility_id, v_device.resident_id, v_device.room_id,
        p_request_kind, 'resident_hub'
    ) returning * into v_request;

    return v_request;
end;
$$;

-- The care team, not the resident device, controls dispatch lifecycle.  This
-- mirrors respond_to_incident: actor/time columns are server-written and no
-- authenticated role has a direct update grant on status.
create or replace function public.respond_to_assistance_request(
    p_assistance_request_id uuid,
    p_new_status text,
    p_note text default null
)
returns public.assistance_requests
language plpgsql
security definer
set search_path = public
as $$
declare
    v_request public.assistance_requests;
    v_role text;
    v_allowed_next text[];
begin
    select * into v_request
    from public.assistance_requests
    where id = p_assistance_request_id
    for update;

    if not found then
        raise exception 'assistance_request_not_found' using errcode = 'P0002';
    end if;

    select fm.role into v_role
    from public.facility_members fm
    where fm.facility_id = v_request.facility_id
    and fm.user_id = auth.uid();

    if v_role is null or v_role not in ('owner', 'admin', 'caregiver') then
        raise exception 'not_authorized' using errcode = '42501';
    end if;

    v_allowed_next := case v_request.status
        when 'open' then array['acknowledged', 'cancelled']
        when 'acknowledged' then array['en_route', 'resolved', 'cancelled']
        when 'en_route' then array['resolved']
        else array[]::text[]
    end;

    if p_new_status not in ('acknowledged', 'en_route', 'resolved', 'cancelled')
       or not (p_new_status = any(v_allowed_next)) then
        raise exception 'invalid_transition' using errcode = '22023';
    end if;

    update public.assistance_requests
    set status = p_new_status,
        acknowledged_by = coalesce(acknowledged_by, case when p_new_status = 'acknowledged' then auth.uid() else null end),
        acknowledged_at = coalesce(acknowledged_at, case when p_new_status = 'acknowledged' then now() else null end),
        en_route_by = coalesce(en_route_by, case when p_new_status = 'en_route' then auth.uid() else null end),
        en_route_at = coalesce(en_route_at, case when p_new_status = 'en_route' then now() else null end),
        resolved_by = case when p_new_status = 'resolved' then auth.uid() else resolved_by end,
        resolved_at = case when p_new_status = 'resolved' then now() else resolved_at end,
        cancelled_by = case when p_new_status = 'cancelled' then auth.uid() else cancelled_by end,
        cancelled_at = case when p_new_status = 'cancelled' then now() else cancelled_at end,
        resolution_note = coalesce(p_note, resolution_note)
    where id = v_request.id
    returning * into v_request;

    return v_request;
end;
$$;

-- Pending prompts are converted to no_response by any Hub refresh or answer
-- attempt after expiry.  The resident UI calls this before every state query;
-- the server is authoritative and an expired answer is never accepted.
create or replace function public.expire_my_visitor_verification_prompts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count integer;
begin
    update public.visitor_verification_prompts p
    set status = 'no_response'
    where p.status = 'pending'
    and p.expires_at <= now()
    and exists (
        select 1 from public.resident_hub_devices d
        where d.resident_id = p.resident_id
        and d.facility_id = p.facility_id
        and d.hub_user_id = auth.uid()
        and d.active
    );
    get diagnostics v_count = row_count;
    return v_count;
end;
$$;

create or replace function public.respond_to_visitor_verification(
    p_prompt_id uuid,
    p_response text
)
returns public.visitor_verification_prompts
language plpgsql
security definer
set search_path = public
as $$
declare
    v_prompt public.visitor_verification_prompts;
begin
    if p_response not in ('approved', 'denied') then
        raise exception 'invalid_visitor_response' using errcode = '22023';
    end if;

    perform public.expire_my_visitor_verification_prompts();

    select * into v_prompt
    from public.visitor_verification_prompts p
    where p.id = p_prompt_id
    and p.status = 'pending'
    and exists (
        select 1 from public.resident_hub_devices d
        where d.resident_id = p.resident_id
        and d.facility_id = p.facility_id
        and d.hub_user_id = auth.uid()
        and d.active
    )
    for update;

    if not found then
        raise exception 'visitor_prompt_not_found_or_expired' using errcode = 'P0002';
    end if;

    update public.visitor_verification_prompts
    set status = p_response,
        answered_at = now(),
        answered_by = auth.uid()
    where id = v_prompt.id
    returning * into v_prompt;

    if p_response = 'denied' then
        insert into public.notifications (
            facility_id, resident_id, visitor_verification_prompt_id, channel, body, status
        ) values (
            v_prompt.facility_id, null, v_prompt.id, 'push',
            'Resident denied an expected-visitor prompt for room ' || v_prompt.room_id || '. Please check in.',
            'pending'
        );

        update public.visitor_verification_prompts
        set escalation_notified_at = now()
        where id = v_prompt.id
        returning * into v_prompt;
    end if;

    return v_prompt;
end;
$$;

-- Every resident or automatic help request becomes a durable care-team
-- notification.  Family-contact requests additionally notify only linked
-- family where the resident has explicitly consented to family visibility.
create or replace function public.notify_assistance_request()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    insert into public.notifications (
        facility_id, resident_id, assistance_request_id, channel, body, status
    ) values (
        new.facility_id, null, new.id, 'push',
        case new.request_kind
            when 'emergency' then 'Emergency help requested for room ' || new.room_id || '.'
            when 'family_contact' then 'Resident in room ' || new.room_id || ' requested a family call.'
            else 'Assistance requested for room ' || new.room_id || '.'
        end,
        'pending'
    );

    if new.request_kind = 'family_contact' then
        insert into public.notifications (
            facility_id, resident_id, assistance_request_id, channel, body, status
        )
        select new.facility_id, fml.resident_id, new.id, 'push',
               'Your family member asked to speak with you.', 'pending'
        from public.family_member_links fml
        join public.person_consents pc
            on pc.person_id = fml.resident_id
            and pc.consent_scope = 'family_visibility'
            and pc.consent_status = 'active'
        where fml.facility_id = new.facility_id
        and fml.resident_id = new.resident_id;
    end if;

    return new;
end;
$$;

drop trigger if exists assistance_request_notify on public.assistance_requests;
create trigger assistance_request_notify
after insert on public.assistance_requests
for each row execute function public.notify_assistance_request();

-- A confirmed fall is itself the dispatch command.  The unique partial index
-- makes this safe if a backend retry or future ingestion path fires again.
create or replace function public.dispatch_confirmed_fall_assistance()
returns trigger
language plpgsql
set search_path = public
as $$
declare
    v_room_id text;
begin
    if new.event_type = 'fall_confirmed' and new.resident_id is not null then
        select coalesce(
            new.room_id,
            (
                select rp.room_id
                from public.resident_profiles rp
                where rp.person_id = new.resident_id
                and rp.facility_id = new.facility_id
            )
        ) into v_room_id;

        if v_room_id is null then
            raise exception 'fall_dispatch_room_scope_missing' using errcode = '23514';
        end if;

        insert into public.assistance_requests (
            facility_id, resident_id, room_id, incident_id, request_kind, source
        ) values (
            new.facility_id, new.resident_id, v_room_id,
            new.id, 'emergency', 'auto_fall_dispatch'
        ) on conflict (incident_id) where source = 'auto_fall_dispatch' do nothing;
    end if;
    return new;
end;
$$;

drop trigger if exists confirmed_fall_assistance_dispatch on public.incident_events;
create trigger confirmed_fall_assistance_dispatch
after insert on public.incident_events
for each row execute function public.dispatch_confirmed_fall_assistance();

-- Unknown/new visitor observations are routed only to the resident whose Hub
-- was provisioned for that entry camera.  This avoids broadcasting an entry
-- event across unrelated rooms while still allowing one resident's Hub to
-- ask the useful, bounded question: "Is this person expected?"
create or replace function public.create_resident_visitor_verification_prompts()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if new.match_status not in ('new_visitor', 'unknown') then
        return new;
    end if;

    insert into public.visitor_verification_prompts (
        facility_id, resident_id, room_id, observation_id, camera_id, expires_at
    )
    select d.facility_id, d.resident_id, d.room_id, new.id, new.camera_id,
           now() + interval '2 minutes'
    from public.resident_hub_devices d
    where d.active
    and d.facility_id = new.facility_id
    and d.visitor_camera_id = new.camera_id
    on conflict (observation_id, resident_id) do nothing;

    return new;
end;
$$;

drop trigger if exists resident_visitor_verification_prompt on public.visitor_face_observations;
create trigger resident_visitor_verification_prompt
after insert on public.visitor_face_observations
for each row execute function public.create_resident_visitor_verification_prompts();

alter table public.resident_hub_devices enable row level security;
alter table public.assistance_requests enable row level security;
alter table public.visitor_verification_prompts enable row level security;

revoke all on public.resident_hub_devices from anon, authenticated;
revoke all on public.assistance_requests from anon, authenticated;
revoke all on public.visitor_verification_prompts from anon, authenticated;

grant all on public.resident_hub_devices to service_role;
grant all on public.assistance_requests to service_role;
grant all on public.visitor_verification_prompts to service_role;

-- Defense in depth: the Hub receives no direct table grants today, but these
-- policies remain correct if a future narrowly-scoped grant is introduced.
create policy "care team can manage resident hub devices"
on public.resident_hub_devices
for all to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = resident_hub_devices.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin')
))
with check (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = resident_hub_devices.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin')
));

create policy "care team can read assistance requests"
on public.assistance_requests
for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = assistance_requests.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin', 'caregiver', 'viewer')
));

create policy "resident hub can read own assistance requests"
on public.assistance_requests
for select to authenticated
using (exists (
    select 1 from public.resident_hub_devices d
    where d.facility_id = assistance_requests.facility_id
    and d.resident_id = assistance_requests.resident_id
    and d.room_id = assistance_requests.room_id
    and d.hub_user_id = auth.uid()
    and d.active
));

create policy "care team can read visitor verification prompts"
on public.visitor_verification_prompts
for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = visitor_verification_prompts.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin', 'caregiver')
));

create policy "resident hub can read own visitor verification prompts"
on public.visitor_verification_prompts
for select to authenticated
using (exists (
    select 1 from public.resident_hub_devices d
    where d.facility_id = visitor_verification_prompts.facility_id
    and d.resident_id = visitor_verification_prompts.resident_id
    and d.room_id = visitor_verification_prompts.room_id
    and d.hub_user_id = auth.uid()
    and d.active
));

-- These views are security-definer intentionally, like family_incident_feed.
-- They are the resident device's only read path and project only the content
-- safe to show on a room display.
create or replace view public.resident_hub_profile
as
select d.facility_id, d.resident_id, d.room_id, rp.display_name
from public.resident_hub_devices d
join public.resident_profiles rp on rp.person_id = d.resident_id
where d.hub_user_id = auth.uid()
and d.active;

create or replace view public.resident_hub_assistance_feed
as
select
    ar.id,
    ar.request_kind,
    ar.source,
    ar.status,
    ar.requested_at,
    ar.acknowledged_at,
    ar.en_route_at,
    ar.resolved_at,
    ar.cancelled_at,
    eta.eta_seconds,
    eta.eta_confidence
from public.assistance_requests ar
cross join lateral public.estimate_assistance_eta(ar.facility_id) eta
where exists (
    select 1 from public.resident_hub_devices d
    where d.facility_id = ar.facility_id
    and d.resident_id = ar.resident_id
    and d.room_id = ar.room_id
    and d.hub_user_id = auth.uid()
    and d.active
);

create or replace view public.resident_hub_visitor_prompt_feed
as
select
    p.id,
    p.status,
    p.prompted_at,
    p.expires_at,
    p.answered_at,
    p.escalation_notified_at,
    p.camera_id,
    v.body_description,
    v.detected_at
from public.visitor_verification_prompts p
join public.visitor_face_observations v on v.id = p.observation_id
where exists (
    select 1 from public.resident_hub_devices d
    where d.facility_id = p.facility_id
    and d.resident_id = p.resident_id
    and d.room_id = p.room_id
    and d.hub_user_id = auth.uid()
    and d.active
);

grant select on public.resident_hub_profile to authenticated;
grant select on public.resident_hub_assistance_feed to authenticated;
grant select on public.resident_hub_visitor_prompt_feed to authenticated;

revoke all on function public.create_resident_assistance_request(text) from public;
revoke all on function public.respond_to_assistance_request(uuid, text, text) from public;
revoke all on function public.expire_my_visitor_verification_prompts() from public;
revoke all on function public.respond_to_visitor_verification(uuid, text) from public;
grant execute on function public.create_resident_assistance_request(text) to authenticated;
grant execute on function public.respond_to_assistance_request(uuid, text, text) to authenticated;
grant execute on function public.expire_my_visitor_verification_prompts() to authenticated;
grant execute on function public.respond_to_visitor_verification(uuid, text) to authenticated;
