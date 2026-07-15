import { DoorOpen } from "lucide-react";
import { verifySession } from "@/lib/dal";
import { createClient } from "@/lib/supabase/server";
import { getVisitorTimeline, getCameras } from "@/lib/queries/visitors";
import { visitorArrivalCopy, formatRelativeTime, formatClockTime, formatDate } from "@/lib/format";

export const metadata = { title: "Visitor observations — Meridian Insights" };

export default async function VisitorsPage() {
  const session = await verifySession();
  const supabase = await createClient();
  const [observations, cameras] = await Promise.all([
    getVisitorTimeline(supabase, session.facilityId),
    getCameras(supabase, session.facilityId),
  ]);

  const cameraName = new Map(cameras.map((c) => [c.id, c.display_name ?? c.location_label ?? c.id]));

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-semibold">Visitor observations</h1>
        <p className="text-sm text-[var(--color-foreground-muted)] mt-1">
          Entry-camera activity. Unrecognized faces are logged as observations only — never shown as
          identified people.
        </p>
      </div>

      {observations.length === 0 ? (
        <div className="soft-card p-8 text-center text-sm text-[var(--color-foreground-muted)]">
          No visitor observations recorded yet.
        </div>
      ) : (
        <ol className="space-y-3">
          {observations.map((obs, i) => {
            const camera = obs.camera_id ? (cameraName.get(obs.camera_id) ?? null) : null;
            return (
              <li key={`${obs.detected_at}-${i}`} className="soft-card p-4 flex gap-3">
                <div className="mt-0.5 shrink-0 rounded-full bg-[var(--color-primary)]/10 p-2 text-[var(--color-primary)]">
                  <DoorOpen size={16} aria-hidden="true" />
                </div>
                <div className="min-w-0">
                  <p className="font-medium text-sm">{visitorArrivalCopy(obs.match_status, camera)}</p>
                  <p className="text-xs text-[var(--color-foreground-muted)] mt-0.5">
                    {formatDate(obs.detected_at)} · {formatClockTime(obs.detected_at)} ·{" "}
                    {formatRelativeTime(obs.detected_at)}
                    {obs.quality_score !== null && ` · quality ${Math.round(obs.quality_score * 100)}%`}
                  </p>
                  {obs.body_description && (
                    <p className="text-sm text-[var(--color-foreground-muted)] mt-2 italic">
                      &ldquo;{obs.body_description}&rdquo;
                    </p>
                  )}
                </div>
              </li>
            );
          })}
        </ol>
      )}
    </div>
  );
}
