"use client";

import { useCallback, useEffect, useState, useTransition } from "react";
import { AlertTriangle, BellRing, HeartHandshake, PhoneCall, ShieldCheck, UserRoundCheck } from "lucide-react";
import { answerVisitorPrompt, createAssistanceRequest } from "@/app/actions";
import { createClient } from "@/lib/supabase/client";
import type { AssistanceKind, HubAssistanceRequest, HubState, HubVisitorPrompt } from "@/lib/types";

const POLL_MS = 10_000;

function activeRequest(requests: HubAssistanceRequest[]) {
  return requests.find((request) => ["open", "acknowledged", "en_route"].includes(request.status));
}

function etaCopy(request: HubAssistanceRequest) {
  const minutes = Math.max(1, Math.round(request.eta_seconds / 60));
  if (request.eta_confidence === "data_derived") {
    return { title: `Estimated response time: about ${minutes} minute${minutes === 1 ? "" : "s"}`, note: "Based on this facility’s recent staff acknowledgement times." };
  }
  if (request.eta_confidence === "limited_history") {
    return { title: `Estimated response time: about ${minutes} minute${minutes === 1 ? "" : "s"}`, note: "Based on limited recent response history; this is an estimate, not a promise." };
  }
  return { title: "Response time is still being estimated", note: "This facility has no recent acknowledgement history yet. The 5-minute display is a clearly marked conservative default, not a measured ETA." };
}

function statusCopy(request: HubAssistanceRequest) {
  if (request.status === "en_route") return "Help is coming. A caregiver is on the way.";
  if (request.status === "acknowledged") return "A caregiver has seen your request and is responding.";
  if (request.status === "resolved") return "This help request is complete.";
  if (request.status === "cancelled") return "This help request was cancelled by the care team.";
  if (request.source === "auto_fall_dispatch") return "A fall was detected. Help was requested automatically.";
  return "Your request was sent to the care team.";
}

async function loadLiveState(): Promise<Pick<HubState, "assistanceRequests" | "visitorPrompts">> {
  const supabase = createClient();
  // This turns expired prompts into no_response before reading. It is safe to
  // call repeatedly and means an old prompt never stays actionable on screen.
  const expiry = await supabase.rpc("expire_my_visitor_verification_prompts");
  if (expiry.error) throw expiry.error;
  const [requests, prompts] = await Promise.all([
    supabase.from("resident_hub_assistance_feed").select("*").order("requested_at", { ascending: false }),
    supabase.from("resident_hub_visitor_prompt_feed").select("*").order("prompted_at", { ascending: false }),
  ]);
  if (requests.error) throw requests.error;
  if (prompts.error) throw prompts.error;
  return { assistanceRequests: requests.data as HubAssistanceRequest[], visitorPrompts: prompts.data as HubVisitorPrompt[] };
}

export function HubSurface({ initialState }: { initialState: HubState }) {
  const [state, setState] = useState(initialState);
  const [online, setOnline] = useState(() => typeof navigator === "undefined" ? true : navigator.onLine);
  const [message, setMessage] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const refresh = useCallback(async () => {
    try {
      const next = await loadLiveState();
      setState((current) => ({ ...current, ...next }));
      setOnline(true);
    } catch {
      setOnline(false);
    }
  }, []);

  useEffect(() => {
    const onOnline = () => { setOnline(true); void refresh(); };
    const onOffline = () => setOnline(false);
    window.addEventListener("online", onOnline);
    window.addEventListener("offline", onOffline);
    const timer = window.setInterval(() => { if (navigator.onLine) void refresh(); }, POLL_MS);
    return () => {
      window.removeEventListener("online", onOnline);
      window.removeEventListener("offline", onOffline);
      window.clearInterval(timer);
    };
  }, [refresh]);

  const submitRequest = (kind: AssistanceKind) => {
    if (!navigator.onLine) {
      setOnline(false);
      setMessage("This Hub is offline, so your request was not sent. Please use the room call button or call out for staff now.");
      return;
    }
    startTransition(async () => {
      const result = await createAssistanceRequest(kind);
      setMessage(result.error ?? null);
      if (!result.error) await refresh();
    });
  };

  const respondToVisitor = (prompt: HubVisitorPrompt, response: "approved" | "denied") => {
    if (!navigator.onLine) {
      setOnline(false);
      setMessage("This Hub is offline, so your answer was not sent. Please use the room call button or call care staff.");
      return;
    }
    startTransition(async () => {
      const result = await answerVisitorPrompt(prompt.id, response);
      setMessage(result.error ?? (response === "denied" ? "The care team has been notified to check in." : "Thank you. Your answer was saved."));
      if (!result.error) await refresh();
    });
  };

  const request = activeRequest(state.assistanceRequests);
  const prompt = state.visitorPrompts.find((item) => item.status === "pending");

  return (
    <main className="hub-shell">
      <header>
        <p className="eyebrow">MeridianHub · Room {state.profile.room_id}</p>
        <h1 className="title">Hello, {state.profile.display_name}</h1>
        <p className="subhead">Choose what you need. Your care team is here to help.</p>
      </header>

      {!online && <div className="connection" role="alert"><AlertTriangle aria-hidden="true" /> Connection problem: this Hub cannot confirm new requests right now. Please use the room call button or call out for staff.</div>}
      {message && <div className="calm-alert" role="alert">{message}</div>}

      {request ? <HelpStatus request={request} /> : (
        <section className="action-grid" aria-label="Ways to get help">
          <button className="action-button" type="button" disabled={pending} onClick={() => submitRequest("assistance")}>
            <HeartHandshake aria-hidden="true" /> Request assistance
            <span className="action-note">Ask a caregiver to come to your room.</span>
          </button>
          <button className="action-button secondary" type="button" disabled={pending} onClick={() => submitRequest("family_contact")}>
            <PhoneCall aria-hidden="true" /> Call family
            <span className="action-note">Ask your consented family contact to call you.</span>
          </button>
          <button className="action-button emergency" type="button" disabled={pending} onClick={() => submitRequest("emergency")}>
            <BellRing aria-hidden="true" /> Emergency help
            <span className="action-note">Send an urgent alert to the care team now.</span>
          </button>
        </section>
      )}

      {prompt && <VisitorVerification prompt={prompt} disabled={pending} onAnswer={respondToVisitor} />}
    </main>
  );
}

function HelpStatus({ request }: { request: HubAssistanceRequest }) {
  const eta = etaCopy(request);
  return (
    <section className={`hub-card status-card ${request.status.replace("_", "-")}`} aria-live="polite">
      <p className="eyebrow"><ShieldCheck aria-hidden="true" /> Live help status</p>
      <h2 className="status-heading">{statusCopy(request)}</h2>
      <p className="status-copy">Status: {request.status.replace("_", " ")}</p>
      {!["resolved", "cancelled"].includes(request.status) && <div className="eta">{eta.title}<small>{eta.note}</small></div>}
    </section>
  );
}

function VisitorVerification({ prompt, disabled, onAnswer }: { prompt: HubVisitorPrompt; disabled: boolean; onAnswer: (prompt: HubVisitorPrompt, response: "approved" | "denied") => void }) {
  const detected = new Date(prompt.detected_at).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  return (
    <section className="hub-card visitor-card" aria-live="assertive">
      <p className="eyebrow"><UserRoundCheck aria-hidden="true" /> Visitor check</p>
      <h2>Is this person expected?</h2>
      <p className="visitor-details">{prompt.body_description ?? "An unfamiliar visitor was detected at your assigned entry camera."} Detected at {detected}.</p>
      <div className="answer-actions">
        <button className="answer-button" type="button" disabled={disabled} onClick={() => onAnswer(prompt, "approved")}>Yes, expected</button>
        <button className="answer-button deny" type="button" disabled={disabled} onClick={() => onAnswer(prompt, "denied")}>No, get help</button>
      </div>
    </section>
  );
}
