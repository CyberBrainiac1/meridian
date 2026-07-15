import type { SupabaseClient } from "@supabase/supabase-js";
import type { FloorViewRow } from "@/lib/types";

export async function getFloorView(
  supabase: SupabaseClient,
  facilityId: string
): Promise<FloorViewRow[]> {
  const { data, error } = await supabase
    .from("facility_floor_view")
    .select("*")
    .eq("facility_id", facilityId)
    .order("room_id", { ascending: true, nullsFirst: false });

  if (error) throw error;
  return data ?? [];
}
