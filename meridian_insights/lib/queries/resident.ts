import type { SupabaseClient } from "@supabase/supabase-js";
import type { ResidentActivityRollupRow, ResidentActivityRow, ResidentProfile } from "@/lib/types";

export async function getResidentActivity(
  supabase: SupabaseClient,
  residentId: string
): Promise<ResidentActivityRow[]> {
  const { data, error } = await supabase
    .from("resident_activity_view")
    .select("*")
    .eq("resident_id", residentId)
    .order("detected_at", { ascending: false });

  if (error) throw error;
  return data ?? [];
}

export async function getResidentProfile(
  supabase: SupabaseClient,
  residentId: string
): Promise<ResidentProfile | null> {
  const { data, error } = await supabase
    .from("resident_profiles")
    .select("*")
    .eq("person_id", residentId)
    .maybeSingle();

  if (error) throw error;
  return data;
}

export async function getLatestResidentActivityRollup(
  supabase: SupabaseClient,
  residentId: string
): Promise<ResidentActivityRollupRow | null> {
  const { data, error } = await supabase
    .from("resident_activity_rollups")
    .select("resident_id, rollup_date, daytime_pattern, nighttime_pattern, baseline_status, observation_status")
    .eq("resident_id", residentId)
    .order("rollup_date", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data;
}
