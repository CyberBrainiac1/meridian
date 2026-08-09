-- Lets a resident hub device self-report a medication dose as taken, via a
-- tappable "today's reminders" checklist on the resident surface.
--
-- This is a deliberate, explicit reversal of a prior product decision: the
-- medication card on the Hub used to be informational-only (see the "residents
-- do not self-administer" comment removed from hub-surface.tsx, and PRD.md's
-- "event logged when med cart reaches the room" adherence model). That
-- decision was about *clinical verification* -- a resident's tap is not proof
-- a dose was actually taken correctly, and must never be conflated with a
-- caregiver having watched it happen.
--
-- self_reported is how that boundary stays visible everywhere
-- medication_administrations is read: a caregiver or auditor can always tell
-- "resident says they took it" apart from "staff verified it". The RPC also
-- never overwrites a row staff already wrote -- a resident's tap only fills
-- the gap when nothing has been recorded for that dose yet.

alter table public.medication_administrations
    add column if not exists self_reported boolean not null default false;

create or replace function public.resident_report_medication_taken(
    p_medication_id uuid,
    p_scheduled_for timestamptz
)
returns public.medication_administrations
language plpgsql
security definer
set search_path = public
as $$
declare
    v_med public.resident_medications;
    v_device public.resident_hub_devices;
    v_row public.medication_administrations;
begin
    select * into v_med from public.resident_medications where id = p_medication_id;
    if not found then
        raise exception 'medication_not_found' using errcode = 'P0002';
    end if;

    select * into v_device
    from public.resident_hub_devices dv
    where dv.hub_user_id = auth.uid()
    and dv.facility_id = v_med.facility_id
    and dv.resident_id = v_med.resident_id
    and dv.active;

    if not found then
        raise exception 'not_authorized' using errcode = '42501';
    end if;

    -- A row already existing means staff already recorded this dose (given,
    -- refused, held or missed) -- do not let a resident's tap overwrite that.
    insert into public.medication_administrations (
        medication_id, facility_id, resident_id, scheduled_for, status, administered_by, self_reported
    ) values (
        p_medication_id, v_med.facility_id, v_med.resident_id, p_scheduled_for, 'given', null, true
    )
    on conflict (medication_id, scheduled_for) do nothing
    returning * into v_row;

    if v_row.id is null then
        select * into v_row
        from public.medication_administrations
        where medication_id = p_medication_id and scheduled_for = p_scheduled_for;
    end if;

    return v_row;
end;
$$;

revoke all on function public.resident_report_medication_taken(uuid, timestamptz) from public;
grant execute on function public.resident_report_medication_taken(uuid, timestamptz) to authenticated;
