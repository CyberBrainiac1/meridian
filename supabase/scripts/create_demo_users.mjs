#!/usr/bin/env node
// Creates the three demo auth.users accounts (owner, caregiver, family)
// via Supabase's Auth Admin REST API, then prints a ready-to-paste sed
// command to patch their real UUIDs into demo_two_room_seed.sql.
//
// Run once, after `supabase link` + `supabase db push`:
//
//   SUPABASE_URL=https://<ref>.supabase.co \
//   SUPABASE_SERVICE_ROLE_KEY=<service-role-key-from-dashboard> \
//   node supabase/scripts/create_demo_users.mjs
//
// Never commit the service-role key or put it in any app's env file —
// this script only needs it for this one local, one-time admin call.

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (see script header) before running.");
  process.exit(1);
}

const DEMO_USERS = [
  { role: "owner", email: "owner@meridian-demo.test", password: "MeridianDemo1!" },
  { role: "caregiver", email: "caregiver@meridian-demo.test", password: "MeridianDemo1!" },
  { role: "family", email: "family@meridian-demo.test", password: "MeridianDemo1!" },
];

async function createUser({ role, email, password }) {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({ email, password, email_confirm: true }),
  });

  const body = await res.json();
  if (!res.ok) {
    // 422/"already registered" is fine on a re-run — look the user up
    // instead of failing.
    if (res.status === 422 || body?.msg?.includes("already been registered")) {
      const list = await fetch(`${SUPABASE_URL}/auth/v1/admin/users?email=${encodeURIComponent(email)}`, {
        headers: { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
      }).then((r) => r.json());
      const existing = list.users?.[0];
      if (existing) return { role, email, id: existing.id, existed: true };
    }
    throw new Error(`Failed to create ${email}: ${res.status} ${JSON.stringify(body)}`);
  }
  return { role, email, id: body.id, existed: false };
}

const results = [];
for (const user of DEMO_USERS) {
  const result = await createUser(user);
  results.push(result);
  console.log(`${result.existed ? "found existing" : "created"} ${result.role}: ${result.email} -> ${result.id}`);
}

const [owner, caregiver, family] = results;
console.log("\nPassword for all three demo accounts: MeridianDemo1!\n");
console.log("Run this to patch the real UUIDs into the seed file, then run the seed script:\n");
console.log(
  `sed -i '' \\\n` +
    `  -e 's/00000000-0000-0000-0000-000000000001/${owner.id}/' \\\n` +
    `  -e 's/00000000-0000-0000-0000-000000000002/${caregiver.id}/' \\\n` +
    `  -e 's/00000000-0000-0000-0000-000000000003/${family.id}/' \\\n` +
    `  supabase/seed/demo_two_room_seed.sql`
);
