"use client";

import { Printer, Download } from "lucide-react";
import { formatEventType, formatStatus } from "@/lib/format";
import type { ResidentActivityRow } from "@/lib/types";

function toCsv(rows: ResidentActivityRow[]): string {
  const header = [
    "Resident",
    "Event type",
    "Severity",
    "Status",
    "Detected at",
    "Acknowledged at",
    "Resolved at",
    "Resolution note",
  ];
  const lines = rows.map((r) =>
    [
      r.display_name,
      formatEventType(r.event_type),
      r.severity,
      formatStatus(r.status),
      r.detected_at,
      r.acknowledged_at ?? "",
      r.resolved_at ?? "",
      (r.resolution_note ?? "").replace(/"/g, '""'),
    ]
      .map((field) => `"${field}"`)
      .join(",")
  );
  return [header.join(","), ...lines].join("\n");
}

export function ReportActions({ rows }: { rows: ResidentActivityRow[] }) {
  const downloadCsv = () => {
    const csv = toCsv(rows);
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `meridian-incident-report-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="no-print flex gap-2">
      <button
        type="button"
        onClick={downloadCsv}
        className="inline-flex items-center gap-1.5 rounded-[var(--radius-control)] border border-[var(--color-border)] bg-white px-3.5 py-2 text-sm font-medium transition-colors duration-200 ease-in-out hover:bg-[var(--color-muted)] focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]"
      >
        <Download size={16} aria-hidden="true" />
        Export CSV
      </button>
      <button
        type="button"
        onClick={() => window.print()}
        className="inline-flex items-center gap-1.5 rounded-[var(--radius-control)] border border-[var(--color-border)] bg-white px-3.5 py-2 text-sm font-medium transition-colors duration-200 ease-in-out hover:bg-[var(--color-muted)] focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]"
      >
        <Printer size={16} aria-hidden="true" />
        Print
      </button>
    </div>
  );
}
