
-- resident_hub_medication_feed was built on top of
-- facility_medication_schedule, which is security_invoker -- so the inner
-- view's permission check resolved against the Hub device rather than the
-- view owner, and the device (deliberately) holds no grant on
-- resident_hub_devices. Every Hub read failed with 42501.
--
-- Fixed by computing the dose slots directly from base tables, the same
-- definer-view pattern as resident_hub_profile / resident_hub_assistance_feed.
-- The projection is unchanged and still deliberately omits drug name, dose,
-- route and instructions: a room display is not a medication record.
drop view if exists public.resident_hub_medication_feed;

create view public.resident_hub_medication_feed
as
select
    m.id as medication_id,
    ((d.day + t.slot) at time zone f.timezone) as scheduled_for,
    coalesce(a.status, 'outstanding') as status
from public.resident_medications m
join public.facilities f on f.id = m.facility_id
join public.resident_hub_devices dv
    on dv.facility_id = m.facility_id
    and dv.resident_id = m.resident_id
    and dv.hub_user_id = auth.uid()
    and dv.active
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

grant select on public.resident_hub_medication_feed to authenticated;
