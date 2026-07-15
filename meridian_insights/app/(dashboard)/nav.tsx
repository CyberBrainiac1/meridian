"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { LayoutGrid, Gauge, ClipboardList, DoorOpen } from "lucide-react";

const LINKS = [
  { href: "/", label: "Floor status", icon: LayoutGrid },
  { href: "/analytics", label: "Response analytics", icon: Gauge },
  { href: "/incidents", label: "Incident reports", icon: ClipboardList },
  { href: "/visitors", label: "Visitor observations", icon: DoorOpen },
];

export function Nav() {
  const pathname = usePathname();

  return (
    <nav aria-label="Main" className="flex flex-col gap-1">
      {LINKS.map(({ href, label, icon: Icon }) => {
        const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? "page" : undefined}
            className={`flex items-center gap-3 rounded-[var(--radius-control)] px-3.5 py-2.5 text-sm font-medium transition-colors duration-200 ease-in-out ${
              active
                ? "bg-[var(--color-primary)] text-[var(--color-on-primary)]"
                : "text-[var(--color-foreground)] hover:bg-[var(--color-muted)]"
            }`}
          >
            <Icon size={18} aria-hidden="true" />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
