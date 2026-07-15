import type { IncidentEventType, ResidentActivityRow } from "@/lib/types";

/** Event types treated as fall-risk-relevant for the trend proxy chart
 *  (see lib/queries/resident.ts callers) — not a backend-defined category,
 *  a frontend display grouping over the real event_type enum. */
export const FALL_RISK_EVENT_TYPES: IncidentEventType[] = [
  "fall_confirmed",
  "fall_suspected",
  "long_lie",
  "unusual_inactivity",
];

export interface WeeklyPoint {
  weekStart: string; // ISO date, Monday of the week
  weekLabel: string;
  counts: Record<IncidentEventType, number>;
}

function startOfIsoWeek(date: Date): Date {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = d.getUTCDay() || 7; // Sunday -> 7
  if (day !== 1) d.setUTCDate(d.getUTCDate() - (day - 1));
  return d;
}

/** Buckets incident rows into ISO weeks covering the last `weeks` weeks
 *  (including weeks with zero incidents, so the line chart shows a real
 *  trend rather than skipping gaps). */
export function weeklyIncidentSeries(
  rows: ResidentActivityRow[],
  weeks = 8,
  eventTypes: IncidentEventType[] = FALL_RISK_EVENT_TYPES
): WeeklyPoint[] {
  const now = startOfIsoWeek(new Date());
  const buckets: WeeklyPoint[] = [];

  for (let i = weeks - 1; i >= 0; i--) {
    const weekStart = new Date(now);
    weekStart.setUTCDate(weekStart.getUTCDate() - i * 7);
    const counts = Object.fromEntries(eventTypes.map((t) => [t, 0])) as Record<
      IncidentEventType,
      number
    >;
    buckets.push({
      weekStart: weekStart.toISOString().slice(0, 10),
      weekLabel: weekStart.toLocaleDateString(undefined, { month: "short", day: "numeric" }),
      counts,
    });
  }

  for (const row of rows) {
    if (!eventTypes.includes(row.event_type)) continue;
    const rowWeek = startOfIsoWeek(new Date(row.detected_at)).toISOString().slice(0, 10);
    const bucket = buckets.find((b) => b.weekStart === rowWeek);
    if (bucket) bucket.counts[row.event_type] += 1;
  }

  return buckets;
}
