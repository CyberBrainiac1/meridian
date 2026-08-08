
-- Two related defects, both found by querying as an actual caregiver rather
-- than as service_role.
--
-- 1. MISSING GRANTS. 20260807000000 revoked all on assistance_requests and
--    visitor_verification_prompts from `authenticated` and granted only to
--    service_role, but then defined care-team SELECT policies on both. A
--    policy cannot grant access that the table-level privilege withholds, so
--    the care team could never read either table: a resident could press
--    "Request assistance" on the Hub and no caregiver query would ever
--    return it. RLS still does the row filtering; the grant only makes the
--    table reachable at all.
grant select on public.assistance_requests to authenticated;
grant select on public.visitor_verification_prompts to authenticated;
grant select on public.resident_hub_devices to authenticated;

-- 2. POLICY BODIES RUN WITH THE QUERYING USER'S PRIVILEGES. Several shared
--    tables carry a "resident hub can read own …" policy whose body reads
--    resident_hub_devices. Postgres evaluates every permissive policy for a
--    query, so a *caregiver* selecting from resident_medications also had to
--    read resident_hub_devices — a table no role held a grant on — and the
--    whole query failed 42501 before RLS filtering even mattered.
--
--    Wrapping the check in a SECURITY DEFINER function fixes it at the root:
--    the function reads resident_hub_devices as its owner, so no caller needs
--    that privilege. It is safe to expose — it answers only "is the current
--    JWT the active Hub device bound to this facility+resident?", returns a
--    boolean, and leaks no rows. The grant above is belt-and-braces for any
--    policy still reading the table directly.
create or replace function public.is_active_hub_device_for(
    p_facility_id text,
    p_resident_id text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.resident_hub_devices d
        where d.facility_id = p_facility_id
        and d.resident_id = p_resident_id
        and d.hub_user_id = auth.uid()
        and d.active
    );
$$;

revoke all on function public.is_active_hub_device_for(text, text) from public;
grant execute on function public.is_active_hub_device_for(text, text) to authenticated;

drop policy if exists "resident hub can read own medications" on public.resident_medications;
create policy "resident hub can read own medications"
on public.resident_medications for select to authenticated
using (public.is_active_hub_device_for(facility_id, resident_id));

drop policy if exists "resident hub can read own administrations" on public.medication_administrations;
create policy "resident hub can read own administrations"
on public.medication_administrations for select to authenticated
using (public.is_active_hub_device_for(facility_id, resident_id));

drop policy if exists "resident hub can read own assistance requests" on public.assistance_requests;
create policy "resident hub can read own assistance requests"
on public.assistance_requests for select to authenticated
using (public.is_active_hub_device_for(facility_id, resident_id));

drop policy if exists "resident hub can read own visitor verification prompts" on public.visitor_verification_prompts;
create policy "resident hub can read own visitor verification prompts"
on public.visitor_verification_prompts for select to authenticated
using (public.is_active_hub_device_for(facility_id, resident_id));

-- A Hub device is not a facility_member, so the care-team policy on
-- resident_hub_devices leaves it unable to read its own binding row. Its
-- feeds are definer views that never consult this policy, but the grant
-- above now makes the table reachable, and without this a device could see
-- every binding in the facility.
drop policy if exists "hub device can read own binding" on public.resident_hub_devices;
create policy "hub device can read own binding"
on public.resident_hub_devices for select to authenticated
using (hub_user_id = auth.uid() and active);
