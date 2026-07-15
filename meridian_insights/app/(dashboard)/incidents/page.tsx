import Link from "next/link";
import { verifySession } from "@/lib/dal";
import { createClient } from "@/lib/supabase/server";
import { getFacilityIncidents } from "@/lib/queries/incidents";
import { formatEventType, formatStatus, formatDate, formatClockTime } from "@/lib/format";
import { SeverityBadge } from "@/components/status-badge";
import { ReportFilters } from "./report-filters";
import { ReportActions } from "./report-actions";
import type { IncidentSeverity, IncidentStatus } from "@/lib/types";

export const metadata = { title: "Incident reports — Meridian Insights" };

export default async function IncidentsPage({
  searchParams,
}: {
  searchParams: Promise<{ severity?: string; status?: string }>;
}) {
  const { severity, status } = await searchParams;
  const session = await verifySession();
  const supabase = await createClient();
  const incidents = await getFacilityIncidents(supabase, session.facilityId, {
    severity: severity as IncidentSeverity | undefined,
    status: status as IncidentStatus | undefined,
  });

  return (
    <div>
      <div className="mb-6 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 className="text-2xl font-semibold">Incident reports</h1>
          <p className="text-sm text-[var(--color-foreground)]/70 mt-1">
            {session.facilityName} · compliance and liability documentation, {incidents.length} incident
            {incidents.length === 1 ? "" : "s"}
          </p>
        </div>
        <ReportActions rows={incidents} />
      </div>

      <ReportFilters />

      <div className="soft-card overflow-x-auto print:shadow-none print:border-0">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left border-b border-[var(--color-border)] text-[var(--color-foreground)]/60">
              <th className="px-4 py-3 font-medium">Resident</th>
              <th className="px-4 py-3 font-medium">Event</th>
              <th className="px-4 py-3 font-medium">Severity</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium font-[family-name:var(--font-fira-code)]">Detected</th>
              <th className="px-4 py-3 font-medium">Resolution</th>
            </tr>
          </thead>
          <tbody>
            {incidents.map((incident) => (
              <tr key={incident.incident_id} className="border-b border-[var(--color-border)] last:border-0 align-top">
                <td className="px-4 py-3">
                  <Link
                    href={`/residents/${incident.resident_id}`}
                    className="font-medium hover:underline focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]"
                  >
                    {incident.display_name}
                  </Link>
                </td>
                <td className="px-4 py-3">
                  <Link
                    href={`/incidents/${incident.incident_id}`}
                    className="hover:underline focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]"
                  >
                    {formatEventType(incident.event_type)}
                  </Link>
                </td>
                <td className="px-4 py-3">
                  <SeverityBadge severity={incident.severity} />
                </td>
                <td className="px-4 py-3">{formatStatus(incident.status)}</td>
                <td className="px-4 py-3 font-[family-name:var(--font-fira-code)] text-xs whitespace-nowrap">
                  {formatDate(incident.detected_at)} {formatClockTime(incident.detected_at)}
                </td>
                <td className="px-4 py-3 max-w-xs text-[var(--color-foreground)]/70">
                  {incident.resolution_note ?? "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {incidents.length === 0 && (
          <p className="p-8 text-center text-sm text-[var(--color-foreground)]/60">
            No incidents match these filters.
          </p>
        )}
      </div>
    </div>
  );
}
