"use server";

import { createClient } from "@/lib/supabase/server";
import type { AssistanceKind } from "@/lib/types";

export interface ActionResult {
  error?: string;
}

export async function createAssistanceRequest(kind: AssistanceKind): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("create_resident_assistance_request", {
    p_request_kind: kind,
  });
  return error ? { error: "Your request could not be sent. Please use the room call button or call care staff." } : {};
}

export async function answerVisitorPrompt(promptId: string, response: "approved" | "denied"): Promise<ActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("respond_to_visitor_verification", {
    p_prompt_id: promptId,
    p_response: response,
  });
  return error ? { error: "We could not save your answer. Please use the room call button or call care staff." } : {};
}
