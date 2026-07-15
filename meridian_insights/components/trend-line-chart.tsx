"use client";

import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
} from "recharts";
import { formatEventType } from "@/lib/format";
import type { WeeklyPoint } from "@/lib/aggregate";
import type { IncidentEventType } from "@/lib/types";

const SERIES: { type: IncidentEventType; color: string; dash?: string }[] = [
  { type: "fall_confirmed", color: "#DC2626" }, // solid — reserved destructive red, this is the one true emergency series
  { type: "fall_suspected", color: "#B45309", dash: "6 3" },
  { type: "long_lie", color: "#0369A1", dash: "2 3" },
  { type: "unusual_inactivity", color: "#0891B2", dash: "8 3 2 3" },
];

export function TrendLineChart({ data }: { data: WeeklyPoint[] }) {
  const chartData = data.map((point) => ({
    weekLabel: point.weekLabel,
    ...point.counts,
  }));

  return (
    <div>
      <div style={{ width: "100%", height: 280 }}>
        <ResponsiveContainer>
          <LineChart data={chartData} margin={{ top: 8, right: 16, bottom: 0, left: 0 }}>
            <CartesianGrid stroke="#E0F2FE" vertical={false} />
            <XAxis
              dataKey="weekLabel"
              tick={{ fontSize: 12, fill: "#0C4A6E" }}
              axisLine={{ stroke: "#E0F2FE" }}
              tickLine={false}
            />
            <YAxis
              allowDecimals={false}
              tick={{ fontSize: 12, fill: "#0C4A6E" }}
              axisLine={{ stroke: "#E0F2FE" }}
              tickLine={false}
              width={28}
            />
            <Tooltip
              contentStyle={{ borderRadius: 10, borderColor: "#E0F2FE", fontSize: 13 }}
              formatter={(value, name) => [value, formatEventType(String(name) as IncidentEventType)]}
            />
            <Legend
              formatter={(value: string) => formatEventType(value as IncidentEventType)}
              wrapperStyle={{ fontSize: 12 }}
            />
            {SERIES.map((s) => (
              <Line
                key={s.type}
                type="monotone"
                dataKey={s.type}
                name={s.type}
                stroke={s.color}
                strokeWidth={2}
                strokeDasharray={s.dash}
                dot={{ r: 3 }}
                activeDot={{ r: 5 }}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>

      {/* Text table alongside the chart — counts are never color-only. */}
      <div className="mt-4 overflow-x-auto">
        <table className="w-full text-xs font-[family-name:var(--font-fira-code)]">
          <thead>
            <tr className="text-left text-[var(--color-foreground-muted)]">
              <th className="pr-4 py-1 font-medium">Week</th>
              {SERIES.map((s) => (
                <th key={s.type} className="pr-4 py-1 font-medium">
                  {formatEventType(s.type)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.map((point) => (
              <tr key={point.weekStart} className="border-t border-[var(--color-border)]">
                <td className="pr-4 py-1">{point.weekLabel}</td>
                {SERIES.map((s) => (
                  <td key={s.type} className="pr-4 py-1 tabular-nums">
                    {point.counts[s.type]}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
