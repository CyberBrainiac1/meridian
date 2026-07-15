-- Family app content gap: family_incident_feed / family_visitor_feed /
-- notifications all carry resident_id but no display name, and the only
-- tables with a name (people, resident_profiles) are RLS-scoped to
-- facility_members — family has no select policy on either. That leaves
-- no way for the Family app to render "Maggie had a good day" (PRD 7.3,
-- the app's emotional-core copy), only "Your family member had a good
-- day." This view closes that gap with the smallest possible surface:
-- name only, no room_id/risk_flags/care_notes, which stay care-team-only
-- on resident_profiles.
--
-- Same pattern as family_incident_feed/family_visitor_feed (see
-- 20260703000100_incident_rpc_and_views.sql): not security_invoker, gates
-- access itself via family_member_links + auth.uid() rather than
-- inheriting people's facility_members-scoped RLS.
create or replace view public.family_linked_residents
as
select
    fml.resident_id,
    p.display_name
from public.family_member_links fml
join public.people p on p.id = fml.resident_id
where fml.user_id = (select auth.uid());

grant select on public.family_linked_residents to authenticated;
