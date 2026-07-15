import { CheckCircle2, AlertTriangle, OctagonAlert, WifiOff } from "lucide-react";
import type { RoomStatus } from "@/lib/format";
import type { IncidentSeverity } from "@/lib/types";

const ROOM_STATUS_CONFIG: Record<
  RoomStatus,
  { label: string; icon: typeof CheckCircle2; className: string }
> = {
  normal: {
    label: "Normal",
    icon: CheckCircle2,
    className: "bg-[var(--color-success)]/10 text-[var(--color-success-strong)]",
  },
  alert: {
    label: "Alert",
    icon: OctagonAlert,
    className: "bg-[var(--color-destructive)]/10 text-[var(--color-destructive-strong)]",
  },
  offline: {
    label: "Offline",
    icon: WifiOff,
    className: "bg-[var(--color-warning)]/10 text-[var(--color-warning-strong)]",
  },
};

export function RoomStatusBadge({ status }: { status: RoomStatus }) {
  const { label, icon: Icon, className } = ROOM_STATUS_CONFIG[status];
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold ${className}`}
    >
      <Icon size={14} aria-hidden="true" />
      {label}
    </span>
  );
}

const SEVERITY_CONFIG: Record<
  IncidentSeverity,
  { label: string; icon: typeof CheckCircle2; className: string }
> = {
  info: {
    label: "Info",
    icon: CheckCircle2,
    className: "bg-[var(--color-primary)]/10 text-[var(--color-primary)]",
  },
  warning: {
    label: "Needs attention",
    icon: AlertTriangle,
    className: "bg-[var(--color-warning)]/10 text-[var(--color-warning-strong)]",
  },
  critical: {
    label: "Emergency",
    icon: OctagonAlert,
    className: "bg-[var(--color-destructive)]/10 text-[var(--color-destructive-strong)]",
  },
};

export function SeverityBadge({ severity }: { severity: IncidentSeverity }) {
  const { label, icon: Icon, className } = SEVERITY_CONFIG[severity];
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold ${className}`}
    >
      <Icon size={14} aria-hidden="true" />
      {label}
    </span>
  );
}
