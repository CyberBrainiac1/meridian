import { LoginForm } from "./login-form";

export default function LoginPage() {
  return (
    <main className="min-h-screen flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-2xl font-semibold text-[var(--color-foreground)]">
            Meridian Insights
          </h1>
          <p className="mt-1 text-sm text-[var(--color-foreground)]/70">
            Sign in to your facility dashboard.
          </p>
        </div>
        <LoginForm />
      </div>
    </main>
  );
}
