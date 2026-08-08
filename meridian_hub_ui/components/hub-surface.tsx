"use client";

import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import {
  AlertTriangle,
  BellRing,
  CheckCircle2,
  Clock,
  HeartHandshake,
  Loader2,
  PhoneCall,
  ShieldCheck,
  UserRoundCheck,
} from "lucide-react";
import { answerVisitorPrompt, createAssistanceRequest } from "@/app/actions";
import { createClient } from "@/lib/supabase/client";
import type { AssistanceKind, HubAssistanceRequest, HubState, HubVisitorPrompt } from "@/lib/types";

const POLL_MS = 10_000;
// A resident must never be left watching a control that never resolves. If the
// round trip has not answered by this point we stop waiting and say so.
const ACTION_TIMEOUT_MS = 15_000;
// How long a finished request stays on screen so the resident actually reads
// the outcome instead of the panel silently reverting under them.
const TERMINAL_VISIBLE_MS = 90_000;

type NoticeTone = "working" | "success" | "error";
interface Notice {
  tone: NoticeTone;
  text: string;
}

const ACTIVE_STATUSES = ["open", "acknowledged", "en_route"];

function activeRequest(requests: HubAssistanceRequest[]) {
  return requests.find((request) => ACTIVE_STATUSES.includes(request.status));
}

/** The most recent request that just finished, so "resolved" and "cancelled"
 *  are announced rather than causing the screen to change with no explanation. */
function recentlyFinishedRequest(requests: HubAssistanceRequest[], now: number) {
  // now === 0 means the clock has not been adopted yet (first paint). Showing
  // nothing is correct there; the effect re-runs this a tick later.
  if (now === 0) return undefined;
  return requests.find((request) => {
    if (ACTIVE_STATUSES.includes(request.status)) return false;
    const endedAt = request.resolved_at ?? request.cancelled_at;
    if (!endedAt) return false;
    return now - new Date(endedAt).getTime() < TERMINAL_VISIBLE_MS;
  });
}

function etaCopy(request: HubAssistanceRequest) {
  const minutes = Math.max(1, Math.round(request.eta_seconds / 60));
  const phrase = `about ${minutes} minute${minutes === 1 ? "" : "s"}`;
  if (request.eta_confidence === "data_derived") {
    return {
      title: `Someone should reach you in ${phrase}.`,
      note: "Based on how quickly staff answered recent calls here.",
    };
  }
  if (request.eta_confidence === "limited_history") {
    return {
      title: `Someone should reach you in ${phrase}.`,
      note: "This is an early estimate from only a few recent calls, so it may change.",
    };
  }
  // No acknowledgement history yet: name the conservative default plainly
  // instead of referring to a figure that is not on screen.
  return {
    title: `Someone should reach you in ${phrase}.`,
    note: "There is no response history for this building yet, so this is a cautious estimate rather than a measured time.",
  };
}

function statusHeading(request: HubAssistanceRequest) {
  if (request.status === "resolved") return "This help request is finished.";
  if (request.status === "cancelled") return "The care team cancelled this help request.";
  if (request.status === "en_route") return "Help is coming. A caregiver is on the way.";
  if (request.status === "acknowledged") return "A caregiver has seen your request.";
  if (request.source === "auto_fall_dispatch") return "A fall was detected. Help was called for you.";
  return "Your request was sent to the care team.";
}

function kindLabel(kind: AssistanceKind) {
  if (kind === "emergency") return "Emergency help";
  if (kind === "family_contact") return "Call family";
  return "Assistance";
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
  return {
    assistanceRequests: requests.data as HubAssistanceRequest[],
    visitorPrompts: prompts.data as HubVisitorPrompt[],
  };
}

/** Resolves to the action result, or to a timeout marker — never hangs. */
async function withTimeout<T>(work: Promise<T>): Promise<T | "timeout"> {
  let timer: ReturnType<typeof setTimeout>;
  const timeout = new Promise<"timeout">((resolve) => {
    timer = setTimeout(() => resolve("timeout"), ACTION_TIMEOUT_MS);
  });
  try {
    return await Promise.race([work, timeout]);
  } finally {
    clearTimeout(timer!);
  }
}

export function HubSurface({ initialState }: { initialState: HubState }) {
  const [state, setState] = useState(initialState);
  // `online` and `now` must NOT be read from navigator/Date during the first
  // render: the server has neither, and the mismatch throws a hydration error
  // that leaves every button inert until React recovers. Both start at a
  // server-safe constant and are corrected in the effect below.
  const [online, setOnline] = useState(true);
  const [notice, setNotice] = useState<Notice | null>(null);
  // Which single action is in flight. Only that control locks, so a slow
  // "Call family" can never block "Emergency help".
  const [busyKind, setBusyKind] = useState<AssistanceKind | "visitor" | null>(null);
  const [now, setNow] = useState(0);
  const busyRef = useRef(busyKind);
  busyRef.current = busyKind;

  const refresh = useCallback(async () => {
    try {
      const next = await loadLiveState();
      setState((current) => ({ ...current, ...next }));
      setOnline(true);
    } catch {
      // A failed background poll means we cannot show fresh status. It must not
      // retract a confirmation the resident has already been given, so the
      // notice is left untouched and only the connection banner changes.
      setOnline(false);
    }
  }, []);

  useEffect(() => {
    // Now that we are on the client, adopt the real clock and connection state.
    setNow(Date.now());
    setOnline(navigator.onLine);

    const onOnline = () => {
      setOnline(true);
      void refresh();
    };
    const onOffline = () => setOnline(false);
    window.addEventListener("online", onOnline);
    window.addEventListener("offline", onOffline);
    const poll = window.setInterval(() => {
      // Never re-render the panel out from under an in-flight tap.
      if (navigator.onLine && busyRef.current === null) void refresh();
    }, POLL_MS);
    // Drives the visitor countdown and the terminal-request window.
    const tick = window.setInterval(() => setNow(Date.now()), 1_000);
    return () => {
      window.removeEventListener("online", onOnline);
      window.removeEventListener("offline", onOffline);
      window.clearInterval(poll);
      window.clearInterval(tick);
    };
  }, [refresh]);

  const submitRequest = async (kind: AssistanceKind) => {
    if (busyKind) return;
    if (!navigator.onLine) {
      setOnline(false);
      setNotice({
        tone: "error",
        text: "This screen is offline, so the request was not sent. Please press the call button by your bed, or call out for staff now.",
      });
      return;
    }
    // Feedback before the network is touched: the resident sees the tap land.
    setBusyKind(kind);
    setNotice({ tone: "working", text: `Sending your ${kindLabel(kind).toLowerCase()} request…` });

    const result = await withTimeout(createAssistanceRequest(kind));
    setBusyKind(null);

    if (result === "timeout") {
      setNotice({
        tone: "error",
        text: "The request is taking too long to confirm, so we cannot be sure it was sent. Please press the call button by your bed, or call out for staff.",
      });
      return;
    }
    if (result.error) {
      setNotice({ tone: "error", text: result.error });
      return;
    }
    setNotice({
      tone: "success",
      text:
        kind === "family_contact"
          ? "Your family has been notified. They will be told you asked to speak with them."
          : "Your request was sent. The care team has been notified.",
    });
    await refresh();
  };

  const respondToVisitor = async (prompt: HubVisitorPrompt, response: "approved" | "denied") => {
    if (busyKind) return;
    if (!navigator.onLine) {
      setOnline(false);
      setNotice({
        tone: "error",
        text: "This screen is offline, so your answer was not sent. Please press the call button by your bed, or call out for staff.",
      });
      return;
    }
    setBusyKind("visitor");
    setNotice({ tone: "working", text: "Saving your answer…" });

    const result = await withTimeout(answerVisitorPrompt(prompt.id, response));
    setBusyKind(null);

    if (result === "timeout") {
      setNotice({
        tone: "error",
        text: "Your answer is taking too long to confirm. Please press the call button by your bed, or call out for staff.",
      });
      return;
    }
    if (result.error) {
      setNotice({ tone: "error", text: result.error });
      return;
    }
    setNotice({
      tone: "success",
      text:
        response === "denied"
          ? "Thank you. The care team has been told to come and check."
          : "Thank you. Your answer was saved.",
    });
    await refresh();
  };

  const request = activeRequest(state.assistanceRequests);
  const finished = request ? undefined : recentlyFinishedRequest(state.assistanceRequests, now);
  const prompt = state.visitorPrompts.find((item) => item.status === "pending");
  const shown = request ?? finished;

  return (
    <main className="hub-shell">
      <header>
        <p className="eyebrow">MeridianHub · Room {state.profile.room_id}</p>
        <h1 className="title">Hello, {state.profile.display_name}</h1>
        <p className="subhead">Choose what you need. Your care team is here to help.</p>
      </header>

      {!online && (
        <div className="connection" role="alert">
          <AlertTriangle aria-hidden="true" />
          <span>
            Connection problem: this screen cannot reach the care team right now. Please press the call button by your
            bed, or call out for staff.
          </span>
        </div>
      )}

      {notice && <NoticeBanner notice={notice} />}

      {shown && <HelpStatus request={shown} />}

      {/* While a request is open the three-way choice collapses to a single
          focus — the status — but Emergency stays on screen so the resident is
          never trapped without a way to escalate. */}
      {request ? (
        <section className="escape-row" aria-label="Urgent help">
          <button
            className="action-button emergency"
            type="button"
            aria-busy={busyKind === "emergency"}
            disabled={busyKind === "emergency"}
            onClick={() => void submitRequest("emergency")}
          >
            <span>
              <BellRing aria-hidden="true" /> Emergency help
            </span>
            <span className="action-note">Use this if you need urgent help right now.</span>
          </button>
        </section>
      ) : (
        <section className="action-grid" aria-label="Ways to get help">
          <ActionButton
            kind="assistance"
            busyKind={busyKind}
            onPress={submitRequest}
            icon={<HeartHandshake aria-hidden="true" />}
            label="Request assistance"
            note="Ask a caregiver to come to your room."
          />
          <ActionButton
            kind="family_contact"
            busyKind={busyKind}
            className="secondary"
            onPress={submitRequest}
            icon={<PhoneCall aria-hidden="true" />}
            label="Call family"
            note="Ask your family contact to call you."
          />
          <ActionButton
            kind="emergency"
            busyKind={busyKind}
            className="emergency"
            onPress={submitRequest}
            icon={<BellRing aria-hidden="true" />}
            label="Emergency help"
            note="Send an urgent alert to the care team now."
          />
        </section>
      )}

      {prompt && (
        <VisitorVerification
          prompt={prompt}
          now={now}
          busy={busyKind === "visitor"}
          locked={busyKind !== null && busyKind !== "visitor"}
          onAnswer={respondToVisitor}
        />
      )}
    </main>
  );
}

function ActionButton({
  kind,
  busyKind,
  className,
  onPress,
  icon,
  label,
  note,
}: {
  kind: AssistanceKind;
  busyKind: AssistanceKind | "visitor" | null;
  className?: string;
  onPress: (kind: AssistanceKind) => Promise<void>;
  icon: ReactNode;
  label: string;
  note: string;
}) {
  const busy = busyKind === kind;
  // Emergency is deliberately never locked out by another pending action.
  const locked = busyKind !== null && !busy && kind !== "emergency";
  return (
    <button
      className={`action-button${className ? ` ${className}` : ""}`}
      type="button"
      aria-busy={busy}
      disabled={busy || locked}
      onClick={() => void onPress(kind)}
    >
      <span>
        {busy ? <Loader2 aria-hidden="true" /> : icon} {label}
      </span>
      <span className="action-note">{busy ? "Sending…" : note}</span>
    </button>
  );
}

function NoticeBanner({ notice }: { notice: Notice }) {
  const Icon = notice.tone === "success" ? CheckCircle2 : notice.tone === "error" ? AlertTriangle : Loader2;
  return (
    <div className={`notice ${notice.tone}`} role="status" aria-live="polite">
      <Icon aria-hidden="true" />
      <span>{notice.text}</span>
    </div>
  );
}

function HelpStatus({ request }: { request: HubAssistanceRequest }) {
  const eta = etaCopy(request);
  const live = ACTIVE_STATUSES.includes(request.status);
  const steps = [
    { label: "Your request was sent", done: true },
    { label: "A caregiver has seen it", done: request.status !== "open" },
    { label: "A caregiver is on the way", done: request.status === "en_route" || request.status === "resolved" },
  ];
  return (
    <section className={`hub-card status-card ${request.status.replace("_", "-")}`} aria-live="polite">
      <p className="eyebrow">
        <ShieldCheck aria-hidden="true" /> Help status
      </p>
      <h2 className="status-heading">{statusHeading(request)}</h2>
      {live ? (
        <>
          {/* Position + check mark carry the progress, not colour alone. */}
          <ul className="status-steps">
            {steps.map((step) => (
              <li key={step.label} data-done={step.done}>
                {step.done ? <CheckCircle2 aria-hidden="true" /> : <Clock aria-hidden="true" />}
                <span>{step.label}</span>
              </li>
            ))}
          </ul>
          <div className="eta">
            {eta.title}
            <small>{eta.note}</small>
          </div>
        </>
      ) : (
        <p className="status-copy">
          You do not need to do anything else. Use the buttons below if you need help again.
        </p>
      )}
    </section>
  );
}

function VisitorVerification({
  prompt,
  now,
  busy,
  locked,
  onAnswer,
}: {
  prompt: HubVisitorPrompt;
  now: number;
  busy: boolean;
  locked: boolean;
  onAnswer: (prompt: HubVisitorPrompt, response: "approved" | "denied") => Promise<void>;
}) {
  const detected = new Date(prompt.detected_at).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  // Before the clock is adopted, assume time remains rather than rendering an
  // absurd countdown or disabling the buttons on the very first paint.
  const secondsLeft =
    now === 0 ? 120 : Math.max(0, Math.round((new Date(prompt.expires_at).getTime() - now) / 1000));

  return (
    <section className="hub-card visitor-card" aria-live="assertive">
      <p className="eyebrow">
        <UserRoundCheck aria-hidden="true" /> Visitor check
      </p>
      <h2>Is this person expected?</h2>
      <p className="visitor-details">
        {prompt.body_description ?? "Someone we do not recognise was seen at the entrance."} Seen at {detected}.
      </p>
      {/* The card used to disappear mid-decision when the prompt expired. The
          remaining time is now stated, and expiry is explained in place. */}
      {secondsLeft > 0 ? (
        <p className="visitor-countdown">
          You have about {secondsLeft} second{secondsLeft === 1 ? "" : "s"} to answer. If you are unsure, choose
          “No, get help”.
        </p>
      ) : (
        <p className="visitor-countdown">
          This visitor check has closed because there was no answer. The care team was told to check for you.
        </p>
      )}
      <div className="answer-actions">
        <button
          className="answer-button"
          type="button"
          aria-busy={busy}
          disabled={busy || locked || secondsLeft === 0}
          onClick={() => void onAnswer(prompt, "approved")}
        >
          <CheckCircle2 aria-hidden="true" /> Yes, expected
        </button>
        <button
          className="answer-button deny"
          type="button"
          aria-busy={busy}
          disabled={busy || locked || secondsLeft === 0}
          onClick={() => void onAnswer(prompt, "denied")}
        >
          <BellRing aria-hidden="true" /> No, get help
        </button>
      </div>
    </section>
  );
}
