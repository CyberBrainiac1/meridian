"use client";

import { useActionState } from "react";
import { login, type LoginState } from "./actions";

const initialState: LoginState = {};

export default function LoginPage() {
  const [state, action, pending] = useActionState<LoginState, FormData>(login, initialState);
  return (
    <main className="hub-shell"><section className="hub-card login">
      <p className="eyebrow">MeridianHub setup</p><h1 className="title">Connect this room</h1>
      <p className="subhead">A care administrator provisions one account for this room’s Hub. This is not a shared staff or family login.</p>
      <form action={action}>
        <label htmlFor="email">Hub email</label><input id="email" name="email" type="email" autoComplete="username" required />
        <label htmlFor="password">Hub password</label><input id="password" name="password" type="password" autoComplete="current-password" required />
        {state.error && <p className="calm-alert" role="alert">{state.error}</p>}
        <button type="submit" disabled={pending}>{pending ? "Connecting…" : "Connect MeridianHub"}</button>
      </form>
    </section></main>
  );
}
