-- Two defects found by driving the resident Hub against a seeded facility.
--
--   1. estimate_assistance_eta could never return a measured ETA to a Hub.
--      The function is plain STABLE, so it executes with the caller's rights,
--      and a Hub device is deliberately NOT a facility_members row -- it has no
--      select policy on incident_events at all.  Every call therefore saw zero
--      rows, fell through to sample_count = 0, and returned the conservative
--      300s 'facility_default' no matter how much acknowledgement history the
--      building had.  The resident was shown "no response history for this
--      building yet" on a facility with hundreds of answered calls.
--
--      SECURITY DEFINER is safe here and nowhere near as broad as it looks:
--      the function returns only a clamped scalar average plus a confidence
--      label for one facility id, never a row, an identifier, or a timestamp.
--      The facility id itself is not attacker-chosen from the Hub -- the view
--      passes ar.facility_id, which RLS has already constrained to the
--      device's own facility.
create or replace function public.estimate_assistance_eta(p_facility_id text)
returns table (eta_seconds integer, eta_confidence text)
language sql
stable
security definer
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

revoke all on function public.estimate_assistance_eta(text) from public;
grant execute on function public.estimate_assistance_eta(text) to authenticated;

--   2. Notification fan-out was multiplied by duplicate consent rows.
--      notify_assistance_request JOINed person_consents, so a resident holding
--      two active family_visibility consent rows produced two identical push
--      notifications per family member.  person_consents has no uniqueness
--      constraint on (person_id, consent_scope) except for face_recognition,
--      so this is reachable in normal operation, and the failure mode is
--      alarming: a family member is told twice that their relative asked to
--      speak with them.  EXISTS tests the same condition without multiplying
--      rows.  The same fix is applied to the visitor-arrival trigger, which
--      had the identical shape.
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
        where fml.facility_id = new.facility_id
        and fml.resident_id = new.resident_id
        and exists (
            select 1
            from public.person_consents pc
            where pc.person_id = fml.resident_id
            and pc.facility_id = fml.facility_id
            and pc.consent_scope = 'family_visibility'
            and pc.consent_status = 'active'
        );
    end if;

    return new;
end;
$$;

create or replace function public.notify_visitor_arrival()
returns trigger
language plpgsql
set search_path = public
as $$
declare
    v_camera_label text;
    v_care_body text;
begin
    if new.match_status not in ('new_visitor', 'unknown') then
        return new;
    end if;

    select coalesce(c.display_name, c.location_label, c.external_id) into v_camera_label
    from public.cameras c
    where c.id = new.camera_id;

    v_care_body := 'New visitor detected at ' || coalesce(v_camera_label, 'an entry point');
    if new.body_description is not null and length(new.body_description) > 0 then
        v_care_body := v_care_body || ': ' || new.body_description;
    else
        v_care_body := v_care_body || '.';
    end if;

    insert into public.notifications (facility_id, resident_id, incident_id, channel, body, status)
    values (new.facility_id, null, null, 'push', v_care_body, 'pending');

    insert into public.notifications (facility_id, resident_id, incident_id, channel, body, status)
    select fml.facility_id, fml.resident_id, null, 'push',
           'A new visitor was detected at the facility.',
           'pending'
    from public.family_member_links fml
    where fml.facility_id = new.facility_id
    and exists (
        select 1
        from public.person_consents pc
        where pc.person_id = fml.resident_id
        and pc.facility_id = fml.facility_id
        and pc.consent_scope = 'family_visibility'
        and pc.consent_status = 'active'
    );

    return new;
end;
$$;

-- Removing the duplicates that the join was multiplying, then preventing new
-- ones. Partial-unique on the active rows only, so revoked consent history is
-- still retained as an audit trail.
delete from public.person_consents pc
where exists (
    select 1 from public.person_consents keep
    where keep.person_id = pc.person_id
    and keep.facility_id = pc.facility_id
    and keep.consent_scope = pc.consent_scope
    and keep.consent_status = pc.consent_status
    and keep.consent_status = 'active'
    and keep.created_at < pc.created_at
);

create unique index if not exists person_consents_active_scope_idx
    on public.person_consents (facility_id, person_id, consent_scope)
    where consent_status = 'active';
