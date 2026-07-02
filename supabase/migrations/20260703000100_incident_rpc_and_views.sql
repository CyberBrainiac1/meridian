-- Single write path for incident state. Security definer so it can write
-- acknowledged_by/resolved_by/*_at columns that authenticated users have
-- no direct column grant on (see prior migration's revoke), and so it can
-- insert into notifications regardless of the caller's own grants.
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

-- Care-team views: security_invoker so they inherit the RLS already
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
