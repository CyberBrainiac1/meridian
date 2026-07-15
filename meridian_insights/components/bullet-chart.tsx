import { formatSeconds } from "@/lib/format";

/**
 * Response-time target. Not specified in the PRD/API contract (only the
 * Sense-side detection-to-alert budget of 15s and a demo anecdote of a
 * 90s staff response exist as reference points) — this is a UI display
 * convention, not backend-sourced data, so it's set here as the smallest
 * reasonable choice: 120s ("good"), with a 90s "excellent" inner band
 * matching the pitch narrative's own benchmark. Easy to make configurable
 * per facility later if the business wants a real SLA field.
 */
const TARGET_SECONDS = 120;
const EXCELLENT_SECONDS = 90;
const MAX_SCALE_SECONDS = 240;

export function BulletChart({
  label,
  sublabel,
  valueSeconds,
  incidentCount,
}: {
  label: string;
  sublabel: string;
  valueSeconds: number | null;
  incidentCount: number;
}) {
  const hasData = valueSeconds !== null;
  const pct = (n: number) => Math.min(100, (n / MAX_SCALE_SECONDS) * 100);
  const overTarget = hasData && valueSeconds > TARGET_SECONDS;

  return (
    <div className="soft-card p-4">
      <div className="flex items-baseline justify-between gap-2 mb-1">
        <div>
          <p className="font-semibold text-sm">{label}</p>
          <p className="text-xs text-[var(--color-foreground)]/60">{sublabel}</p>
        </div>
        <p
          className={`text-lg font-semibold tabular-nums ${
            overTarget ? "text-[var(--color-warning)]" : "text-[var(--color-foreground)]"
          }`}
        >
          {hasData ? formatSeconds(valueSeconds) : "No data"}
        </p>
      </div>

      {hasData ? (
        <div
          role="img"
          aria-label={`Average acknowledgment time ${formatSeconds(valueSeconds)}, target ${formatSeconds(
            TARGET_SECONDS
          )}`}
          className="relative h-4 rounded-full bg-[var(--color-muted)] overflow-hidden mt-2"
        >
          {/* qualitative bands: excellent / acceptable / needs-improvement */}
          <div
            className="absolute inset-y-0 left-0 bg-[var(--color-success)]/15"
            style={{ width: `${pct(EXCELLENT_SECONDS)}%` }}
          />
          <div
            className="absolute inset-y-0 bg-[var(--color-warning)]/10"
            style={{ left: `${pct(EXCELLENT_SECONDS)}%`, width: `${pct(TARGET_SECONDS) - pct(EXCELLENT_SECONDS)}%` }}
          />
          {/* actual value bar */}
          <div
            className={`absolute inset-y-1 left-0 rounded-full ${
              overTarget ? "bg-[var(--color-warning)]" : "bg-[var(--color-primary)]"
            }`}
            style={{ width: `${pct(valueSeconds)}%` }}
          />
          {/* target tick */}
          <div
            className="absolute inset-y-0 w-0.5 bg-[var(--color-foreground)]"
            style={{ left: `${pct(TARGET_SECONDS)}%` }}
            aria-hidden="true"
          />
        </div>
      ) : (
        <div className="h-4 rounded-full bg-[var(--color-muted)] mt-2 skeleton-shimmer" />
      )}

      <div className="flex items-center justify-between mt-1.5 text-[11px] text-[var(--color-foreground)]/50">
        <span>Target: {formatSeconds(TARGET_SECONDS)}</span>
        <span>{incidentCount} incident{incidentCount === 1 ? "" : "s"}</span>
      </div>
    </div>
  );
}
