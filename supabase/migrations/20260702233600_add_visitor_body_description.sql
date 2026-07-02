alter table public.visitor_face_observations
    add column if not exists body_description text check (
        body_description is null or length(body_description) <= 700
    ),
    add column if not exists body_description_model text check (
        body_description_model is null or length(body_description_model) <= 120
    ),
    add column if not exists body_description_generated_at timestamptz,
    add column if not exists person_photo_ciphertext text check (
        person_photo_ciphertext is null or length(person_photo_ciphertext) >= 32
    ),
    add column if not exists person_photo_sha256 text check (
        person_photo_sha256 is null or person_photo_sha256 ~ '^[a-f0-9]{64}$'
    ),
    add column if not exists person_photo_key_id text,
    add column if not exists person_photo_nonce text,
    add column if not exists person_photo_algorithm text check (
        person_photo_algorithm is null
        or person_photo_algorithm in ('AES-256-GCM', 'XCHACHA20-POLY1305')
    ),
    add column if not exists person_photo_content_type text check (
        person_photo_content_type is null
        or person_photo_content_type in ('image/jpeg', 'image/png', 'image/webp')
    ),
    add column if not exists person_photo_size_bytes integer check (
        person_photo_size_bytes is null
        or (person_photo_size_bytes > 0 and person_photo_size_bytes <= 10485760)
    ),
    add column if not exists person_photo_expires_at timestamptz;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'visitor_face_observations_person_photo_encrypted_check'
    ) then
        alter table public.visitor_face_observations
            add constraint visitor_face_observations_person_photo_encrypted_check
            check (
                person_photo_ciphertext is null
                or (
                    person_photo_sha256 is not null
                    and person_photo_key_id is not null
                    and person_photo_nonce is not null
                    and person_photo_algorithm is not null
                    and person_photo_content_type is not null
                    and person_photo_size_bytes is not null
                )
            );
    end if;
end;
$$;

create index if not exists visitor_face_observations_body_description_idx
    on public.visitor_face_observations (facility_id, detected_at desc)
    where body_description is not null;

-- Include the generated body/clothing description in care-team visitor
-- notifications when available. Family-facing notifications stay generic.
create or replace function public.notify_visitor_arrival()
returns trigger
language plpgsql
set search_path = public
as $$
declare
    v_camera_label text;
    v_care_body text;
begin
    if new.match_status not in ('new_visitor', 'unknown') then
        return new;
    end if;

    select coalesce(c.display_name, c.location_label, c.external_id) into v_camera_label
    from public.cameras c
    where c.id = new.camera_id;

    v_care_body := 'New visitor detected at ' || coalesce(v_camera_label, 'an entry point');
    if new.body_description is not null and length(new.body_description) > 0 then
        v_care_body := v_care_body || ': ' || new.body_description;
    else
        v_care_body := v_care_body || '.';
    end if;

    insert into public.notifications (facility_id, resident_id, incident_id, channel, body, status)
    values (
        new.facility_id, null, null, 'push',
        v_care_body,
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
