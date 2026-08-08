import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/proxy";

export function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  // manifest.webmanifest must stay reachable without a session: the browser
  // fetches it to decide whether "Add to Home Screen" is even offered, before
  // anyone has a chance to log in.
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|manifest\\.webmanifest|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
