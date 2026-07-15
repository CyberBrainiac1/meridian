import type { SupabaseClient } from "@supabase/supabase-js";
import type { ResidentActivityRow, ResidentProfile } from "@/lib/types";

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
