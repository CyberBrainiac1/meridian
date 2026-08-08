-- Emergency SMS is an escalation channel, not a replacement for the normal
-- in-app notification path.  It deliberately has its own consent, queue and
-- delivery audit records so a generic `notifications` row can never cause an
-- unconsented text.

create table if not exists public.facility_sms_escalation_policies (
    facility_id text primary key references public.facilities(id) on delete cascade,
    enabled boolean not null default true,
    escalation_delay_seconds integer not null default 300
        check (escalation_delay_seconds between 60 and 900),
    max_messages_per_recipient_24h integer not null default 3
        check (max_messages_per_recipient_24h between 1 and 10),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- A phone number belongs to the family account and its link to one resident.
-- Revoked rows are retained as audit history; a later re-opt-in creates a new
-- row and therefore a fresh, explicit consent event.
create table if not exists public.family_sms_preferences (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    family_user_id uuid not null references auth.users(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    phone_e164 text not null check (phone_e164 ~ '^\\+[1-9][0-9]{7,14}$'),
    consent_status text not null default 'opted_in'
        check (consent_status in ('opted_in', 'revoked')),
    consent_source text not null,
    consent_text_version text not null,
    opted_in_at timestamptz not null default now(),
    revoked_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (
        (consent_status = 'opted_in' and revoked_at is null)
        or (consent_status = 'revoked' and revoked_at is not null)
    )
);

create unique index if not exists family_sms_preferences_one_active_link_idx
    on public.family_sms_preferences (family_user_id, resident_id)
    where consent_status = 'opted_in';

create index if not exists family_sms_preferences_dispatch_idx
    on public.family_sms_preferences (facility_id, resident_id)
    where consent_status = 'opted_in';

create table if not exists public.family_sms_consent_events (
    id uuid primary key default gen_random_uuid(),
    preference_id uuid not null references public.family_sms_preferences(id) on delete restrict,
    facility_id text not null references public.facilities(id) on delete cascade,
    family_user_id uuid not null references auth.users(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    phone_e164 text not null,
    event_type text not null check (event_type in ('opted_in', 'revoked')),
    consent_source text not null,
    consent_text_version text not null,
    occurred_at timestamptz not null default now()
);

create table if not exists public.family_sms_recipient_rate_windows (
    preference_id uuid primary key references public.family_sms_preferences(id) on delete cascade,
    window_started_at timestamptz not null,
    reserved_count integer not null default 0 check (reserved_count >= 0),
    updated_at timestamptz not null default now()
);

-- One row is the durable decision for one incident/recipient.  The unique
-- pair is the idempotency boundary; individual delivery attempts live below.
create table if not exists public.family_sms_escalations (
    id uuid primary key default gen_random_uuid(),
    incident_id uuid not null references public.incident_events(id) on delete cascade,
    preference_id uuid not null references public.family_sms_preferences(id) on delete restrict,
    facility_id text not null references public.facilities(id) on delete cascade,
    resident_id text not null references public.people(id) on delete cascade,
    body text not null,
    status text not null default 'pending' check (
        status in (
            'pending', 'claimed', 'provider_accepted', 'delivered', 'undelivered', 'failed',
            'unknown_outcome', 'suppressed_rate_limited', 'suppressed_consent_revoked',
            'suppressed_resident_visibility_revoked'
        )
    ),
    idempotency_key text not null unique,
    scheduled_at timestamptz not null default now(),
    claimed_at timestamptz,
    completed_at timestamptz,
    last_error_code text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (incident_id, preference_id)
);

create index if not exists family_sms_escalations_claim_idx
    on public.family_sms_escalations (status, scheduled_at)
    where status = 'pending';

create table if not exists public.family_sms_delivery_attempts (
    id uuid primary key default gen_random_uuid(),
    escalation_id uuid not null references public.family_sms_escalations(id) on delete cascade,
    attempt_number integer not null check (attempt_number > 0),
    provider text not null,
    provider_message_id text,
    status text not null check (
        status in ('claimed', 'provider_accepted', 'delivered', 'failed', 'undelivered', 'unknown_outcome')
    ),
    provider_status text,
    error_code text,
    error_message text,
    attempted_at timestamptz not null default now(),
    completed_at timestamptz,
    created_at timestamptz not null default now(),
    unique (escalation_id, attempt_number),
    unique (provider, provider_message_id)
);

create index if not exists family_sms_delivery_attempts_provider_message_idx
    on public.family_sms_delivery_attempts (provider, provider_message_id)
    where provider_message_id is not null;

create or replace function public.assert_family_sms_preference_link()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if not exists (
        select 1
        from public.family_member_links fml
        where fml.facility_id = new.facility_id
        and fml.user_id = new.family_user_id
        and fml.resident_id = new.resident_id
    ) then
        raise exception 'family_sms_preference_requires_family_link' using errcode = '23514';
    end if;

    if tg_op = 'UPDATE' and old.consent_status = 'revoked' then
        raise exception 'revoked_sms_consent_is_immutable' using errcode = '22023';
    end if;

    return new;
end;
$$;

drop trigger if exists family_sms_preferences_link_guard on public.family_sms_preferences;
create trigger family_sms_preferences_link_guard
before insert or update on public.family_sms_preferences
for each row execute function public.assert_family_sms_preference_link();

create or replace function public.audit_family_sms_consent()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if tg_op = 'INSERT' then
        insert into public.family_sms_consent_events (
            preference_id, facility_id, family_user_id, resident_id, phone_e164,
            event_type, consent_source, consent_text_version, occurred_at
        ) values (
            new.id, new.facility_id, new.family_user_id, new.resident_id, new.phone_e164,
            'opted_in', new.consent_source, new.consent_text_version, new.opted_in_at
        );
    elsif old.consent_status = 'opted_in' and new.consent_status = 'revoked' then
        insert into public.family_sms_consent_events (
            preference_id, facility_id, family_user_id, resident_id, phone_e164,
            event_type, consent_source, consent_text_version, occurred_at
        ) values (
            new.id, new.facility_id, new.family_user_id, new.resident_id, new.phone_e164,
            'revoked', new.consent_source, new.consent_text_version, new.revoked_at
        );
    end if;
    return new;
end;
$$;

drop trigger if exists family_sms_preferences_consent_audit on public.family_sms_preferences;
create trigger family_sms_preferences_consent_audit
after insert or update of consent_status on public.family_sms_preferences
for each row execute function public.audit_family_sms_consent();

drop trigger if exists set_facility_sms_escalation_policies_updated_at on public.facility_sms_escalation_policies;
create trigger set_facility_sms_escalation_policies_updated_at
before update on public.facility_sms_escalation_policies
for each row execute function public.set_updated_at();

drop trigger if exists set_family_sms_preferences_updated_at on public.family_sms_preferences;
create trigger set_family_sms_preferences_updated_at
before update on public.family_sms_preferences
for each row execute function public.set_updated_at();

drop trigger if exists set_family_sms_escalations_updated_at on public.family_sms_escalations;
create trigger set_family_sms_escalations_updated_at
before update on public.family_sms_escalations
for each row execute function public.set_updated_at();

-- Family users explicitly opt in or revoke their own number.  A revocation
-- never deletes history and a new opt-in gets a new immutable consent row.
create or replace function public.set_my_family_sms_consent(
    p_resident_id text,
    p_phone_e164 text,
    p_opt_in boolean,
    p_consent_source text,
    p_consent_text_version text
)
returns public.family_sms_preferences
language plpgsql
security definer
set search_path = public
as $$
declare
    v_link public.family_member_links;
    v_preference public.family_sms_preferences;
begin
    select * into v_link
    from public.family_member_links fml
    where fml.user_id = auth.uid()
    and fml.resident_id = p_resident_id;

    if not found then
        raise exception 'family_link_not_found' using errcode = '42501';
    end if;

    if p_opt_in then
        if p_phone_e164 !~ '^\\+[1-9][0-9]{7,14}$' then
            raise exception 'invalid_e164_phone_number' using errcode = '22023';
        end if;
        if nullif(trim(p_consent_source), '') is null or nullif(trim(p_consent_text_version), '') is null then
            raise exception 'consent_source_and_text_version_required' using errcode = '22023';
        end if;

        insert into public.family_sms_preferences (
            facility_id, family_user_id, resident_id, phone_e164, consent_status,
            consent_source, consent_text_version
        ) values (
            v_link.facility_id, auth.uid(), p_resident_id, p_phone_e164, 'opted_in',
            p_consent_source, p_consent_text_version
        ) returning * into v_preference;
    else
        update public.family_sms_preferences
        set consent_status = 'revoked', revoked_at = now()
        where family_user_id = auth.uid()
        and resident_id = p_resident_id
        and consent_status = 'opted_in'
        returning * into v_preference;

        if not found then
            raise exception 'active_sms_consent_not_found' using errcode = 'P0002';
        end if;
    end if;

    return v_preference;
end;
$$;

-- Evaluate the escalation entirely in Postgres, next to the authoritative
-- acknowledgement timestamp.  The worker may call this repeatedly: the
-- incident/preference unique constraint and the locked rate window make it
-- idempotent and prevent a flapping source from reserving endless texts.
create or replace function public.queue_family_sms_escalations(
    p_limit integer default 100
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_candidate record;
    v_window public.family_sms_recipient_rate_windows;
    v_reserved_count integer;
    v_queued integer := 0;
begin
    if p_limit < 1 or p_limit > 500 then
        raise exception 'invalid_queue_limit' using errcode = '22023';
    end if;

    for v_candidate in
        select
            ie.id as incident_id,
            ie.facility_id,
            ie.resident_id,
            pref.id as preference_id,
            policy.max_messages_per_recipient_24h
        from public.incident_events ie
        join public.family_sms_preferences pref
            on pref.facility_id = ie.facility_id
            and pref.resident_id = ie.resident_id
            and pref.consent_status = 'opted_in'
        left join public.facility_sms_escalation_policies configured_policy
            on configured_policy.facility_id = ie.facility_id
        cross join lateral (
            select
                coalesce(configured_policy.enabled, true) as enabled,
                coalesce(configured_policy.escalation_delay_seconds, 300) as escalation_delay_seconds,
                coalesce(configured_policy.max_messages_per_recipient_24h, 3) as max_messages_per_recipient_24h
        ) policy
        where ie.severity = 'critical'
        and ie.resident_id is not null
        and ie.acknowledged_at is null
        and ie.resolved_at is null
        and ie.status in ('open', 'escalated')
        and policy.enabled
        and ie.detected_at <= now() - make_interval(secs => policy.escalation_delay_seconds)
        and exists (
            select 1
            from public.person_consents pc
            where pc.facility_id = ie.facility_id
            and pc.person_id = ie.resident_id
            and pc.consent_scope = 'family_visibility'
            and pc.consent_status = 'active'
        )
        and not exists (
            select 1
            from public.family_sms_escalations existing
            where existing.incident_id = ie.id
            and existing.preference_id = pref.id
        )
        order by ie.detected_at asc
        limit p_limit
    loop
        perform pg_advisory_xact_lock(hashtextextended(v_candidate.preference_id::text, 0));

        -- A concurrent worker may have created it while this worker waited.
        if exists (
            select 1 from public.family_sms_escalations existing
            where existing.incident_id = v_candidate.incident_id
            and existing.preference_id = v_candidate.preference_id
        ) then
            continue;
        end if;

        select * into v_window
        from public.family_sms_recipient_rate_windows w
        where w.preference_id = v_candidate.preference_id
        for update;

        if not found then
            insert into public.family_sms_recipient_rate_windows (
                preference_id, window_started_at, reserved_count
            ) values (v_candidate.preference_id, now(), 0)
            returning * into v_window;
        elsif v_window.window_started_at <= now() - interval '24 hours' then
            update public.family_sms_recipient_rate_windows
            set window_started_at = now(), reserved_count = 0
            where preference_id = v_candidate.preference_id
            returning * into v_window;
        end if;

        v_reserved_count := v_window.reserved_count;
        if v_reserved_count >= v_candidate.max_messages_per_recipient_24h then
            insert into public.family_sms_escalations (
                incident_id, preference_id, facility_id, resident_id, body, status, idempotency_key,
                completed_at, last_error_code
            ) values (
                v_candidate.incident_id, v_candidate.preference_id, v_candidate.facility_id,
                v_candidate.resident_id, 'Critical incident remains unacknowledged. Open MeridianFamily for details.',
                'suppressed_rate_limited',
                encode(digest(v_candidate.incident_id::text || ':' || v_candidate.preference_id::text, 'sha256'), 'hex'),
                now(), 'recipient_rate_limit'
            );
        else
            update public.family_sms_recipient_rate_windows
            set reserved_count = reserved_count + 1
            where preference_id = v_candidate.preference_id;

            insert into public.family_sms_escalations (
                incident_id, preference_id, facility_id, resident_id, body, idempotency_key
            ) values (
                v_candidate.incident_id, v_candidate.preference_id, v_candidate.facility_id,
                v_candidate.resident_id, 'Critical incident remains unacknowledged. Open MeridianFamily for details.',
                encode(digest(v_candidate.incident_id::text || ':' || v_candidate.preference_id::text, 'sha256'), 'hex')
            );
        end if;
        v_queued := v_queued + 1;
    end loop;

    return v_queued;
end;
$$;

-- Claiming creates the attempt before the provider call.  A claimed attempt
-- is never auto-retried because an HTTP timeout can mean Twilio accepted the
-- message; this favors no duplicate emergency text over uncertain retry.
create or replace function public.claim_family_sms_escalations(
    p_limit integer default 25
)
returns table (
    escalation_id uuid,
    attempt_id uuid,
    phone_e164 text,
    body text,
    idempotency_key text
)
language plpgsql
security definer
set search_path = public
as $$
begin
    if p_limit < 1 or p_limit > 100 then
        raise exception 'invalid_claim_limit' using errcode = '22023';
    end if;

    return query
    with candidates as (
        select escalation.id
        from public.family_sms_escalations escalation
        join public.family_sms_preferences pref on pref.id = escalation.preference_id
        join public.incident_events ie on ie.id = escalation.incident_id
        where escalation.status = 'pending'
        and pref.consent_status = 'opted_in'
        and ie.acknowledged_at is null
        and ie.resolved_at is null
        and ie.status in ('open', 'escalated')
        and exists (
            select 1
            from public.person_consents pc
            where pc.facility_id = ie.facility_id
            and pc.person_id = ie.resident_id
            and pc.consent_scope = 'family_visibility'
            and pc.consent_status = 'active'
        )
        order by escalation.scheduled_at asc
        limit p_limit
        for update of escalation skip locked
    ), claimed as (
        update public.family_sms_escalations escalation
        set status = 'claimed', claimed_at = now()
        from candidates
        where escalation.id = candidates.id
        returning escalation.*
    ), attempts as (
        insert into public.family_sms_delivery_attempts (
            escalation_id, attempt_number, provider, status
        )
        select claimed.id, 1, 'twilio', 'claimed'
        from claimed
        returning id, escalation_id
    )
    select claimed.id, attempts.id, pref.phone_e164, claimed.body, claimed.idempotency_key
    from claimed
    join attempts on attempts.escalation_id = claimed.id
    join public.family_sms_preferences pref on pref.id = claimed.preference_id;

    -- Revocation may race a queue entry.  Record the suppression instead of
    -- sending, and make the result visible to the audit trail.
    update public.family_sms_escalations escalation
    set status = 'suppressed_consent_revoked', completed_at = now(),
        last_error_code = 'consent_revoked_before_claim'
    from public.family_sms_preferences pref
    where escalation.preference_id = pref.id
    and escalation.status = 'pending'
    and pref.consent_status = 'revoked';

    update public.family_sms_escalations escalation
    set status = 'suppressed_resident_visibility_revoked', completed_at = now(),
        last_error_code = 'resident_family_visibility_revoked'
    from public.incident_events ie
    where escalation.incident_id = ie.id
    and escalation.status = 'pending'
    and not exists (
        select 1
        from public.person_consents pc
        where pc.facility_id = ie.facility_id
        and pc.person_id = ie.resident_id
        and pc.consent_scope = 'family_visibility'
        and pc.consent_status = 'active'
    );
end;
$$;

create or replace function public.complete_family_sms_attempt(
    p_attempt_id uuid,
    p_provider_message_id text,
    p_outcome text,
    p_provider_status text default null,
    p_error_code text default null,
    p_error_message text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_attempt public.family_sms_delivery_attempts;
begin
    if p_outcome not in ('provider_accepted', 'failed', 'unknown_outcome') then
        raise exception 'invalid_sms_attempt_outcome' using errcode = '22023';
    end if;

    select * into v_attempt
    from public.family_sms_delivery_attempts attempt
    where attempt.id = p_attempt_id
    for update;

    if not found or v_attempt.status <> 'claimed' then
        raise exception 'sms_attempt_not_claimed' using errcode = 'P0002';
    end if;

    update public.family_sms_delivery_attempts
    set provider_message_id = p_provider_message_id,
        status = p_outcome,
        provider_status = p_provider_status,
        error_code = p_error_code,
        error_message = p_error_message,
        completed_at = now()
    where id = p_attempt_id;

    update public.family_sms_escalations
    set status = p_outcome,
        completed_at = case when p_outcome = 'provider_accepted' then null else now() end,
        last_error_code = p_error_code
    where id = v_attempt.escalation_id;
end;
$$;

create or replace function public.record_family_sms_provider_status(
    p_provider text,
    p_provider_message_id text,
    p_provider_status text,
    p_error_code text default null,
    p_error_message text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_attempt public.family_sms_delivery_attempts;
    v_terminal_status text;
begin
    if p_provider_status not in ('delivered', 'undelivered', 'failed') then
        return;
    end if;

    select * into v_attempt
    from public.family_sms_delivery_attempts attempt
    where attempt.provider = p_provider
    and attempt.provider_message_id = p_provider_message_id
    for update;

    if not found then
        return;
    end if;

    v_terminal_status := p_provider_status;
    update public.family_sms_delivery_attempts
    set status = v_terminal_status,
        provider_status = p_provider_status,
        error_code = p_error_code,
        error_message = p_error_message,
        completed_at = now()
    where id = v_attempt.id;

    update public.family_sms_escalations
    set status = v_terminal_status,
        completed_at = now(),
        last_error_code = p_error_code
    where id = v_attempt.escalation_id;
end;
$$;

alter table public.facility_sms_escalation_policies enable row level security;
alter table public.family_sms_preferences enable row level security;
alter table public.family_sms_consent_events enable row level security;
alter table public.family_sms_recipient_rate_windows enable row level security;
alter table public.family_sms_escalations enable row level security;
alter table public.family_sms_delivery_attempts enable row level security;

revoke all on public.facility_sms_escalation_policies from anon, authenticated;
revoke all on public.family_sms_preferences from anon, authenticated;
revoke all on public.family_sms_consent_events from anon, authenticated;
revoke all on public.family_sms_recipient_rate_windows from anon, authenticated;
revoke all on public.family_sms_escalations from anon, authenticated;
revoke all on public.family_sms_delivery_attempts from anon, authenticated;

grant select on public.facility_sms_escalation_policies to authenticated;
grant select on public.family_sms_preferences to authenticated;
grant select on public.family_sms_consent_events to authenticated;
grant insert, update on public.facility_sms_escalation_policies to authenticated;
grant all on public.facility_sms_escalation_policies to service_role;
grant all on public.family_sms_preferences to service_role;
grant all on public.family_sms_consent_events to service_role;
grant all on public.family_sms_recipient_rate_windows to service_role;
grant all on public.family_sms_escalations to service_role;
grant all on public.family_sms_delivery_attempts to service_role;

create policy "family can read own sms preferences"
on public.family_sms_preferences
for select to authenticated
using (family_user_id = auth.uid());

create policy "family can read own sms consent audit"
on public.family_sms_consent_events
for select to authenticated
using (family_user_id = auth.uid());

create policy "facility admins can read sms escalation policy"
on public.facility_sms_escalation_policies
for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = facility_sms_escalation_policies.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin')
));

create policy "facility admins can manage sms escalation policy"
on public.facility_sms_escalation_policies
for all to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = facility_sms_escalation_policies.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin')
))
with check (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = facility_sms_escalation_policies.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin')
));

create policy "facility admins can read sms preferences"
on public.family_sms_preferences
for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = family_sms_preferences.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin')
));

create policy "facility admins can read sms audit"
on public.family_sms_consent_events
for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = family_sms_consent_events.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin')
));

create policy "facility care team can read sms delivery audit"
on public.family_sms_escalations
for select to authenticated
using (exists (
    select 1 from public.facility_members fm
    where fm.facility_id = family_sms_escalations.facility_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin', 'caregiver')
));

create policy "facility care team can read sms attempt audit"
on public.family_sms_delivery_attempts
for select to authenticated
using (exists (
    select 1
    from public.family_sms_escalations escalation
    join public.facility_members fm on fm.facility_id = escalation.facility_id
    where escalation.id = family_sms_delivery_attempts.escalation_id
    and fm.user_id = auth.uid()
    and fm.role in ('owner', 'admin', 'caregiver')
));

revoke all on function public.set_my_family_sms_consent(text, text, boolean, text, text) from public;
revoke all on function public.queue_family_sms_escalations(integer) from public;
revoke all on function public.claim_family_sms_escalations(integer) from public;
revoke all on function public.complete_family_sms_attempt(uuid, text, text, text, text, text) from public;
revoke all on function public.record_family_sms_provider_status(text, text, text, text, text) from public;
grant execute on function public.set_my_family_sms_consent(text, text, boolean, text, text) to authenticated;
grant execute on function public.queue_family_sms_escalations(integer) to service_role;
grant execute on function public.claim_family_sms_escalations(integer) to service_role;
grant execute on function public.complete_family_sms_attempt(uuid, text, text, text, text, text) to service_role;
grant execute on function public.record_family_sms_provider_status(text, text, text, text, text) to service_role;
