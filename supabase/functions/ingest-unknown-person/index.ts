const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const cryptoAlgorithms = new Set(["AES-256-GCM", "XCHACHA20-POLY1305"]);
const forbiddenPlaintextFields = [
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
  "embedding",
  "face_embedding",
  "embedding_vector",
];

type EnrollmentPayload = Record<string, unknown>;

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
    Deno.env.get("SUPABASE_SECRET_KEY") ??
    Deno.env.get("SUPABASE_SECRET_KEYS");

  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "server_not_configured" }, 500);
  }

  let payload: EnrollmentPayload;
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

  const existing = await findExistingEnrollment(
    supabaseUrl,
    serviceKey,
    facilityId,
    valueAsString(payload.source_event_id),
    payload.face_embedding_digest as string,
  );
  if (existing.error) {
    return jsonResponse({ error: existing.error }, 502);
  }
  if (existing.id) {
    return jsonResponse({ id: existing.id, status: "pending", deduped: true }, 200);
  }

  const row = {
    facility_id: payload.facility_id,
    camera_id: payload.camera_id ?? null,
    source_event_id: payload.source_event_id ?? null,
    detected_at: payload.detected_at,
    quality_score: payload.quality_score ?? null,
    match_threshold: payload.match_threshold ?? null,
    match_confidence: payload.match_confidence ?? payload.confidence ?? null,
    face_embedding_ciphertext: payload.face_embedding_ciphertext,
    face_embedding_digest: payload.face_embedding_digest,
    face_embedding_key_id: payload.face_embedding_key_id,
    face_embedding_nonce: payload.face_embedding_nonce,
    face_embedding_algorithm: payload.face_embedding_algorithm,
    face_embedding_model: payload.face_embedding_model ?? "arcface",
    face_embedding_dimensions: payload.face_embedding_dimensions,
    face_embedding_expires_at: payload.face_embedding_expires_at ?? null,
    snapshot_local_ref: payload.snapshot_ref ?? null,
    encrypted_snapshot_path: payload.encrypted_snapshot_path ?? null,
    snapshot_sha256: payload.snapshot_sha256 ?? null,
    snapshot_key_id: payload.snapshot_key_id ?? null,
    snapshot_nonce: payload.snapshot_nonce ?? null,
    snapshot_algorithm: payload.snapshot_algorithm ?? null,
    snapshot_expires_at: payload.snapshot_expires_at ?? null,
    metadata: {
      ...(isPlainObject(payload.metadata) ? payload.metadata : {}),
      ingest_actor_user_id: actorUserId,
      match_status: "unknown",
    },
  };

  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/rest/v1/pending_person_enrollments?select=id,status`,
    {
      method: "POST",
      headers: {
        "apikey": serviceKey,
        "authorization": `Bearer ${serviceKey}`,
        "content-type": "application/json",
        "prefer": "return=representation",
      },
      body: JSON.stringify(row),
    },
  );

  if (!response.ok) {
    if (response.status === 409) {
      const retry = await findExistingEnrollment(
        supabaseUrl,
        serviceKey,
        facilityId,
        valueAsString(payload.source_event_id),
        payload.face_embedding_digest as string,
      );
      if (retry.id) {
        return jsonResponse({ id: retry.id, status: "pending", deduped: true }, 200);
      }
    }

    console.error("pending enrollment insert failed", response.status, await response.text());
    return jsonResponse({ error: "insert_failed" }, 502);
  }

  const inserted = await response.json() as Array<{ id: string; status: string }>;
  return jsonResponse({ id: inserted[0]?.id, status: inserted[0]?.status ?? "pending" }, 201);
});

function validatePayload(payload: EnrollmentPayload): { ok: true } | { ok: false; error: string } {
  for (const field of forbiddenPlaintextFields) {
    if (Object.hasOwn(payload, field)) {
      return { ok: false, error: "plaintext_biometric_or_media_not_accepted" };
    }
  }

  if (payload.match_status !== undefined && payload.match_status !== "unknown") {
    return { ok: false, error: "only_unknown_faces_are_enrolled" };
  }

  if (payload.person_id !== undefined && payload.person_id !== null) {
    return { ok: false, error: "known_person_not_pending_enrollment" };
  }

  const facilityId = valueAsString(payload.facility_id);
  if (!facilityId || !isMeridianId(facilityId)) {
    return { ok: false, error: "facility_id_required" };
  }

  if (payload.camera_id !== undefined && payload.camera_id !== null) {
    const cameraId = valueAsString(payload.camera_id);
    if (!cameraId || !isMeridianId(cameraId)) {
      return { ok: false, error: "camera_id_invalid" };
    }
  }

  if (payload.source_event_id !== undefined && payload.source_event_id !== null) {
    const eventId = valueAsString(payload.source_event_id);
    if (!eventId || !isMeridianId(eventId)) {
      return { ok: false, error: "source_event_id_invalid" };
    }
  }

  const detectedAt = valueAsString(payload.detected_at);
  if (!detectedAt || Number.isNaN(Date.parse(detectedAt))) {
    return { ok: false, error: "detected_at_required" };
  }

  for (const field of ["quality_score", "match_threshold", "match_confidence", "confidence"]) {
    const value = payload[field];
    if (value !== undefined && value !== null) {
      if (typeof value !== "number" || value < 0 || value > 1) {
        return { ok: false, error: `${field}_invalid` };
      }
    }
  }

  const ciphertext = valueAsString(payload.face_embedding_ciphertext);
  if (!ciphertext || ciphertext.length < 32) {
    return { ok: false, error: "face_embedding_ciphertext_required" };
  }

  const digest = valueAsString(payload.face_embedding_digest);
  if (!digest || !/^[a-f0-9]{64}$/.test(digest)) {
    return { ok: false, error: "face_embedding_digest_invalid" };
  }

  if (!valueAsString(payload.face_embedding_key_id)) {
    return { ok: false, error: "face_embedding_key_id_required" };
  }

  if (!valueAsString(payload.face_embedding_nonce)) {
    return { ok: false, error: "face_embedding_nonce_required" };
  }

  const embeddingAlgorithm = valueAsString(payload.face_embedding_algorithm);
  if (!embeddingAlgorithm || !cryptoAlgorithms.has(embeddingAlgorithm)) {
    return { ok: false, error: "face_embedding_algorithm_invalid" };
  }

  const dimensions = payload.face_embedding_dimensions;
  if (typeof dimensions !== "number" || !Number.isInteger(dimensions) || dimensions <= 0 || dimensions > 4096) {
    return { ok: false, error: "face_embedding_dimensions_invalid" };
  }

  if (payload.face_embedding_model !== undefined && payload.face_embedding_model !== null) {
    const model = valueAsString(payload.face_embedding_model);
    if (!model || model.length > 80) {
      return { ok: false, error: "face_embedding_model_invalid" };
    }
  }

  if (payload.face_embedding_expires_at !== undefined && payload.face_embedding_expires_at !== null) {
    const expiresAt = valueAsString(payload.face_embedding_expires_at);
    if (!expiresAt || Number.isNaN(Date.parse(expiresAt))) {
      return { ok: false, error: "face_embedding_expires_at_invalid" };
    }
  }

  if (payload.snapshot_ref !== undefined && payload.snapshot_ref !== null) {
    const snapshotRef = valueAsString(payload.snapshot_ref);
    if (!snapshotRef || snapshotRef.length > 512) {
      return { ok: false, error: "snapshot_ref_invalid" };
    }
  }

  if (payload.metadata !== undefined && !isPlainObject(payload.metadata)) {
    return { ok: false, error: "metadata_invalid" };
  }

  const snapshotPath = valueAsString(payload.encrypted_snapshot_path);
  if (!snapshotPath) {
    return { ok: true };
  }

  if (!snapshotPath.startsWith(`${facilityId}/`) || snapshotPath.includes("..") || !snapshotPath.endsWith(".bin")) {
    return { ok: false, error: "encrypted_snapshot_path_invalid" };
  }

  const sha256 = valueAsString(payload.snapshot_sha256);
  if (!sha256 || !/^[a-f0-9]{64}$/.test(sha256)) {
    return { ok: false, error: "snapshot_sha256_invalid" };
  }

  if (!valueAsString(payload.snapshot_key_id)) {
    return { ok: false, error: "snapshot_key_id_required" };
  }

  if (!valueAsString(payload.snapshot_nonce)) {
    return { ok: false, error: "snapshot_nonce_required" };
  }

  const snapshotAlgorithm = valueAsString(payload.snapshot_algorithm);
  if (!snapshotAlgorithm || !cryptoAlgorithms.has(snapshotAlgorithm)) {
    return { ok: false, error: "snapshot_algorithm_invalid" };
  }

  if (payload.snapshot_expires_at !== undefined && payload.snapshot_expires_at !== null) {
    const expiresAt = valueAsString(payload.snapshot_expires_at);
    if (!expiresAt || Number.isNaN(Date.parse(expiresAt))) {
      return { ok: false, error: "snapshot_expires_at_invalid" };
    }
  }

  return { ok: true };
}

async function findExistingEnrollment(
  supabaseUrl: string,
  serviceKey: string,
  facilityId: string,
  sourceEventId: string | null,
  embeddingDigest: string,
): Promise<{ id?: string; error?: string }> {
  if (sourceEventId) {
    const bySource = await selectExistingEnrollment(supabaseUrl, serviceKey, {
      facility_id: `eq.${facilityId}`,
      source_event_id: `eq.${sourceEventId}`,
    });
    if (bySource.error || bySource.id) {
      return bySource;
    }
  }

  return await selectExistingEnrollment(supabaseUrl, serviceKey, {
    facility_id: `eq.${facilityId}`,
    face_embedding_digest: `eq.${embeddingDigest}`,
    status: "eq.pending",
  });
}

async function selectExistingEnrollment(
  supabaseUrl: string,
  serviceKey: string,
  filters: Record<string, string>,
): Promise<{ id?: string; error?: string }> {
  const params = new URLSearchParams({ select: "id", limit: "1", ...filters });
  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/rest/v1/pending_person_enrollments?${params.toString()}`,
    {
      headers: {
        "apikey": serviceKey,
        "authorization": `Bearer ${serviceKey}`,
      },
    },
  );

  if (!response.ok) {
    console.error("pending enrollment lookup failed", response.status, await response.text());
    return { error: "pending_enrollment_lookup_failed" };
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
