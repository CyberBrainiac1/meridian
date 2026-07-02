const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const eventTypes = new Set([
  "fall_suspected",
  "fall_confirmed",
  "long_lie",
  "unusual_inactivity",
  "wandering",
  "exit_risk",
  "night_activity",
  "device_offline",
  "stream_degraded",
  "medication_visit_missing",
  "visitor_arrival",
  "visitor_departure",
]);

const severities = new Set(["info", "warning", "critical"]);
const eventStatuses = new Set([
  "open",
  "acknowledged",
  "responding",
  "resolved",
  "dismissed_false_alarm",
  "escalated",
]);
const evidenceAlgorithms = new Set(["AES-256-GCM", "XCHACHA20-POLY1305"]);
const rawMediaFields = [
  "image",
  "frame",
  "raw_image",
  "rawImage",
  "jpeg",
  "jpg",
  "png",
  "video",
  "clip",
  "base64",
  "bytes",
  "snapshot_bytes",
];

type IncidentPayload = Record<string, unknown>;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = getServiceKey();

  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "server_not_configured" }, 500);
  }

  let payload: IncidentPayload;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const validation = validatePayload(payload);
  if (!validation.ok) {
    return jsonResponse({ error: validation.error }, 400);
  }

  const actorUserId = getJwtSubject(request.headers.get("authorization"));
  if (!actorUserId) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const facilityId = payload.facility_id as string;
  const membership = await assertFacilityWriter(supabaseUrl, serviceKey, facilityId, actorUserId);
  if (!membership.ok) {
    return jsonResponse({ error: membership.error }, membership.status);
  }

  const existing = await findExistingIncident(supabaseUrl, serviceKey, payload.event_id as string);
  if (existing.error) {
    return jsonResponse({ error: existing.error }, 502);
  }
  if (existing.id) {
    return jsonResponse({ id: existing.id, deduped: true }, 200);
  }

  const row = {
    source_event_id: payload.event_id,
    schema_version: payload.schema_version ?? "1.0",
    facility_id: payload.facility_id,
    building_id: payload.building_id ?? null,
    floor_id: payload.floor_id ?? null,
    room_id: payload.room_id ?? null,
    resident_id: payload.resident_id ?? null,
    camera_id: payload.camera_id,
    event_type: payload.event_type,
    severity: payload.severity,
    status: payload.status ?? "open",
    confidence: payload.confidence,
    detected_at: payload.detected_at,
    generated_at: payload.generated_at,
    reason_codes: payload.reason_codes,
    evidence: payload.evidence ?? {},
    device_health: payload.device_health ?? {},
    summary: payload.summary ?? null,
    encrypted_evidence_path: payload.encrypted_evidence_path ?? null,
    evidence_sha256: payload.evidence_sha256 ?? null,
    evidence_key_id: payload.evidence_key_id ?? null,
    evidence_nonce: payload.evidence_nonce ?? null,
    evidence_algorithm: payload.evidence_algorithm ?? null,
    evidence_expires_at: payload.evidence_expires_at ?? null,
    metadata: {
      ...(isPlainObject(payload.metadata) ? payload.metadata : {}),
      ingest_actor_user_id: actorUserId,
    },
  };

  const response = await fetch(`${supabaseUrl.replace(/\/$/, "")}/rest/v1/incident_events?select=id`, {
    method: "POST",
    headers: {
      "apikey": serviceKey,
      "authorization": `Bearer ${serviceKey}`,
      "content-type": "application/json",
      "prefer": "return=representation",
    },
    body: JSON.stringify(row),
  });

  if (!response.ok) {
    if (response.status === 409) {
      const retry = await findExistingIncident(supabaseUrl, serviceKey, payload.event_id as string);
      if (retry.id) {
        return jsonResponse({ id: retry.id, deduped: true }, 200);
      }
    }

    console.error("incident insert failed", response.status, await response.text());
    return jsonResponse({ error: "insert_failed" }, 502);
  }

  const inserted = await response.json() as Array<{ id: string }>;
  return jsonResponse({ id: inserted[0]?.id }, 201);
});

function validatePayload(payload: IncidentPayload): { ok: true } | { ok: false; error: string } {
  for (const field of rawMediaFields) {
    if (Object.hasOwn(payload, field)) {
      return { ok: false, error: "raw_media_not_accepted" };
    }
  }

  const eventId = valueAsString(payload.event_id);
  if (!eventId || !isMeridianId(eventId)) {
    return { ok: false, error: "event_id_required" };
  }

  const facilityId = valueAsString(payload.facility_id);
  if (!facilityId || !isMeridianId(facilityId)) {
    return { ok: false, error: "facility_id_required" };
  }

  const cameraId = valueAsString(payload.camera_id);
  if (!cameraId || !isMeridianId(cameraId)) {
    return { ok: false, error: "camera_id_required" };
  }

  for (const field of ["building_id", "floor_id", "room_id", "resident_id", "schema_version"]) {
    if (payload[field] !== undefined && payload[field] !== null) {
      const value = valueAsString(payload[field]);
      if (!value || value.length > 128) {
        return { ok: false, error: `${field}_invalid` };
      }
    }
  }

  const eventType = valueAsString(payload.event_type);
  if (!eventType || !eventTypes.has(eventType)) {
    return { ok: false, error: "event_type_invalid" };
  }

  const severity = valueAsString(payload.severity);
  if (!severity || !severities.has(severity)) {
    return { ok: false, error: "severity_invalid" };
  }

  const status = valueAsString(payload.status ?? "open");
  if (!status || !eventStatuses.has(status)) {
    return { ok: false, error: "status_invalid" };
  }

  const confidence = payload.confidence;
  if (typeof confidence !== "number" || confidence < 0 || confidence > 1) {
    return { ok: false, error: "confidence_invalid" };
  }

  const detectedAt = valueAsString(payload.detected_at);
  if (!detectedAt || Number.isNaN(Date.parse(detectedAt))) {
    return { ok: false, error: "detected_at_required" };
  }

  const generatedAt = valueAsString(payload.generated_at);
  if (!generatedAt || Number.isNaN(Date.parse(generatedAt))) {
    return { ok: false, error: "generated_at_required" };
  }

  if (!Array.isArray(payload.reason_codes) || !payload.reason_codes.every((item) => typeof item === "string")) {
    return { ok: false, error: "reason_codes_required" };
  }

  if (payload.evidence !== undefined && !isPlainObject(payload.evidence)) {
    return { ok: false, error: "evidence_invalid" };
  }

  if (payload.device_health !== undefined && !isPlainObject(payload.device_health)) {
    return { ok: false, error: "device_health_invalid" };
  }

  if (payload.metadata !== undefined && !isPlainObject(payload.metadata)) {
    return { ok: false, error: "metadata_invalid" };
  }

  if (payload.summary !== undefined && payload.summary !== null && typeof payload.summary !== "string") {
    return { ok: false, error: "summary_invalid" };
  }

  const evidencePath = valueAsString(payload.encrypted_evidence_path);
  if (!evidencePath) {
    return { ok: true };
  }

  if (!evidencePath.startsWith(`${facilityId}/`) || evidencePath.includes("..") || !evidencePath.endsWith(".bin")) {
    return { ok: false, error: "evidence_path_invalid" };
  }

  const sha256 = valueAsString(payload.evidence_sha256);
  if (!sha256 || !/^[a-f0-9]{64}$/.test(sha256)) {
    return { ok: false, error: "evidence_sha256_invalid" };
  }

  if (!valueAsString(payload.evidence_key_id)) {
    return { ok: false, error: "evidence_key_id_required" };
  }

  if (!valueAsString(payload.evidence_nonce)) {
    return { ok: false, error: "evidence_nonce_required" };
  }

  const algorithm = valueAsString(payload.evidence_algorithm);
  if (!algorithm || !evidenceAlgorithms.has(algorithm)) {
    return { ok: false, error: "evidence_algorithm_invalid" };
  }

  if (payload.evidence_expires_at !== undefined && payload.evidence_expires_at !== null) {
    const expiresAt = valueAsString(payload.evidence_expires_at);
    if (!expiresAt || Number.isNaN(Date.parse(expiresAt))) {
      return { ok: false, error: "evidence_expires_at_invalid" };
    }
  }

  return { ok: true };
}

async function findExistingIncident(
  supabaseUrl: string,
  serviceKey: string,
  eventId: string,
): Promise<{ id?: string; error?: string }> {
  const params = new URLSearchParams({
    select: "id",
    source_event_id: `eq.${eventId}`,
    limit: "1",
  });

  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/rest/v1/incident_events?${params.toString()}`,
    {
      headers: {
        "apikey": serviceKey,
        "authorization": `Bearer ${serviceKey}`,
      },
    },
  );

  if (!response.ok) {
    console.error("incident lookup failed", response.status, await response.text());
    return { error: "incident_lookup_failed" };
  }

  const rows = await response.json() as Array<{ id?: string }>;
  return rows[0]?.id ? { id: rows[0].id } : {};
}

function valueAsString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function isMeridianId(value: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/.test(value);
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function getServiceKey(): string | null {
  const explicit = Deno.env.get("MERIDIAN_SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SECRET_KEY");
  if (explicit) {
    return explicit;
  }

  const secretKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!secretKeys) {
    return null;
  }

  try {
    const parsed = JSON.parse(secretKeys) as Record<string, unknown>;
    const defaultKey = parsed.default;
    return typeof defaultKey === "string" && defaultKey.length > 0 ? defaultKey : null;
  } catch {
    return secretKeys;
  }
}

function getJwtSubject(authorization: string | null): string | null {
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) {
    return null;
  }

  const [, payload] = token.split(".");
  if (!payload) {
    return null;
  }

  try {
    const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    const decoded = JSON.parse(atob(padded));
    return typeof decoded.sub === "string" ? decoded.sub : null;
  } catch {
    return null;
  }
}

async function assertFacilityWriter(
  supabaseUrl: string,
  serviceKey: string,
  facilityId: string,
  userId: string,
): Promise<{ ok: true } | { ok: false; error: string; status: number }> {
  const params = new URLSearchParams({
    select: "role",
    facility_id: `eq.${facilityId}`,
    user_id: `eq.${userId}`,
    limit: "1",
  });

  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/rest/v1/facility_members?${params.toString()}`,
    {
      headers: {
        "apikey": serviceKey,
        "authorization": `Bearer ${serviceKey}`,
      },
    },
  );

  if (!response.ok) {
    console.error("membership lookup failed", response.status, await response.text());
    return { ok: false, error: "membership_lookup_failed", status: 502 };
  }

  const rows = await response.json() as Array<{ role?: string }>;
  const role = rows[0]?.role;
  if (!role) {
    return { ok: false, error: "facility_forbidden", status: 403 };
  }

  if (!["owner", "admin", "caregiver"].includes(role)) {
    return { ok: false, error: "facility_role_forbidden", status: 403 };
  }

  return { ok: true };
}

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}
