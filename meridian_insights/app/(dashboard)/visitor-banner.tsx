"use client";

import { useEffect, useState } from "react";
import { X, DoorOpen } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import type { NotificationRow } from "@/lib/types";

/** Realtime "someone just walked in" banner — same notifications table
 *  used by the Care app's new-visitor alert (api-contract.md), filtered
 *  client-side to resident_id is null per that doc's guidance. Insights
 *  treats this as an audit-trail-style banner (realtime-channels.md),
 *  not a page of its own. */
export function VisitorBanner({ facilityId }: { facilityId: string }) {
  const [latest, setLatest] = useState<NotificationRow | null>(null);
  const [dismissed, setDismissed] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel(`notifications-${facilityId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "notifications", filter: `facility_id=eq.${facilityId}` },
        (payload) => {
          const row = payload.new as NotificationRow;
          if (row.resident_id === null) setLatest(row);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [facilityId]);

  if (!latest || dismissed === latest.id) return null;

  return (
    <div
      role="status"
      className="alert-arrive no-print mb-4 flex items-center justify-between gap-3 rounded-[var(--radius-control)] border border-[var(--color-primary)]/20 bg-[var(--color-primary)]/5 px-4 py-3"
    >
      <div className="flex items-center gap-2.5">
        <DoorOpen size={18} className="text-[var(--color-primary)]" aria-hidden="true" />
        <p className="text-sm font-medium">{latest.body}</p>
      </div>
      <button
        type="button"
        onClick={() => setDismissed(latest.id)}
        aria-label="Dismiss"
        className="rounded-full p-1.5 text-[var(--color-foreground-muted)] hover:bg-[var(--color-primary)]/10 focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]"
      >
        <X size={16} aria-hidden="true" />
      </button>
    </div>
  );
}
