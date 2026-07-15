// Hand-mirrored from meridian_software/design-tokens/tokens.json (canonical
// source). Used where JS needs raw color values (e.g. chart series, canvas
// rendering) instead of CSS custom properties.

export const colors = {
  primary: "#0369A1",
  primaryAlt: "#0891B2",
  success: "#059669",
  warning: "#B45309",
  destructive: "#DC2626",
  foreground: "#0C4A6E",
  muted: "#E7EFF5",
  border: "#E0F2FE",
  background: "#F0F9FF",
  surface: "#FFFFFF",
} as const;

export const severityColor: Record<"info" | "warning" | "critical", string> = {
  info: colors.primary,
  warning: colors.warning,
  critical: colors.destructive,
};

export const severityLabel: Record<"info" | "warning" | "critical", string> = {
  info: "Info",
  warning: "Needs attention",
  critical: "Emergency",
};

export const demoSkeleton = {
  background: "#05060A",
  accent: "#22FFC2",
} as const;

export const motion = {
  durationMs: 200,
  easing: "ease-in-out",
} as const;
