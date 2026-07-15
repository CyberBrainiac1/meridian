import type { SupabaseClient } from "@supabase/supabase-js";
import type { CameraRow, VisitorObservationTimelineRow } from "@/lib/types";

// Deliberately the exact column list from api-contract.md — never select
// face_embedding_*, person_photo_*, or encrypted_face_image_path here.
const TIMELINE_COLUMNS =
  "facility_id, camera_id, match_status, detected_at, quality_score, matched_person_id, body_description, body_description_model, body_description_generated_at";

export async function getVisitorTimeline(
  supabase: SupabaseClient,
  facilityId: string
): Promise<VisitorObservationTimelineRow[]> {
  const { data, error } = await supabase
    .from("visitor_face_observations")
    .select(TIMELINE_COLUMNS)
    .eq("facility_id", facilityId)
    .order("detected_at", { ascending: false });

  if (error) throw error;
  return (data ?? []) as unknown as VisitorObservationTimelineRow[];
}

export async function getCameras(
  supabase: SupabaseClient,
  facilityId: string
): Promise<CameraRow[]> {
  const { data, error } = await supabase
    .from("cameras")
    .select("*")
    .eq("facility_id", facilityId);

  if (error) throw error;
  return data ?? [];
}
