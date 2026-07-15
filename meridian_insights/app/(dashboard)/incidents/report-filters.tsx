"use client";

import { useRouter, useSearchParams, usePathname } from "next/navigation";

const SEVERITIES = ["info", "warning", "critical"] as const;
const STATUSES = [
  "open",
  "acknowledged",
  "responding",
  "resolved",
  "dismissed_false_alarm",
  "escalated",
] as const;

export function ReportFilters() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const set = (key: string, value: string) => {
    const params = new URLSearchParams(searchParams.toString());
    if (value) params.set(key, value);
    else params.delete(key);
    router.push(`${pathname}?${params.toString()}`);
  };

  return (
    <div className="no-print flex flex-wrap gap-3 mb-4">
      <label className="text-sm">
        <span className="sr-only">Filter by severity</span>
        <select
          defaultValue={searchParams.get("severity") ?? ""}
          onChange={(e) => set("severity", e.target.value)}
          className="rounded-[var(--radius-control)] border border-[var(--color-border)] bg-white px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]"
        >
          <option value="">All severities</option>
          {SEVERITIES.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </select>
      </label>

      <label className="text-sm">
        <span className="sr-only">Filter by status</span>
        <select
          defaultValue={searchParams.get("status") ?? ""}
          onChange={(e) => set("status", e.target.value)}
          className="rounded-[var(--radius-control)] border border-[var(--color-border)] bg-white px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]"
        >
          <option value="">All statuses</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>
              {s.replace(/_/g, " ")}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}
