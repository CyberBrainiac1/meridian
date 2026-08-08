import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "MeridianHub",
  description: "A resident-first Meridian help and visitor verification surface.",
  appleWebApp: {
    // Pre-16.4 iPadOS reads these meta tags rather than the web manifest;
    // keeping both means "Add to Home Screen" gives a real full-screen app
    // icon on every iPad we're likely to demo on.
    capable: true,
    title: "MeridianHub",
    statusBarStyle: "black-translucent",
  },
  icons: {
    icon: [
      { url: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    apple: [{ url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" }],
  },
};

export const viewport: Viewport = {
  themeColor: "#075985",
  width: "device-width",
  initialScale: 1,
  // Deliberately no maximumScale/userScalable=no: locking pinch-zoom is a
  // senior-UX anti-pattern (§ standards audit earlier in this build).
  viewportFit: "cover",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
