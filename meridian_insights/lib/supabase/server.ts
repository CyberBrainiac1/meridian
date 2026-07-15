import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

// Server-side Supabase client for Server Components, Server Actions, and
// Route Handlers — reads/writes the session via Next.js cookies(). Always
// uses the anon key + the signed-in user's session (RLS-enforced), never
// the service-role key.
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // Called from a Server Component during render — the proxy
            // handles session refresh in that case, so this is safe to
            // swallow (see proxy.ts).
          }
        },
      },
    }
  );
}
