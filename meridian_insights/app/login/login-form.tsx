"use client";

import { useActionState } from "react";
import { login, type LoginState } from "./actions";

const initialState: LoginState = {};

export function LoginForm() {
  const [state, formAction, pending] = useActionState(login, initialState);

  return (
    <form action={formAction} className="soft-card p-6 space-y-4">
      <div>
        <label htmlFor="email" className="block text-sm font-medium mb-1.5">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          required
          className="w-full rounded-[var(--radius-control)] border border-[var(--color-border)] bg-white px-3.5 py-2.5 text-base focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]"
        />
      </div>
      <div>
        <label htmlFor="password" className="block text-sm font-medium mb-1.5">
          Password
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          className="w-full rounded-[var(--radius-control)] border border-[var(--color-border)] bg-white px-3.5 py-2.5 text-base focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]"
        />
      </div>

      {state?.error && (
        <p role="alert" className="text-sm font-medium text-[var(--color-destructive)]">
          {state.error}
        </p>
      )}

      <button
        type="submit"
        disabled={pending}
        className="w-full rounded-[var(--radius-control)] bg-[var(--color-primary)] px-4 py-2.5 text-base font-medium text-[var(--color-on-primary)] transition-colors duration-200 ease-in-out hover:bg-[var(--color-primary)]/90 disabled:opacity-60"
      >
        {pending ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}
