"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { RespondToIncidentArgs } from "@/lib/types";

export interface RespondState {
  error?: string;
  errorKind?: "not_authorized" | "invalid_transition" | "unknown";
  success?: boolean;
}

export async function respondToIncident(
  incidentId: string,
  newStatus: RespondToIncidentArgs["p_new_status"],
  note: string | null
): Promise<RespondState> {
  const supabase = await createClient();

  const { error } = await supabase.rpc("respond_to_incident", {
    p_incident_id: incidentId,
    p_new_status: newStatus,
    p_note: note || null,
  });

  if (error) {
    // Postgres error codes surfaced by respond_to_incident (see
    // supabase/migrations/20260703000100_incident_rpc_and_views.sql).
    if (error.code === "42501") {
      return {
        error: "You don't have permission to respond to this incident.",
        errorKind: "not_authorized",
      };
    }
    if (error.code === "22023") {
      return {
        error: "That status change isn't valid from the incident's current state.",
        errorKind: "invalid_transition",
      };
    }
    return { error: "Something went wrong updating this incident. Try again.", errorKind: "unknown" };
  }

  revalidatePath(`/incidents/${incidentId}`);
  revalidatePath("/");
  revalidatePath("/incidents");
  return { success: true };
}
