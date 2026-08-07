import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "MeridianHub",
  description: "A resident-first Meridian help and visitor verification surface.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
