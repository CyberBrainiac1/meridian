"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { getFloorView } from "@/lib/queries/floor";
import { formatEventType, formatRelativeTime, roomStatus } from "@/lib/format";
import { RoomStatusBadge } from "@/components/status-badge";
import type { FloorViewRow } from "@/lib/types";

export function FloorGrid({
  facilityId,
  initialRows,
}: {
  facilityId: string;
  initialRows: FloorViewRow[];
}) {
  const [rows, setRows] = useState(initialRows);
  const [connected, setConnected] = useState(false);
  const [justAlerted, setJustAlerted] = useState<Set<string>>(new Set());
  const prevIncidentIds = useRef(new Map(initialRows.map((r) => [r.resident_id, r.open_incident_id])));

  useEffect(() => {
    const supabase = createClient();

    const refetch = async () => {
      try {
        const next = await getFloorView(supabase, facilityId);
        const nextAlerted = new Set<string>();
        for (const row of next) {
          const prevId = prevIncidentIds.current.get(row.resident_id);
          if (row.open_incident_id && row.open_incident_id !== prevId) {
            nextAlerted.add(row.resident_id);
          }
        }
        setJustAlerted(nextAlerted);
        prevIncidentIds.current = new Map(next.map((r) => [r.resident_id, r.open_incident_id]));
        setRows(next);
      } catch {
        // Realtime payload arrived but the refetch failed (e.g. transient
        // network blip) — next change event will retry naturally.
      }
    };

    const channel = supabase
      .channel(`incident-events-${facilityId}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "incident_events", filter: `facility_id=eq.${facilityId}` },
        refetch
      )
      .subscribe((status) => setConnected(status === "SUBSCRIBED"));

    return () => {
      supabase.removeChannel(channel);
    };
  }, [facilityId]);

  return (
    <div>
      <div className="mb-4 flex items-center gap-2 text-xs text-[var(--color-foreground)]/60">
        <span
          className={`h-2 w-2 rounded-full ${connected ? "bg-[var(--color-success)]" : "bg-[var(--color-warning)]"}`}
          aria-hidden="true"
        />
        {connected ? "Live" : "Connecting…"}
      </div>

      {rows.length === 0 ? (
        <div className="soft-card p-8 text-center text-sm text-[var(--color-foreground)]/60">
          No residents are set up for this facility yet.
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {rows.map((row) => {
            const status = roomStatus(row.open_incident_type);
            const isNew = justAlerted.has(row.resident_id);
            return (
              <Link
                key={row.resident_id}
                href={row.open_incident_id ? `/incidents/${row.open_incident_id}` : `/residents/${row.resident_id}`}
                className={`soft-card block p-4 transition-shadow duration-200 ease-in-out hover:shadow-[var(--shadow-soft-hover)] focus-visible:outline-2 focus-visible:outline-[var(--color-primary)] ${
                  isNew ? "alert-arrive" : ""
                } ${status === "alert" ? "ring-2 ring-[var(--color-destructive)]/40" : ""}`}
              >
                <div className="flex items-start justify-between gap-2 mb-3">
                  <div className="min-w-0">
                    <p className="font-semibold truncate">{row.display_name}</p>
                    <p className="text-xs text-[var(--color-foreground)]/60">
                      {row.room_id ?? "Room unassigned"}
                    </p>
                  </div>
                  <RoomStatusBadge status={status} />
                </div>

                {row.open_incident_id ? (
                  <div className="text-sm">
                    <p className="font-medium">
                      {row.open_incident_type && formatEventType(row.open_incident_type)}
                    </p>
                    {row.open_incident_detected_at && (
                      <p className="text-xs text-[var(--color-foreground)]/60 mt-0.5">
                        {formatRelativeTime(row.open_incident_detected_at)}
                      </p>
                    )}
                  </div>
                ) : (
                  <p className="text-sm text-[var(--color-foreground)]/60">No open incidents</p>
                )}

                {row.risk_flags.length > 0 && (
                  <div className="mt-3 flex flex-wrap gap-1">
                    {row.risk_flags.map((flag) => (
                      <span
                        key={flag}
                        className="rounded-full bg-[var(--color-muted)] px-2 py-0.5 text-[11px] font-medium text-[var(--color-foreground)]/70"
                      >
                        {flag.replace(/_/g, " ")}
                      </span>
                    ))}
                  </div>
                )}
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
