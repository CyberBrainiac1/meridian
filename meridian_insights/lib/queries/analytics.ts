import type { SupabaseClient } from "@supabase/supabase-js";
import type { ResponseMetricRow } from "@/lib/types";

export async function getResponseMetrics(
  supabase: SupabaseClient,
  facilityId: string
): Promise<ResponseMetricRow[]> {
  const { data, error } = await supabase
    .from("facility_response_metrics")
    .select("*")
    .eq("facility_id", facilityId)
    .order("shift_date", { ascending: false });

  if (error) throw error;
  return data ?? [];
}
