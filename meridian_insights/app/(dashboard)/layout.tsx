import { LogOut } from "lucide-react";
import { verifySession } from "@/lib/dal";
import { signOut } from "./actions";
import { Nav } from "./nav";
import { VisitorBanner } from "./visitor-banner";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await verifySession();

  return (
    <div className="min-h-screen flex">
      <aside className="no-print w-64 shrink-0 border-r border-[var(--color-border)] bg-white/60 p-4 flex flex-col">
        <div className="px-1 mb-6">
          <p className="text-lg font-semibold text-[var(--color-foreground)]">Meridian</p>
          <p className="text-xs text-[var(--color-foreground)]/60">Insights</p>
        </div>

        <Nav />

        <div className="mt-auto pt-4 border-t border-[var(--color-border)] space-y-2">
          <div className="px-1">
            <p className="text-sm font-medium truncate">{session.facilityName}</p>
            <p className="text-xs text-[var(--color-foreground)]/60 truncate">
              {session.email} · {session.role}
            </p>
          </div>
          <form action={signOut}>
            <button
              type="submit"
              className="flex w-full items-center gap-2 rounded-[var(--radius-control)] px-3.5 py-2.5 text-sm font-medium text-[var(--color-foreground)] transition-colors duration-200 ease-in-out hover:bg-[var(--color-muted)]"
            >
              <LogOut size={16} aria-hidden="true" />
              Sign out
            </button>
          </form>
        </div>
      </aside>

      <main className="flex-1 min-w-0 p-6 md:p-8">
        <VisitorBanner facilityId={session.facilityId} />
        {children}
      </main>
    </div>
  );
}
