-- When a face at an entry-point camera doesn't match anyone in the local
-- known-person store (match_status new_visitor/unknown), proactively
-- notify both audiences through the same notifications/notify-family
-- pipeline already used for incidents — visitor arrivals shouldn't be a
-- separate, easy-to-forget notification path.
--
-- Two notification rows per qualifying arrival:
--   * one facility-wide row (resident_id null) for the care team — read
--     via the existing "care team can read notifications" policy, which
--     already has no resident_id restriction.
--   * one row per family_member_link whose resident has an active
--     family_visibility consent at that facility — read via the existing
--     "family can read own resident notifications" policy.
--
-- No SECURITY DEFINER needed: visitor_face_observations can only be
-- written by the service role (ingest-visitor-face), which already has
-- full grants on notifications, so the trigger runs with sufficient
-- privilege as-is.
create or replace function public.notify_visitor_arrival()
returns trigger
language plpgsql
set search_path = public
as $$
declare
    v_camera_label text;
begin
    if new.match_status not in ('new_visitor', 'unknown') then
        return new;
    end if;

    select coalesce(c.display_name, c.location_label, c.external_id) into v_camera_label
    from public.cameras c
    where c.id = new.camera_id;

    insert into public.notifications (facility_id, resident_id, incident_id, channel, body, status)
    values (
        new.facility_id, null, null, 'push',
        'New visitor detected at ' || coalesce(v_camera_label, 'an entry point') || '.',
        'pending'
    );

    insert into public.notifications (facility_id, resident_id, incident_id, channel, body, status)
    select fml.facility_id, fml.resident_id, null, 'push',
           'A new visitor was detected at the facility.',
           'pending'
    from public.family_member_links fml
    join public.person_consents pc
        on pc.person_id = fml.resident_id
        and pc.consent_scope = 'family_visibility'
        and pc.consent_status = 'active'
    where fml.facility_id = new.facility_id;

    return new;
end;
$$;

drop trigger if exists visitor_arrival_notify on public.visitor_face_observations;
create trigger visitor_arrival_notify
after insert on public.visitor_face_observations
for each row execute function public.notify_visitor_arrival();
