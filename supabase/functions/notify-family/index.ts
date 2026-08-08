const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-internal-secret",
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

interface ClaimedSmsEscalation {
  escalation_id: string;
  attempt_id: string;
  phone_e164: string;
  body: string;
  idempotency_key: string;
}

type SmsOutcome = "provider_accepted" | "failed" | "unknown_outcome";

interface SmsSendResult {
  outcome: SmsOutcome;
  providerMessageId?: string;
  providerStatus?: string;
  errorCode?: string;
  errorMessage?: string;
}

interface SmsProvider {
  readonly name: string;
  send(escalation: ClaimedSmsEscalation): Promise<SmsSendResult>;
}

// Ordinary notification rows remain the app-notification path.  In
// particular, a legacy row whose `channel` happens to say "sms" never gets
// handed to Twilio: it has no recipient-level SMS consent record.
export function buildSendResult(notification: PendingNotification): SendResult {
  const target = notification.resident_id
    ? `family of resident ${notification.resident_id}`
    : `care team at facility ${notification.facility_id}`;
  console.log(
    `[notify-family] would deliver in-app ${notification.channel} notification to ${target}: ${notification.body}`,
  );
  return { id: notification.id, status: "sent", sent_at: new Date().toISOString() };
}

class UnconfiguredSmsProvider implements SmsProvider {
  readonly name = "unconfigured";

  async send(_escalation: ClaimedSmsEscalation): Promise<SmsSendResult> {
    // Marking the claimed attempt failed is intentional: a missing secret must
    // be visible in the audit trail, not turn into a retry storm or break push.
    return {
      outcome: "failed",
      errorCode: "provider_not_configured",
      errorMessage: "Twilio SMS secrets or status callback URL are not configured.",
    };
  }
}

class TwilioSmsProvider implements SmsProvider {
  readonly name = "twilio";

  constructor(
    private readonly accountSid: string,
    private readonly authToken: string,
    private readonly from: string,
    private readonly statusCallbackUrl: string,
  ) {}

  async send(escalation: ClaimedSmsEscalation): Promise<SmsSendResult> {
    const form = new URLSearchParams({
      To: escalation.phone_e164,
      From: this.from,
      Body: escalation.body,
      StatusCallback: this.statusCallbackUrl,
    });
    try {
      const response = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(this.accountSid)}/Messages.json`,
        {
          method: "POST",
          headers: {
            authorization: `Basic ${btoa(`${this.accountSid}:${this.authToken}`)}`,
            "content-type": "application/x-www-form-urlencoded",
            // Retained in our logs/correlation path. The database claim means
            // a transport timeout is never automatically resent.
            "Idempotency-Key": escalation.idempotency_key,
          },
          body: form.toString(),
        },
      );
      const payload = await response.json().catch(() => ({})) as Record<string, unknown>;
      if (!response.ok || typeof payload.sid !== "string") {
        return {
          outcome: "failed",
          errorCode: typeof payload.code === "number" ? String(payload.code) : `twilio_http_${response.status}`,
          errorMessage: typeof payload.message === "string" ? payload.message : "Twilio rejected the message.",
        };
      }
      return {
        outcome: "provider_accepted",
        providerMessageId: payload.sid,
        providerStatus: typeof payload.status === "string" ? payload.status : "queued",
      };
    } catch (error) {
      // A network failure after request transmission has an unknowable result;
      // do not retry automatically and risk two emergency texts.
      return {
        outcome: "unknown_outcome",
        errorCode: "twilio_transport_unknown",
        errorMessage: error instanceof Error ? error.message : "Twilio transport failed.",
      };
    }
  }
}

export function createSmsProvider(environment: Record<string, string | undefined>): SmsProvider {
  const accountSid = environment.TWILIO_ACCOUNT_SID;
  const authToken = environment.TWILIO_AUTH_TOKEN;
  const from = environment.TWILIO_FROM_NUMBER;
  const statusCallbackUrl = environment.MERIDIAN_SMS_STATUS_CALLBACK_URL;
  if (!accountSid || !authToken || !from || !statusCallbackUrl) {
    return new UnconfiguredSmsProvider();
  }
  return new TwilioSmsProvider(accountSid, authToken, from, statusCallbackUrl);
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
    { headers: supabaseHeaders(serviceKey) },
  );
  if (!response.ok) throw new Error(`fetch_pending_failed:${response.status}`);
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
      headers: { ...supabaseHeaders(serviceKey), "content-type": "application/json", prefer: "return=minimal" },
      body: JSON.stringify({ status: "sent", sent_at: sentAt }),
    },
  );
  if (!response.ok) throw new Error(`mark_sent_failed:${response.status}`);
}

async function rpc<T>(
  supabaseUrl: string,
  serviceKey: string,
  name: string,
  args: Record<string, unknown>,
): Promise<T> {
  const response = await fetch(`${supabaseUrl.replace(/\/$/, "")}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { ...supabaseHeaders(serviceKey), "content-type": "application/json" },
    body: JSON.stringify(args),
  });
  if (!response.ok) throw new Error(`rpc_${name}_failed:${response.status}`);
  return await response.json() as T;
}

function supabaseHeaders(serviceKey: string): Record<string, string> {
  return { apikey: serviceKey, authorization: `Bearer ${serviceKey}` };
}

async function processInAppNotifications(supabaseUrl: string, serviceKey: string) {
  let pending: PendingNotification[];
  try {
    pending = await fetchPendingNotifications(supabaseUrl, serviceKey, 25);
  } catch (error) {
    console.error("fetch pending notifications failed", error);
    return [{ status: "fetch_failed" }];
  }

  const results: Array<{ id: string; status: string }> = [];
  for (const notification of pending) {
    const result = buildSendResult(notification);
    try {
      await markSent(supabaseUrl, serviceKey, result.id, result.sent_at);
      results.push({ id: result.id, status: "sent" });
    } catch (error) {
      console.error("mark notification sent failed", notification.id, error);
      results.push({ id: notification.id, status: "failed" });
    }
  }
  return results;
}

async function processSmsEscalations(supabaseUrl: string, serviceKey: string) {
  try {
    await rpc<number>(supabaseUrl, serviceKey, "queue_family_sms_escalations", { p_limit: 100 });
    const claims = await rpc<ClaimedSmsEscalation[]>(
      supabaseUrl, serviceKey, "claim_family_sms_escalations", { p_limit: 25 },
    );
    const provider = createSmsProvider({
      TWILIO_ACCOUNT_SID: Deno.env.get("TWILIO_ACCOUNT_SID"),
      TWILIO_AUTH_TOKEN: Deno.env.get("TWILIO_AUTH_TOKEN"),
      TWILIO_FROM_NUMBER: Deno.env.get("TWILIO_FROM_NUMBER"),
      MERIDIAN_SMS_STATUS_CALLBACK_URL: Deno.env.get("MERIDIAN_SMS_STATUS_CALLBACK_URL"),
    });
    const results: Array<{ id: string; status: string }> = [];
    for (const claim of claims) {
      const send = await provider.send(claim);
      await rpc<void>(supabaseUrl, serviceKey, "complete_family_sms_attempt", {
        p_attempt_id: claim.attempt_id,
        p_provider_message_id: send.providerMessageId ?? null,
        p_outcome: send.outcome,
        p_provider_status: send.providerStatus ?? null,
        p_error_code: send.errorCode ?? null,
        p_error_message: send.errorMessage ?? null,
      });
      results.push({ id: claim.escalation_id, status: send.outcome });
    }
    return results;
  } catch (error) {
    // Push/in-app delivery has already been processed independently.  Surface
    // this operational failure without taking down that default channel.
    console.error("process SMS escalations failed", error);
    return [{ status: "sms_processing_failed" }];
  }
}

async function verifyTwilioSignature(
  signature: string | null,
  callbackUrl: string,
  authToken: string,
  form: URLSearchParams,
) {
  if (!signature) return false;
  const sorted = [...form.entries()].sort(([a], [b]) => a.localeCompare(b));
  const payload = callbackUrl + sorted.map(([key, value]) => key + value).join("");
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(authToken), { name: "HMAC", hash: "SHA-1" }, false, ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  const expected = btoa(String.fromCharCode(...new Uint8Array(digest)));
  return constantTimeEqual(expected, signature);
}

function constantTimeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let i = 0; i < left.length; i++) difference |= left.charCodeAt(i) ^ right.charCodeAt(i);
  return difference === 0;
}

async function handleTwilioStatus(request: Request, supabaseUrl: string, serviceKey: string) {
  const authToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  const callbackUrl = Deno.env.get("MERIDIAN_SMS_STATUS_CALLBACK_URL");
  if (!authToken || !callbackUrl) return jsonResponse({ error: "sms_callback_not_configured" }, 503);
  const form = new URLSearchParams(await request.text());
  if (!await verifyTwilioSignature(request.headers.get("x-twilio-signature"), callbackUrl, authToken, form)) {
    return jsonResponse({ error: "invalid_twilio_signature" }, 401);
  }
  const messageSid = form.get("MessageSid");
  const messageStatus = form.get("MessageStatus");
  if (!messageSid || !messageStatus) return jsonResponse({ error: "invalid_twilio_callback" }, 400);
  try {
    await rpc<void>(supabaseUrl, serviceKey, "record_family_sms_provider_status", {
      p_provider: "twilio",
      p_provider_message_id: messageSid,
      p_provider_status: messageStatus,
      p_error_code: form.get("ErrorCode"),
      p_error_message: null,
    });
  } catch (error) {
    console.error("record Twilio status failed", error);
    return jsonResponse({ error: "status_record_failed" }, 502);
  }
  return new Response(null, { status: 204 });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("MERIDIAN_SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY");
  if (!supabaseUrl || !serviceKey) return jsonResponse({ error: "server_not_configured" }, 500);

  if (new URL(request.url).searchParams.get("twilio_status") === "1") {
    return await handleTwilioStatus(request, supabaseUrl, serviceKey);
  }

  const internalSecret = Deno.env.get("MERIDIAN_INTERNAL_FUNCTION_SECRET");
  if (!internalSecret) return jsonResponse({ error: "server_not_configured" }, 500);
  if (request.headers.get("x-internal-secret") !== internalSecret) return jsonResponse({ error: "unauthorized" }, 401);

  const appResults = await processInAppNotifications(supabaseUrl, serviceKey);
  const smsResults = await processSmsEscalations(supabaseUrl, serviceKey);
  return jsonResponse({ processed: appResults.length + smsResults.length, appResults, smsResults }, 200);
});

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}
