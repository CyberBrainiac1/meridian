import { LoginForm } from "./login-form";
import { isSupabaseConfigured } from "@/lib/supabase/config";

export default function LoginPage() {
  return (
    <main className="min-h-screen flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-2xl font-semibold text-[var(--color-foreground)]">
            Meridian Insights
          </h1>
          <p className="mt-1 text-sm text-[var(--color-foreground-muted)]">
            Sign in to your facility dashboard.
          </p>
        </div>
        <LoginForm />
        {!isSupabaseConfigured && (
          <p className="mt-4 text-center text-xs text-[var(--color-warning)]">
            No Supabase project is configured yet (NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY
            are unset). See frontendguytodo.md.
          </p>
        )}
      </div>
    </main>
  );
}
