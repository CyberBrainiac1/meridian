import { notFound } from "next/navigation";
import Link from "next/link";
import { verifySession } from "@/lib/dal";
import { createClient } from "@/lib/supabase/server";
import { getIncident } from "@/lib/queries/incident-detail";
import { getResidentProfile } from "@/lib/queries/resident";
import { formatEventType, formatStatus, formatDate, formatClockTime } from "@/lib/format";
import { SeverityBadge } from "@/components/status-badge";
import { IncidentActions } from "./incident-actions";

export const metadata = { title: "Incident detail — Meridian Insights" };

export default async function IncidentDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  await verifySession();
  const supabase = await createClient();

  const incident = await getIncident(supabase, id);
  if (!incident) notFound();

  const resident = incident.resident_id ? await getResidentProfile(supabase, incident.resident_id) : null;

  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <div className="flex items-center gap-2 mb-2">
          <SeverityBadge severity={incident.severity} />
          <span className="text-xs text-[var(--color-foreground-muted)]">{formatStatus(incident.status)}</span>
        </div>
        <h1 className="text-2xl font-semibold">
          {incident.summary ?? formatEventType(incident.event_type)}
        </h1>
        <p className="text-sm text-[var(--color-foreground-muted)] mt-1">
          {formatDate(incident.detected_at)} at {formatClockTime(incident.detected_at)}
          {resident && (
            <>
              {" · "}
              <Link href={`/residents/${resident.person_id}`} className="hover:underline">
                {resident.display_name}
              </Link>
            </>
          )}
        </p>
      </div>

      <div className="soft-card p-4 mb-4 grid grid-cols-2 gap-4 text-sm">
        <div>
          <p className="text-xs text-[var(--color-foreground-muted)] mb-0.5">Event type</p>
          <p className="font-medium">{formatEventType(incident.event_type)}</p>
        </div>
        <div>
          <p className="text-xs text-[var(--color-foreground-muted)] mb-0.5">Confidence</p>
          <p className="font-medium">
            {incident.confidence !== null ? `${Math.round(incident.confidence * 100)}%` : "—"}
          </p>
        </div>
        <div>
          <p className="text-xs text-[var(--color-foreground-muted)] mb-0.5">Room</p>
          <p className="font-medium">{incident.room_id ?? "—"}</p>
        </div>
        <div>
          <p className="text-xs text-[var(--color-foreground-muted)] mb-0.5">Reason codes</p>
          <p className="font-medium">
            {incident.reason_codes.length > 0 ? incident.reason_codes.join(", ") : "—"}
          </p>
        </div>
      </div>

      {incident.resolution_note && (
        <div className="soft-card p-4 mb-4 text-sm">
          <p className="text-xs text-[var(--color-foreground-muted)] mb-1">Resolution note</p>
          <p>{incident.resolution_note}</p>
        </div>
      )}

      <IncidentActions incidentId={incident.id} currentStatus={incident.status} />
    </div>
  );
}
