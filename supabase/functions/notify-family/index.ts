const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-internal-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PendingNotification {
  id: string;
  facility_id: string;
  resident_id: string | null;
  incident_id: string | null;
  channel: string;
  body: string;
}

interface SendResult {
  id: string;
  status: "sent";
  sent_at: string;
}

// Stub SMS/push provider: logs only. Swap this function body for a real
// Twilio (or Expo push) call once credentials are available — the caller
// (Deno.serve handler below) doesn't need to change.
export function buildSendResult(notification: PendingNotification): SendResult {
  console.log(
    `[notify-family] would send ${notification.channel} to family of resident ${notification.resident_id}: ${notification.body}`,
  );
  return { id: notification.id, status: "sent", sent_at: new Date().toISOString() };
}

export async function fetchPendingNotifications(
  supabaseUrl: string,
  serviceKey: string,
  limit: number,
): Promise<PendingNotification[]> {
  const params = new URLSearchParams({
    select: "id,facility_id,resident_id,incident_id,channel,body",
    status: "eq.pending",
    order: "created_at.asc",
    limit: String(limit),
  });

  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/rest/v1/notifications?${params.toString()}`,
    {
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error(`fetch_pending_failed:${response.status}`);
  }

  return await response.json() as PendingNotification[];
}

export async function markSent(
  supabaseUrl: string,
  serviceKey: string,
  id: string,
  sentAt: string,
): Promise<void> {
  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/rest/v1/notifications?id=eq.${id}`,
    {
      method: "PATCH",
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "content-type": "application/json",
        prefer: "return=minimal",
      },
      body: JSON.stringify({ status: "sent", sent_at: sentAt }),
    },
  );

  if (!response.ok) {
    throw new Error(`mark_sent_failed:${response.status}`);
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("MERIDIAN_SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SECRET_KEY");
  const internalSecret = Deno.env.get("MERIDIAN_INTERNAL_FUNCTION_SECRET");

  if (!supabaseUrl || !serviceKey || !internalSecret) {
    return jsonResponse({ error: "server_not_configured" }, 500);
  }

  if (request.headers.get("x-internal-secret") !== internalSecret) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let pending: PendingNotification[];
  try {
    pending = await fetchPendingNotifications(supabaseUrl, serviceKey, 25);
  } catch (error) {
    console.error("fetch pending notifications failed", error);
    return jsonResponse({ error: "fetch_failed" }, 502);
  }

  const results: Array<{ id: string; status: string }> = [];
  for (const notification of pending) {
    const result = buildSendResult(notification);
    try {
      await markSent(supabaseUrl, serviceKey, result.id, result.sent_at);
      results.push({ id: result.id, status: "sent" });
    } catch (error) {
      console.error("mark sent failed", notification.id, error);
      results.push({ id: notification.id, status: "failed" });
    }
  }

  return jsonResponse({ processed: results.length, results }, 200);
});

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}
