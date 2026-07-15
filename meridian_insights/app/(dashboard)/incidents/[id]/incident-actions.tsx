"use client";

import { useState, useTransition } from "react";
import { CheckCircle2, ShieldAlert } from "lucide-react";
import { respondToIncident, type RespondState } from "./actions";
import type { IncidentStatus, RespondToIncidentArgs } from "@/lib/types";

const NEXT_STATUS: Record<IncidentStatus, RespondToIncidentArgs["p_new_status"][]> = {
  open: ["acknowledged", "responding", "resolved", "dismissed_false_alarm", "escalated"],
  acknowledged: ["responding", "resolved", "dismissed_false_alarm", "escalated"],
  responding: ["resolved", "dismissed_false_alarm", "escalated"],
  resolved: [],
  dismissed_false_alarm: [],
  escalated: [],
};

const STATUS_ACTION_LABEL: Record<string, string> = {
  acknowledged: "Acknowledge",
  responding: "Mark responding",
  resolved: "Resolve",
  dismissed_false_alarm: "Dismiss as false alarm",
  escalated: "Escalate",
};

export function IncidentActions({
  incidentId,
  currentStatus,
}: {
  incidentId: string;
  currentStatus: IncidentStatus;
}) {
  const [note, setNote] = useState("");
  const [result, setResult] = useState<RespondState | null>(null);
  const [pending, startTransition] = useTransition();

  const available = NEXT_STATUS[currentStatus];

  const act = (status: RespondToIncidentArgs["p_new_status"]) => {
    startTransition(async () => {
      const res = await respondToIncident(incidentId, status, note);
      setResult(res);
    });
  };

  if (available.length === 0) {
    return (
      <div className="soft-card p-4 flex items-center gap-2 text-sm text-[var(--color-success)]">
        <CheckCircle2 size={18} aria-hidden="true" />
        This incident is closed. No further action needed.
      </div>
    );
  }

  return (
    <div className="soft-card p-4">
      <label htmlFor="resolution-note" className="block text-sm font-medium mb-1.5">
        Note (optional)
      </label>
      <textarea
        id="resolution-note"
        value={note}
        onChange={(e) => setNote(e.target.value)}
        rows={2}
        placeholder="e.g. Assisted back to bed, no injury."
        className="w-full rounded-[var(--radius-control)] border border-[var(--color-border)] bg-white px-3.5 py-2.5 text-base mb-4 focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]"
      />

      <div className="flex flex-wrap gap-2">
        {available.map((status) => (
          <button
            key={status}
            type="button"
            disabled={pending}
            onClick={() => act(status)}
            className={`rounded-[var(--radius-control)] px-4 py-2.5 text-sm font-medium transition-colors duration-200 ease-in-out disabled:opacity-60 min-h-11 ${
              status === "resolved"
                ? "bg-[var(--color-success-strong)] text-white hover:bg-[var(--color-success-strong)]/90"
                : status === "escalated"
                  ? "bg-[var(--color-destructive)] text-white hover:bg-[var(--color-destructive)]/90"
                  : "border border-[var(--color-border)] bg-white hover:bg-[var(--color-muted)]"
            }`}
          >
            {STATUS_ACTION_LABEL[status]}
          </button>
        ))}
      </div>

      {result?.error && (
        <p role="alert" className="mt-3 flex items-center gap-2 text-sm font-medium text-[var(--color-destructive)]">
          <ShieldAlert size={16} aria-hidden="true" />
          {result.error}
        </p>
      )}
      {result?.success && (
        <p role="status" className="mt-3 text-sm font-medium text-[var(--color-success)]">
          Updated.
        </p>
      )}
    </div>
  );
}
