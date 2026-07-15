import { notFound } from "next/navigation";
import { verifySession } from "@/lib/dal";
import { createClient } from "@/lib/supabase/server";
import { getResidentActivity, getResidentProfile } from "@/lib/queries/resident";
import { weeklyIncidentSeries } from "@/lib/aggregate";
import { formatEventType, formatRelativeTime, formatStatus } from "@/lib/format";
import { SeverityBadge } from "@/components/status-badge";
import { TrendLineChart } from "@/components/trend-line-chart";

export const metadata = { title: "Resident detail — Meridian Insights" };

export default async function ResidentDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  await verifySession();
  const supabase = await createClient();

  const [profile, activity] = await Promise.all([
    getResidentProfile(supabase, id),
    getResidentActivity(supabase, id),
  ]);

  if (!profile) notFound();

  const trend = weeklyIncidentSeries(activity);

  return (
    <div>
      <div className="mb-6 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 className="text-2xl font-semibold">{profile.display_name}</h1>
          <p className="text-sm text-[var(--color-foreground)]/70 mt-1">
            {profile.room_id ?? "Room unassigned"}
          </p>
        </div>
        {profile.risk_flags.length > 0 && (
          <div className="flex flex-wrap gap-1.5">
            {profile.risk_flags.map((flag) => (
              <span
                key={flag}
                className="rounded-full bg-[var(--color-muted)] px-2.5 py-1 text-xs font-medium text-[var(--color-foreground)]/70"
              >
                {flag.replace(/_/g, " ")}
              </span>
            ))}
          </div>
        )}
      </div>

      {profile.care_notes && (
        <div className="soft-card p-4 mb-6 text-sm">
          <p className="font-medium mb-1">Care notes</p>
          <p className="text-[var(--color-foreground)]/70">{profile.care_notes}</p>
        </div>
      )}

      <section className="soft-card p-4 mb-6">
        <h2 className="font-semibold mb-1">Incident frequency by week</h2>
        <p className="text-xs text-[var(--color-foreground)]/60 mb-4">
          Detection history, not a predictive score — fall/long-lie/inactivity events over the last 8 weeks.
        </p>
        <TrendLineChart data={trend} />
      </section>

      <section className="soft-card p-4">
        <h2 className="font-semibold mb-4">Full incident history</h2>
        {activity.length === 0 ? (
          <p className="text-sm text-[var(--color-foreground)]/60">No incidents recorded for this resident.</p>
        ) : (
          <div className="divide-y divide-[var(--color-border)]">
            {activity.map((incident) => (
              <div key={incident.incident_id} className="py-3 flex items-start justify-between gap-4 flex-wrap">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <SeverityBadge severity={incident.severity} />
                    <p className="font-medium text-sm">{formatEventType(incident.event_type)}</p>
                  </div>
                  <p className="text-xs text-[var(--color-foreground)]/60">
                    {formatStatus(incident.status)} · {formatRelativeTime(incident.detected_at)}
                  </p>
                  {incident.resolution_note && (
                    <p className="text-xs text-[var(--color-foreground)]/70 mt-1 max-w-md">
                      {incident.resolution_note}
                    </p>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
