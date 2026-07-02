-- Idempotent demo data for a 2-camera, 2-resident pitch demo.
-- Run AFTER migrations. Requires three auth.users to already exist
-- (create them via Supabase Auth first — see supabase/seed/README.md) —
-- this script does not and cannot create auth.users rows itself.
--
-- Usage: replace the three UUID placeholders below with the real
-- auth.users ids for your demo owner/caregiver/family accounts, then run
-- this file via the Supabase SQL editor or `psql`.

insert into public.facilities (id, slug, display_name, timezone)
values ('fac-demo-001', 'demo-facility', 'Meridian Demo Facility', 'America/Los_Angeles')
on conflict (id) do update set display_name = excluded.display_name;

insert into public.cameras (id, facility_id, external_id, display_name, location_label, status)
values
    ('cam-entry-001', 'fac-demo-001', 'entry-001', 'Main Entrance', 'Front Door', 'online'),
    ('cam-room-101', 'fac-demo-001', 'room-101', 'Room 101', 'Room 101', 'online')
on conflict (id) do update set status = excluded.status;

insert into public.people (id, facility_id, display_name, person_type, external_ref)
values
    ('person-maggie', 'fac-demo-001', 'Maggie R.', 'resident', 'demo-resident-1'),
    ('person-walter', 'fac-demo-001', 'Walter S.', 'resident', 'demo-resident-2')
on conflict (id) do update set display_name = excluded.display_name;

insert into public.resident_profiles (facility_id, person_id, room_id, display_name, risk_flags, care_notes)
values
    ('fac-demo-001', 'person-maggie', 'room-101', 'Maggie R.', '["fall_history"]'::jsonb, 'Prefers morning walks; mild dementia.'),
    ('fac-demo-001', 'person-walter', 'room-102', 'Walter S.', '[]'::jsonb, 'Independent, low fall risk.')
on conflict (person_id) do update set risk_flags = excluded.risk_flags;

insert into public.person_consents (facility_id, person_id, consent_scope, consent_status, consent_source)
values
    ('fac-demo-001', 'person-maggie', 'monitoring', 'active', 'admission_agreement'),
    ('fac-demo-001', 'person-maggie', 'family_visibility', 'active', 'admission_agreement'),
    ('fac-demo-001', 'person-walter', 'monitoring', 'active', 'admission_agreement'),
    ('fac-demo-001', 'person-walter', 'family_visibility', 'active', 'admission_agreement')
on conflict do nothing;

-- Replace these three UUIDs with real auth.users ids before running.
insert into public.facility_members (facility_id, user_id, role)
values
    ('fac-demo-001', '00000000-0000-0000-0000-000000000001', 'owner'),
    ('fac-demo-001', '00000000-0000-0000-0000-000000000002', 'caregiver'),
    ('fac-demo-001', '00000000-0000-0000-0000-000000000003', 'family')
on conflict (facility_id, user_id) do update set role = excluded.role;

insert into public.family_member_links (facility_id, user_id, resident_id)
values ('fac-demo-001', '00000000-0000-0000-0000-000000000003', 'person-maggie')
on conflict (user_id, resident_id) do nothing;

-- Sample incidents across lifecycle states so the demo has real data to
-- click through immediately.
insert into public.incident_events (
    source_event_id, facility_id, room_id, resident_id, camera_id,
    event_type, severity, status, confidence, detected_at, generated_at,
    reason_codes, summary
)
values
    (
        'demo-evt-open-1', 'fac-demo-001', 'room-101', 'person-maggie', 'cam-room-101',
        'fall_suspected', 'warning', 'open', 0.72, now() - interval '3 minutes', now() - interval '3 minutes',
        '["pose_low_confidence"]'::jsonb, 'Maggie may need help in Room 101'
    ),
    (
        'demo-evt-resolved-1', 'fac-demo-001', 'room-101', 'person-maggie', 'cam-room-101',
        'fall_confirmed', 'critical', 'open', 0.94, now() - interval '2 hours', now() - interval '2 hours',
        '["pose_fall_pattern", "gemini_confirmed"]'::jsonb, 'Maggie needs help in Room 101'
    ),
    (
        'demo-evt-visitor-1', 'fac-demo-001', null, null, 'cam-entry-001',
        'visitor_arrival', 'info', 'resolved', null, now() - interval '1 hour', now() - interval '1 hour',
        '[]'::jsonb, 'New visitor detected at Main Entrance'
    )
on conflict (source_event_id) do nothing;

-- Walk demo-evt-resolved-1 through the real RPC-shaped lifecycle so
-- acknowledged_by/resolved_by are populated the same way the app would
-- populate them (direct update here only because this is seed data, not
-- an app write path).
update public.incident_events
set status = 'resolved',
    acknowledged_by = '00000000-0000-0000-0000-000000000002',
    acknowledged_at = detected_at + interval '90 seconds',
    resolved_by = '00000000-0000-0000-0000-000000000002',
    resolved_at = detected_at + interval '5 minutes',
    resolution_note = 'Staff reached her in 90 seconds. Assisted back to bed, no injury.'
where source_event_id = 'demo-evt-resolved-1';
