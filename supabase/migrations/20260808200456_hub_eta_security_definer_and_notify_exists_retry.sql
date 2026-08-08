
-- Retry of the two remaining fixes from 20260807000400 that never took
-- effect via the dashboard SQL editor paste (confirmed live: prosecdef was
-- still false, and both notify_* functions still used JOIN). Applied
-- directly via migration tooling this time, verified immediately after.

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
