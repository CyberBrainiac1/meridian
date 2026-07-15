import { createBrowserClient } from "@supabase/ssr";

// Client-side Supabase client — anon key only, session comes from cookies
// set by the server client. Used from Client Components (realtime
// subscriptions, acknowledge/resolve button handlers).
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
