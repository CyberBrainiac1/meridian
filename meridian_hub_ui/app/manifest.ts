import type { MetadataRoute } from "next";

// Next.js serves this at /manifest.webmanifest and auto-links it in <head>.
// display: "standalone" plus the icons below is what turns "Add to Home
// Screen" into a real app icon with no Safari chrome, on iPadOS 16.4+ and
// modern Android/desktop PWA installs alike. iOS versions before that read
// the apple-* meta tags in layout.tsx instead, which mirror this.
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "MeridianHub",
    short_name: "MeridianHub",
    description: "Resident help and visitor verification, right from your room.",
    start_url: "/",
    display: "standalone",
    orientation: "any",
    background_color: "#ecfeff",
    theme_color: "#075985",
    icons: [
      { src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
    ],
  };
}
