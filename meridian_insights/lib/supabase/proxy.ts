import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// /demo is the standalone pitch-demo skeleton screen (spec section 5) — it
// renders no facility data, only a local pose-keypoint relay, so it's
// intentionally reachable without a login for fast access during a pitch.
const PUBLIC_ROUTES = ["/login", "/demo"];

// Refreshes the Supabase session cookie on every request and redirects
// unauthenticated users away from protected routes. Called from the root
// proxy.ts. Named updateSession to match the standard @supabase/ssr Next.js
// pattern (the file itself is proxy.ts per Next.js 16's Middleware rename).
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const path = request.nextUrl.pathname;
  const isPublicRoute = PUBLIC_ROUTES.some((route) => path.startsWith(route));

  // No live Supabase project configured yet (see frontendguytodo.md) —
  // createServerClient throws on an empty URL/key, which would otherwise
  // 500 every route including /login. Public routes render their own
  // "not configured" state; protected routes still redirect to /login so
  // the app is navigable end-to-end before a project exists.
  const isConfigured = Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  );
  if (!isConfigured) {
    if (!isPublicRoute) {
      const url = request.nextUrl.clone();
      url.pathname = "/login";
      return NextResponse.redirect(url);
    }
    return response;
  }

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user && !isPublicRoute) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  if (user && path === "/login") {
    const url = request.nextUrl.clone();
    url.pathname = "/";
    return NextResponse.redirect(url);
  }

  return response;
}
