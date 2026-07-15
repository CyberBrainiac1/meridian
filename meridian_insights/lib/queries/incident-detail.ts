import type { SupabaseClient } from "@supabase/supabase-js";
import type { IncidentEventRow } from "@/lib/types";

export async function getIncident(
  supabase: SupabaseClient,
  incidentId: string
): Promise<IncidentEventRow | null> {
  const { data, error } = await supabase
    .from("incident_events")
    .select("*")
    .eq("id", incidentId)
    .maybeSingle();

  if (error) throw error;
  return data;
}
