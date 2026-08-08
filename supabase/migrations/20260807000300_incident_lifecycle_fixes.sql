-- Three defects found while tracing two caregivers acting on one incident, and
-- while checking what facility_response_metrics actually measures.
--
--   1. Acknowledge was not idempotent.  Two caregivers tapping Acknowledge on
--      the same open incident both intend the same end state, but the second
--      one hit 'invalid_transition' because 'acknowledged' was absent from its
--      own allowed_next list.  An error for an action that already succeeded
--      trains staff to ignore errors.  Re-asserting the current status is now
--      a no-op that returns the row.
--
--   2. 'escalated' was terminal (allowed_next was empty), so an escalated fall
--      could never be resolved or closed.  Escalation raises attention; it is
--      not the end of the incident.
--
--   3. acknowledged_at was written only on the literal 'acknowledged'
--      transition.  A caregiver who goes straight from open to Responding or
--      Resolve left it NULL, and facility_response_metrics filters on
--      `acknowledged_at is not null` -- so the fastest responders were dropped
--      from the compliance average entirely, biasing it slow.  Any first
--      human response now stamps it.
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
    v_first_response boolean;
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

    -- Idempotent re-assert: the caller's intent already holds.  Only the note
    -- is merged, so a second caregiver adding context is not lost.
    if p_new_status = v_incident.status then
        if p_note is not null then
            update public.incident_events
            set resolution_note = p_note
            where id = p_incident_id
            returning * into v_incident;
        end if;
        return v_incident;
    end if;

    v_allowed_next := case v_incident.status
        when 'open' then array['acknowledged', 'responding', 'resolved', 'dismissed_false_alarm', 'escalated']
        when 'acknowledged' then array['responding', 'resolved', 'dismissed_false_alarm', 'escalated']
        when 'responding' then array['resolved', 'dismissed_false_alarm', 'escalated']
        -- An escalated incident still has to be closed out by someone.
        when 'escalated' then array['responding', 'resolved', 'dismissed_false_alarm']
        else array[]::text[]
    end;

    if not (p_new_status = any(v_allowed_next)) then
        raise exception 'invalid_transition' using errcode = '22023';
    end if;

    -- Any first move off 'open' is the moment a human took the alert.
    v_first_response := v_incident.acknowledged_at is null;

    update public.incident_events
    set status = p_new_status,
        acknowledged_by = coalesce(acknowledged_by, case when v_first_response then auth.uid() else acknowledged_by end),
        acknowledged_at = coalesce(acknowledged_at, case when v_first_response then now() else acknowledged_at end),
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

-- The metrics view previously reported "time to acknowledge" without saying
-- what that interval excludes.  detected_at is stamped on the Hub at the frame
-- that CONFIRMS a fall, which is already 2-3s after floor contact because of
-- the stillness-confirmation window.  Recording that here keeps anyone reading
-- the view from restating it as end-to-end detection latency.
comment on view public.facility_response_metrics is 'avg_ack_seconds spans Hub fall-confirmation (detected_at) to first human response (acknowledged_at). It EXCLUDES camera capture latency and the stillness-confirmation window (~2-3s), so it is not end-to-end floor-contact-to-staff latency.';
