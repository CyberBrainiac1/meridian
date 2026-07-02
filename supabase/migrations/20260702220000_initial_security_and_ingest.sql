create extension if not exists pgcrypto;

create table if not exists public.facilities (
    id text primary key check (id ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$'),
    slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$'),
    display_name text not null,
    timezone text not null default 'America/Los_Angeles',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.facility_members (
    facility_id text not null references public.facilities(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    role text not null check (role in ('owner', 'admin', 'caregiver', 'viewer')),
    created_at timestamptz not null default now(),
    primary key (facility_id, user_id)
);

create table if not exists public.cameras (
    id text primary key check (id ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$'),
    facility_id text not null references public.facilities(id) on delete cascade,
    external_id text not null,
    display_name text,
    location_label text,
    status text not null default 'provisioning'
        check (status in ('provisioning', 'online', 'offline', 'disabled')),
    last_seen_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (facility_id, external_id)
);

create table if not exists public.people (
    id text primary key check (id ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$'),
    facility_id text not null references public.facilities(id) on delete cascade,
    display_name text not null,
    person_type text not null check (person_type in ('resident', 'staff', 'visitor', 'caregiver')),
    external_ref text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (facility_id, external_ref)
);

create table if not exists public.person_consents (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    person_id text not null references public.people(id) on delete cascade,
    consent_scope text not null check (consent_scope in ('monitoring', 'face_recognition', 'family_visibility')),
    consent_status text not null check (consent_status in ('active', 'revoked', 'expired')),
    consent_source text not null,
    granted_by_user_id uuid references auth.users(id) on delete set null,
    granted_at timestamptz not null default now(),
    revoked_at timestamptz,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.visitor_face_observations (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    camera_id text references public.cameras(id) on delete set null,
    source_event_id text unique,
    detected_at timestamptz not null,
    match_status text not null default 'new_visitor'
        check (match_status in ('new_visitor', 'repeat_visitor', 'known_visitor', 'unknown')),
    matched_person_id text references public.people(id) on delete set null,
    quality_score numeric(5, 4) check (quality_score is null or (quality_score >= 0 and quality_score <= 1)),
    match_threshold numeric(5, 4) check (match_threshold is null or (match_threshold >= 0 and match_threshold <= 1)),
    match_confidence numeric(5, 4) check (match_confidence is null or (match_confidence >= 0 and match_confidence <= 1)),
    face_embedding_ciphertext text not null check (length(face_embedding_ciphertext) >= 32),
    face_embedding_digest text not null check (face_embedding_digest ~ '^[a-f0-9]{64}$'),
    face_embedding_key_id text not null,
    face_embedding_nonce text not null,
    face_embedding_algorithm text not null check (
        face_embedding_algorithm in ('AES-256-GCM', 'XCHACHA20-POLY1305')
    ),
    face_embedding_model text not null default 'insightface:buffalo_s:arcface',
    face_embedding_dimensions integer not null default 512
        check (face_embedding_dimensions > 0 and face_embedding_dimensions <= 4096),
    face_embedding_expires_at timestamptz,
    face_location jsonb not null default '{}'::jsonb,
    encrypted_face_image_path text check (
        encrypted_face_image_path is null
        or (
            encrypted_face_image_path !~ '(^/|\\.\\.)'
            and encrypted_face_image_path like '%.bin'
        )
    ),
    face_image_sha256 text check (face_image_sha256 is null or face_image_sha256 ~ '^[a-f0-9]{64}$'),
    face_image_key_id text,
    face_image_nonce text,
    face_image_algorithm text check (
        face_image_algorithm is null
        or face_image_algorithm in ('AES-256-GCM', 'XCHACHA20-POLY1305')
    ),
    face_image_expires_at timestamptz,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (
        encrypted_face_image_path is null
        or (
            face_image_sha256 is not null
            and face_image_key_id is not null
            and face_image_nonce is not null
            and face_image_algorithm is not null
        )
    )
);

create table if not exists public.incident_events (
    id uuid primary key default gen_random_uuid(),
    source_event_id text not null unique,
    schema_version text not null default '1.0',
    facility_id text not null references public.facilities(id) on delete cascade,
    building_id text,
    floor_id text,
    room_id text,
    resident_id text,
    camera_id text references public.cameras(id) on delete set null,
    event_type text not null check (
        event_type in (
            'fall_suspected',
            'fall_confirmed',
            'long_lie',
            'unusual_inactivity',
            'wandering',
            'exit_risk',
            'night_activity',
            'device_offline',
            'stream_degraded',
            'medication_visit_missing',
            'visitor_arrival',
            'visitor_departure'
        )
    ),
    severity text not null default 'info' check (severity in ('info', 'warning', 'critical')),
    status text not null default 'open' check (
        status in ('open', 'acknowledged', 'responding', 'resolved', 'dismissed_false_alarm', 'escalated')
    ),
    confidence numeric(5, 4) check (confidence is null or (confidence >= 0 and confidence <= 1)),
    detected_at timestamptz not null,
    generated_at timestamptz not null,
    received_at timestamptz not null default now(),
    reason_codes jsonb not null default '[]'::jsonb,
    evidence jsonb not null default '{}'::jsonb,
    device_health jsonb not null default '{}'::jsonb,
    summary text,
    encrypted_evidence_path text check (
        encrypted_evidence_path is null
        or (
            encrypted_evidence_path !~ '(^/|\\.\\.)'
            and encrypted_evidence_path like '%.bin'
        )
    ),
    evidence_sha256 text check (evidence_sha256 is null or evidence_sha256 ~ '^[a-f0-9]{64}$'),
    evidence_key_id text,
    evidence_nonce text,
    evidence_algorithm text check (
        evidence_algorithm is null
        or evidence_algorithm in ('AES-256-GCM', 'XCHACHA20-POLY1305')
    ),
    evidence_expires_at timestamptz,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (
        encrypted_evidence_path is null
        or (
            evidence_sha256 is not null
            and evidence_key_id is not null
            and evidence_nonce is not null
            and evidence_algorithm is not null
        )
    )
);

create table if not exists public.device_heartbeats (
    id uuid primary key default gen_random_uuid(),
    facility_id text not null references public.facilities(id) on delete cascade,
    camera_id text references public.cameras(id) on delete set null,
    hub_device_id text,
    captured_at timestamptz not null default now(),
    status text not null default 'online' check (status in ('online', 'degraded', 'offline')),
    metrics jsonb not null default '{}'::jsonb
);

create index if not exists facility_members_user_idx
    on public.facility_members (user_id, facility_id);

create index if not exists cameras_facility_idx
    on public.cameras (facility_id);

create index if not exists people_facility_idx
    on public.people (facility_id);

create index if not exists person_consents_facility_person_idx
    on public.person_consents (facility_id, person_id);

create unique index if not exists person_consents_active_face_idx
    on public.person_consents (person_id)
    where consent_scope = 'face_recognition' and consent_status = 'active';

create index if not exists visitor_face_observations_facility_detected_idx
    on public.visitor_face_observations (facility_id, detected_at desc);

create index if not exists visitor_face_observations_digest_idx
    on public.visitor_face_observations (facility_id, face_embedding_digest);

create index if not exists visitor_face_observations_camera_idx
    on public.visitor_face_observations (camera_id, detected_at desc);

create index if not exists visitor_face_observations_image_path_idx
    on public.visitor_face_observations (encrypted_face_image_path)
    where encrypted_face_image_path is not null;

create index if not exists incident_events_facility_detected_idx
    on public.incident_events (facility_id, detected_at desc);

create index if not exists incident_events_camera_detected_idx
    on public.incident_events (camera_id, detected_at desc);

create index if not exists incident_events_evidence_path_idx
    on public.incident_events (encrypted_evidence_path)
    where encrypted_evidence_path is not null;

create index if not exists device_heartbeats_facility_captured_idx
    on public.device_heartbeats (facility_id, captured_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

revoke all on function public.set_updated_at() from public;

drop trigger if exists set_facilities_updated_at on public.facilities;
create trigger set_facilities_updated_at
before update on public.facilities
for each row execute function public.set_updated_at();

drop trigger if exists set_cameras_updated_at on public.cameras;
create trigger set_cameras_updated_at
before update on public.cameras
for each row execute function public.set_updated_at();

drop trigger if exists set_people_updated_at on public.people;
create trigger set_people_updated_at
before update on public.people
for each row execute function public.set_updated_at();

drop trigger if exists set_person_consents_updated_at on public.person_consents;
create trigger set_person_consents_updated_at
before update on public.person_consents
for each row execute function public.set_updated_at();

drop trigger if exists set_visitor_face_observations_updated_at on public.visitor_face_observations;
create trigger set_visitor_face_observations_updated_at
before update on public.visitor_face_observations
for each row execute function public.set_updated_at();

drop trigger if exists set_incident_events_updated_at on public.incident_events;
create trigger set_incident_events_updated_at
before update on public.incident_events
for each row execute function public.set_updated_at();

alter table public.facilities enable row level security;
alter table public.facility_members enable row level security;
alter table public.cameras enable row level security;
alter table public.people enable row level security;
alter table public.person_consents enable row level security;
alter table public.visitor_face_observations enable row level security;
alter table public.incident_events enable row level security;
alter table public.device_heartbeats enable row level security;

revoke all on schema public from public;
grant usage on schema public to authenticated, service_role;

revoke all on all tables in schema public from anon, authenticated;
grant select on public.facilities to authenticated;
grant select on public.facility_members to authenticated;
grant select on public.cameras to authenticated;
grant select, insert, update on public.people to authenticated;
grant select, insert, update on public.person_consents to authenticated;
grant select on public.visitor_face_observations to authenticated;
grant select on public.incident_events to authenticated;
grant update (status) on public.incident_events to authenticated;
grant select on public.device_heartbeats to authenticated;
grant all on public.facilities to service_role;
grant all on public.facility_members to service_role;
grant all on public.cameras to service_role;
grant all on public.people to service_role;
grant all on public.person_consents to service_role;
grant all on public.visitor_face_observations to service_role;
grant all on public.incident_events to service_role;
grant all on public.device_heartbeats to service_role;

alter default privileges in schema public revoke all on tables from public;
alter default privileges in schema public grant all on tables to service_role;

drop policy if exists "members can read own facility records" on public.facilities;
create policy "members can read own facility records"
on public.facilities
for select
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = facilities.id
        and fm.user_id = (select auth.uid())
    )
);

drop policy if exists "members can read own membership" on public.facility_members;
create policy "members can read own membership"
on public.facility_members
for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "members can read facility cameras" on public.cameras;
create policy "members can read facility cameras"
on public.cameras
for select
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = cameras.facility_id
        and fm.user_id = (select auth.uid())
    )
);

drop policy if exists "members can read facility people" on public.people;
create policy "members can read facility people"
on public.people
for select
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = people.facility_id
        and fm.user_id = (select auth.uid())
    )
);

drop policy if exists "facility admins can manage people" on public.people;
create policy "facility admins can manage people"
on public.people
for all
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = people.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin')
    )
)
with check (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = people.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin')
    )
);

drop policy if exists "members can read facility consents" on public.person_consents;
create policy "members can read facility consents"
on public.person_consents
for select
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = person_consents.facility_id
        and fm.user_id = (select auth.uid())
    )
);

drop policy if exists "facility admins can manage consents" on public.person_consents;
create policy "facility admins can manage consents"
on public.person_consents
for all
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = person_consents.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin')
    )
)
with check (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = person_consents.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin')
    )
);

drop policy if exists "care team can read visitor face observations" on public.visitor_face_observations;
create policy "care team can read visitor face observations"
on public.visitor_face_observations
for select
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = visitor_face_observations.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin', 'caregiver')
    )
);

drop policy if exists "members can read facility incidents" on public.incident_events;
create policy "members can read facility incidents"
on public.incident_events
for select
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = incident_events.facility_id
        and fm.user_id = (select auth.uid())
    )
);

drop policy if exists "care team can update incident status" on public.incident_events;
create policy "care team can update incident status"
on public.incident_events
for update
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = incident_events.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin', 'caregiver')
    )
)
with check (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = incident_events.facility_id
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin', 'caregiver')
    )
);

drop policy if exists "members can read device heartbeats" on public.device_heartbeats;
create policy "members can read device heartbeats"
on public.device_heartbeats
for select
to authenticated
using (
    exists (
        select 1
        from public.facility_members fm
        where fm.facility_id = device_heartbeats.facility_id
        and fm.user_id = (select auth.uid())
    )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'incident-evidence',
    'incident-evidence',
    false,
    104857600,
    array['application/octet-stream']::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'visitor-face-evidence',
    'visitor-face-evidence',
    false,
    104857600,
    array['application/octet-stream']::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "facility members can upload encrypted evidence" on storage.objects;
create policy "facility members can upload encrypted evidence"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'incident-evidence'
    and name like '%.bin'
    and name !~ '(^/|\\.\\.)'
    and coalesce((storage.foldername(name))[1], '') in (
        select fm.facility_id
        from public.facility_members fm
        where fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin', 'caregiver')
    )
);

drop policy if exists "facility writers can upload encrypted visitor face evidence" on storage.objects;
create policy "facility writers can upload encrypted visitor face evidence"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'visitor-face-evidence'
    and name like '%.bin'
    and name !~ '(^/|\\.\\.)'
    and coalesce((storage.foldername(name))[1], '') in (
        select fm.facility_id
        from public.facility_members fm
        where fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin', 'caregiver')
    )
);

drop policy if exists "facility members can read encrypted incident evidence" on storage.objects;
create policy "facility members can read encrypted incident evidence"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'incident-evidence'
    and exists (
        select 1
        from public.incident_events ie
        join public.facility_members fm on fm.facility_id = ie.facility_id
        where ie.encrypted_evidence_path = storage.objects.name
        and fm.user_id = (select auth.uid())
        and (ie.evidence_expires_at is null or ie.evidence_expires_at > now())
    )
);

drop policy if exists "care team can read encrypted visitor face evidence" on storage.objects;
create policy "care team can read encrypted visitor face evidence"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'visitor-face-evidence'
    and exists (
        select 1
        from public.visitor_face_observations vfo
        join public.facility_members fm on fm.facility_id = vfo.facility_id
        where vfo.encrypted_face_image_path = storage.objects.name
        and fm.user_id = (select auth.uid())
        and fm.role in ('owner', 'admin', 'caregiver')
        and (vfo.face_image_expires_at is null or vfo.face_image_expires_at > now())
    )
);

drop policy if exists "service role manages encrypted evidence" on storage.objects;
create policy "service role manages encrypted evidence"
on storage.objects
for all
to service_role
using (bucket_id in ('incident-evidence', 'visitor-face-evidence'))
with check (bucket_id in ('incident-evidence', 'visitor-face-evidence'));
