import type { SupabaseClient } from "@supabase/supabase-js";
import type { IncidentSeverity, IncidentStatus, ResidentActivityRow } from "@/lib/types";

export interface IncidentReportFilters {
  severity?: IncidentSeverity;
  status?: IncidentStatus;
}

/** Facility-wide incident report — same documented resident_activity_view
 *  as the resident detail screen, filtered by facility_id instead of
 *  resident_id (the view already exposes facility_id as a column). */
export async function getFacilityIncidents(
  supabase: SupabaseClient,
  facilityId: string,
  filters: IncidentReportFilters = {}
): Promise<ResidentActivityRow[]> {
  let query = supabase
    .from("resident_activity_view")
    .select("*")
    .eq("facility_id", facilityId)
    .order("detected_at", { ascending: false });

  if (filters.severity) query = query.eq("severity", filters.severity);
  if (filters.status) query = query.eq("status", filters.status);

  const { data, error } = await query;
  if (error) throw error;
  return data ?? [];
}
