import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { FacilityRole } from "@/lib/types";

export interface Session {
  userId: string;
  email: string | null;
  facilityId: string;
  facilityName: string;
  role: FacilityRole;
}

/**
 * Verifies the Supabase session and resolves the caller's facility + role
 * via facility_members. Insights is a care-team-only surface (owner/admin/
 * caregiver/viewer) — a 'family' role account has no facility_members row
 * and is redirected to /login rather than shown an empty dashboard.
 * Memoized per-request with React's cache().
 */
export const verifySession = cache(async (): Promise<Session> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const { data: membership, error } = await supabase
    .from("facility_members")
    .select("facility_id, role, facilities(display_name)")
    .eq("user_id", user.id)
    .maybeSingle<{
      facility_id: string;
      role: FacilityRole;
      facilities: { display_name: string } | null;
    }>();

  if (error || !membership) {
    redirect("/login?error=no_facility_access");
  }

  return {
    userId: user.id,
    email: user.email ?? null,
    facilityId: membership.facility_id,
    facilityName: membership.facilities?.display_name ?? membership.facility_id,
    role: membership.role,
  };
});
