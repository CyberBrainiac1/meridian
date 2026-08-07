import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { HubAssistanceRequest, HubProfile, HubState, HubVisitorPrompt } from "@/lib/types";

export const getHubState = cache(async (): Promise<HubState> => {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  // These are security-definer, device-scoped projections. A facility member
  // query is intentionally not used here: the Hub JWT is never a staff JWT.
  const [profileResult, requestResult, promptResult] = await Promise.all([
    supabase.from("resident_hub_profile").select("facility_id,resident_id,room_id,display_name").maybeSingle<HubProfile>(),
    supabase.from("resident_hub_assistance_feed").select("*").order("requested_at", { ascending: false }).returns<HubAssistanceRequest[]>(),
    supabase.from("resident_hub_visitor_prompt_feed").select("*").order("prompted_at", { ascending: false }).returns<HubVisitorPrompt[]>(),
  ]);

  if (profileResult.error || !profileResult.data) redirect("/login?error=not_a_provisioned_hub");
  if (requestResult.error || promptResult.error) {
    throw new Error("resident_hub_state_unavailable");
  }

  return {
    profile: profileResult.data,
    assistanceRequests: requestResult.data ?? [],
    visitorPrompts: promptResult.data ?? [],
  };
});
