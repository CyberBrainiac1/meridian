# Demo seed data

`demo_two_room_seed.sql` seeds one facility, two cameras, two residents,
and a handful of incidents in different lifecycle states, for a live
2-camera pitch demo.

## Before running it

Supabase's raw SQL cannot create `auth.users` rows — those must exist
first via Supabase Auth. Create three demo accounts (owner, caregiver,
family) however you prefer:

- Supabase Dashboard → Authentication → Users → Add user, or
- `supabase.auth.admin.createUser(...)` from a trusted script using the
  service-role key (never from a mobile/web app).

Then open `demo_two_room_seed.sql` and replace the three placeholder
UUIDs (`00000000-0000-0000-0000-00000000000{1,2,3}`) with the real
`auth.users.id` values for those three accounts before running the
script.

## Running it

Via the Supabase SQL editor (paste the file contents), or:

```bash
psql "$SUPABASE_DB_URL" -f supabase/seed/demo_two_room_seed.sql
```

The script is idempotent (`on conflict do update/nothing`) — safe to
re-run after editing.
