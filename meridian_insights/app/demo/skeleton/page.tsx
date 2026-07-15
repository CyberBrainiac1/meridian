import type { Metadata } from "next";
import { SkeletonCanvas } from "./skeleton-canvas";

export const metadata: Metadata = {
  title: "Meridian — Live Pose Demo",
  description: "Standalone pitch-demo screen: on-device pose skeleton, proof video never leaves the room.",
};

// Standalone pitch-demo screen (spec section 5) — deliberately outside the
// Insights/Care/Family nav and design language. Dark, high-contrast,
// minimal chrome: the one place "technical infrastructure" is the right
// register, because everywhere else in the product should read as
// trustworthy healthcare, not surveillance tech.
export default function DemoSkeletonPage() {
  return <SkeletonCanvas />;
}
