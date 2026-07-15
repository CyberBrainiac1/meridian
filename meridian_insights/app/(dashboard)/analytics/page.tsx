import { verifySession } from "@/lib/dal";
import { createClient } from "@/lib/supabase/server";
import { getResponseMetrics } from "@/lib/queries/analytics";
import { formatDate } from "@/lib/format";
import { BulletChart } from "@/components/bullet-chart";

export const metadata = { title: "Response analytics — Meridian Insights" };

const SHIFT_LABEL: Record<string, string> = {
  night: "Night",
  day: "Day",
  evening: "Evening",
};

export default async function AnalyticsPage() {
  const session = await verifySession();
  const supabase = await createClient();
  const metrics = await getResponseMetrics(supabase, session.facilityId);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-semibold">Response-time analytics</h1>
        <p className="text-sm text-[var(--color-foreground-muted)] mt-1">
          Average time from alert detected to caregiver acknowledgment, by shift.
        </p>
      </div>

      {metrics.length === 0 ? (
        <div className="soft-card p-8 text-center text-sm text-[var(--color-foreground-muted)]">
          No shifts have been recorded yet.
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {metrics.map((m) => (
            <BulletChart
              key={`${m.shift_date}-${m.shift}`}
              label={`${SHIFT_LABEL[m.shift] ?? m.shift} shift`}
              sublabel={formatDate(m.shift_date)}
              valueSeconds={m.avg_ack_seconds}
              incidentCount={m.incident_count}
            />
          ))}
        </div>
      )}
    </div>
  );
}
