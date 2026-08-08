-- Retry of the person_consents dedup + unique index from 20260807000400.
-- That migration's CREATE UNIQUE INDEX silently failed the first time
-- because duplicate active rows already existed when it ran (confirmed live:
-- inserting a 4th duplicate afterward returned 201, not 409). Deleting the
-- duplicates and creating the index in the same statement batch, verified by
-- a live insert probe immediately after, is what actually proves it stuck --
-- a "Success" message from the SQL editor is not sufficient evidence on its
-- own when a later statement in the same script can fail independently.
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
