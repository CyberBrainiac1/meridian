# Provisioning the live demo Supabase project

End-to-end runbook to take the repo from "no live project" to "all three
apps querying real data." Steps marked **(you)** need your Supabase
account/browser session and can't be done for you. Steps marked **(me)**
are ready to hand back to Claude once you've done the step before them.

## 1. Log in (you)

```bash
npx supabase login
```

Opens a browser tab, ties the CLI session to your Supabase account. This
machine's `npx supabase` will stay authenticated afterward.

## 2. Create the project (you, or tell me to run it)

Either click "New project" at supabase.com/dashboard, or from this repo:

```bash
npx supabase orgs list          # find your org id
npx supabase projects create meridian-demo \
  --org-id <your-org-id> \
  --db-password '<pick-a-strong-password>' \
  --region us-west-1              # or whichever region is closest
```

This creates a real, billable cloud resource under your account — I
won't run it myself without you explicitly telling me to, and confirming
the org/region/plan first.

Note the **project ref** (e.g. `abcdefghijklmnop`) from the output or the
dashboard URL.

## 3. Link + push migrations (me, once I have the project ref)

```bash
cd /Users/dhairyagurnani/meridian
npx supabase link --project-ref <project-ref>
npx supabase db push
```

Applies all 5 files in `supabase/migrations/` in order, including the
`family_linked_residents` view added for the frontend build.

## 4. Deploy the Edge Functions (me)

```bash
npx supabase functions deploy ingest-event
npx supabase functions deploy ingest-visitor-face
npx supabase functions deploy notify-family
```

Then set their secrets (dashboard → Edge Functions → Secrets, or
`supabase secrets set`) per `supabase/functions/.env.example` —
`MERIDIAN_SUPABASE_SERVICE_ROLE_KEY` and `MERIDIAN_INTERNAL_FUNCTION_SECRET`
at minimum for `notify-family` to run.

## 5. Create the three demo accounts (you provide the service-role key, me or you run it)

Get the service-role key from Dashboard → Project Settings → API — **never
paste it into chat**; export it directly in your terminal.

```bash
SUPABASE_URL=https://<project-ref>.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=<paste-here-in-your-terminal-only> \
node supabase/scripts/create_demo_users.mjs
```

Prints the three real `auth.users` UUIDs and a ready-to-run `sed`
command.

## 6. Seed demo data (me, using the sed command from step 5)

```bash
# the sed command printed by create_demo_users.mjs, then:
npx supabase db execute --file supabase/seed/demo_two_room_seed.sql
# or paste the file into the Dashboard SQL editor
```

## 7. Smoke test (me + you together)

Run through `supabase/scripts/smoke_test_backend.md` — RLS isolation,
`respond_to_incident` lifecycle, family visibility scoping. This is the
real correctness check before a pitch.

## 8. Wire the three frontend apps (me)

Get the anon key from Dashboard → Project Settings → API (safe to share —
it's the public client key, RLS does the real access control).

```bash
# meridian_insights/.env.local
NEXT_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon-key>

# meridian_care/Config/Secrets.xcconfig
MERIDIAN_SUPABASE_URL = https://<project-ref>.supabase.co
MERIDIAN_SUPABASE_ANON_KEY = <anon-key>

# meridian_family/Config/Secrets.xcconfig
MERIDIAN_SUPABASE_URL = https://<project-ref>.supabase.co
MERIDIAN_SUPABASE_ANON_KEY = <anon-key>
```

Then `npm run dev` in `meridian_insights`, and `xcodegen generate` +
build in `meridian_care`/`meridian_family` to pick up the new xcconfig
values.

## What I need from you to continue

1. Run step 1 (`npx supabase login`) — tell me when it's done.
2. Either create the project yourself (step 2) and give me the project
   ref, or tell me to run `projects create` and confirm org/region.
3. When you're ready for step 5, export the service-role key in your own
   terminal and run the one command shown — don't paste the key itself
   to me.
