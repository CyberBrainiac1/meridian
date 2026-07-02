const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const cryptoAlgorithms = new Set(["AES-256-GCM", "XCHACHA20-POLY1305"]);
const matchStatuses = new Set(["new_visitor", "repeat_visitor", "known_visitor", "unknown"]);
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
  "face_image",
  "face_crop",
  "face_crop_bytes",
  "face_encoding",
  "encoding",
  "embedding",
  "face_embedding",
  "embedding_vector",
  "person_photo",
  "person_image",
  "body_photo",
  "body_image",
  "full_body_photo",
  "full_body_image",
];

type VisitorFacePayload = Record<string, unknown>;

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

  let payload: VisitorFacePayload;
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

  const sourceEventId = payload.source_event_id as string;
  const existing = await findExistingVisitorFaceObservation(supabaseUrl, serviceKey, sourceEventId);
  if (existing.error) {
    return jsonResponse({ error: existing.error }, 502);
  }
  if (existing.id) {
    return jsonResponse({ id: existing.id, deduped: true }, 200);
  }

  const matchStatus = valueAsString(payload.match_status) ?? "new_visitor";
  const row = {
    facility_id: payload.facility_id,
    camera_id: payload.camera_id,
    source_event_id: payload.source_event_id,
    detected_at: payload.detected_at,
    match_status: matchStatus,
    matched_person_id: payload.matched_person_id ?? null,
    quality_score: payload.quality_score ?? null,
    match_threshold: payload.match_threshold ?? null,
    match_confidence: payload.match_confidence ?? payload.confidence ?? null,
    face_embedding_ciphertext: payload.face_embedding_ciphertext,
    face_embedding_digest: payload.face_embedding_digest,
    face_embedding_key_id: payload.face_embedding_key_id,
    face_embedding_nonce: payload.face_embedding_nonce,
    face_embedding_algorithm: payload.face_embedding_algorithm,
    face_embedding_model: payload.face_embedding_model ?? "insightface:buffalo_s:arcface",
    face_embedding_dimensions: payload.face_embedding_dimensions ?? 512,
    face_embedding_expires_at: payload.face_embedding_expires_at ?? null,
    face_location: payload.face_location ?? {},
    encrypted_face_image_path: payload.encrypted_face_image_path ?? null,
    face_image_sha256: payload.face_image_sha256 ?? null,
    face_image_key_id: payload.face_image_key_id ?? null,
    face_image_nonce: payload.face_image_nonce ?? null,
    face_image_algorithm: payload.face_image_algorithm ?? null,
    face_image_expires_at: payload.face_image_expires_at ?? null,
    body_description: payload.body_description ?? null,
    body_description_model: payload.body_description_model ?? null,
    body_description_generated_at: payload.body_description_generated_at ?? null,
    person_photo_ciphertext: payload.person_photo_ciphertext ?? null,
    person_photo_sha256: payload.person_photo_sha256 ?? null,
    person_photo_key_id: payload.person_photo_key_id ?? null,
    person_photo_nonce: payload.person_photo_nonce ?? null,
    person_photo_algorithm: payload.person_photo_algorithm ?? null,
    person_photo_content_type: payload.person_photo_content_type ?? null,
    person_photo_size_bytes: payload.person_photo_size_bytes ?? null,
    person_photo_expires_at: payload.person_photo_expires_at ?? null,
    metadata: {
      ...(isPlainObject(payload.metadata) ? payload.metadata : {}),
      ingest_actor_user_id: actorUserId,
      face_recognition_library: "InsightFace",
    },
  };

  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/rest/v1/visitor_face_observations?select=id,match_status`,
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
      const retry = await findExistingVisitorFaceObservation(
        supabaseUrl,
        serviceKey,
        sourceEventId,
      );
      if (retry.id) {
        return jsonResponse({ id: retry.id, deduped: true }, 200);
      }
    }

    console.error("visitor face observation insert failed", response.status, await response.text());
    return jsonResponse({ error: "insert_failed" }, 502);
  }

  const inserted = await response.json() as Array<{ id: string; match_status: string }>;
  return jsonResponse({
    id: inserted[0]?.id,
    match_status: inserted[0]?.match_status ?? matchStatus,
  }, 201);
});

function validatePayload(payload: VisitorFacePayload): { ok: true } | { ok: false; error: string } {
  for (const field of forbiddenPlaintextFields) {
    if (Object.hasOwn(payload, field)) {
      return { ok: false, error: "plaintext_biometric_or_media_not_accepted" };
    }
  }

  const facilityId = valueAsString(payload.facility_id);
  if (!facilityId || !isMeridianId(facilityId)) {
    return { ok: false, error: "facility_id_required" };
  }

  const cameraId = valueAsString(payload.camera_id);
  if (!cameraId || !isMeridianId(cameraId)) {
    return { ok: false, error: "camera_id_required" };
  }

  const sourceEventId = valueAsString(payload.source_event_id);
  if (!sourceEventId || !isMeridianId(sourceEventId)) {
    return { ok: false, error: "source_event_id_required" };
  }

  const matchStatus = valueAsString(payload.match_status) ?? "new_visitor";
  if (!matchStatuses.has(matchStatus)) {
    return { ok: false, error: "match_status_invalid" };
  }

  if (payload.matched_person_id !== undefined && payload.matched_person_id !== null) {
    const matchedPersonId = valueAsString(payload.matched_person_id);
    if (!matchedPersonId || !isMeridianId(matchedPersonId)) {
      return { ok: false, error: "matched_person_id_invalid" };
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

  const encodingAlgorithm = valueAsString(payload.face_embedding_algorithm);
  if (!encodingAlgorithm || !cryptoAlgorithms.has(encodingAlgorithm)) {
    return { ok: false, error: "face_embedding_algorithm_invalid" };
  }

  if (
    payload.face_embedding_dimensions !== undefined && payload.face_embedding_dimensions !== null
  ) {
    const dimensions = payload.face_embedding_dimensions;
    if (
      typeof dimensions !== "number" || !Number.isInteger(dimensions) || dimensions <= 0 ||
      dimensions > 4096
    ) {
      return { ok: false, error: "face_embedding_dimensions_invalid" };
    }
  }

  if (payload.face_embedding_model !== undefined && payload.face_embedding_model !== null) {
    const model = valueAsString(payload.face_embedding_model);
    if (!model || model.length > 120) {
      return { ok: false, error: "face_embedding_model_invalid" };
    }
  }

  if (
    payload.face_embedding_expires_at !== undefined && payload.face_embedding_expires_at !== null
  ) {
    const expiresAt = valueAsString(payload.face_embedding_expires_at);
    if (!expiresAt || Number.isNaN(Date.parse(expiresAt))) {
      return { ok: false, error: "face_embedding_expires_at_invalid" };
    }
  }

  if (
    payload.face_location !== undefined && payload.face_location !== null &&
    typeof payload.face_location !== "object"
  ) {
    return { ok: false, error: "face_location_invalid" };
  }

  if (payload.metadata !== undefined && !isPlainObject(payload.metadata)) {
    return { ok: false, error: "metadata_invalid" };
  }

  const bodyDescription = valueAsString(payload.body_description);
  if (payload.body_description !== undefined && payload.body_description !== null) {
    if (!bodyDescription || bodyDescription.length > 700) {
      return { ok: false, error: "body_description_invalid" };
    }
  }

  if (payload.body_description_model !== undefined && payload.body_description_model !== null) {
    const model = valueAsString(payload.body_description_model);
    if (!model || model.length > 120) {
      return { ok: false, error: "body_description_model_invalid" };
    }
  }

  if (
    payload.body_description_generated_at !== undefined &&
    payload.body_description_generated_at !== null
  ) {
    const generatedAt = valueAsString(payload.body_description_generated_at);
    if (!generatedAt || Number.isNaN(Date.parse(generatedAt))) {
      return { ok: false, error: "body_description_generated_at_invalid" };
    }
  }

  const faceImagePath = valueAsString(payload.encrypted_face_image_path);
  if (!faceImagePath) {
    return { ok: true };
  }

  if (
    !faceImagePath.startsWith(`${facilityId}/`) || faceImagePath.includes("..") ||
    !faceImagePath.endsWith(".bin")
  ) {
    return { ok: false, error: "encrypted_face_image_path_invalid" };
  }

  const sha256 = valueAsString(payload.face_image_sha256);
  if (!sha256 || !/^[a-f0-9]{64}$/.test(sha256)) {
    return { ok: false, error: "face_image_sha256_invalid" };
  }

  if (!valueAsString(payload.face_image_key_id)) {
    return { ok: false, error: "face_image_key_id_required" };
  }

  if (!valueAsString(payload.face_image_nonce)) {
    return { ok: false, error: "face_image_nonce_required" };
  }

  const faceImageAlgorithm = valueAsString(payload.face_image_algorithm);
  if (!faceImageAlgorithm || !cryptoAlgorithms.has(faceImageAlgorithm)) {
    return { ok: false, error: "face_image_algorithm_invalid" };
  }

  if (payload.face_image_expires_at !== undefined && payload.face_image_expires_at !== null) {
    const expiresAt = valueAsString(payload.face_image_expires_at);
    if (!expiresAt || Number.isNaN(Date.parse(expiresAt))) {
      return { ok: false, error: "face_image_expires_at_invalid" };
    }
  }

  const personPhotoCiphertext = valueAsString(payload.person_photo_ciphertext);
  if (!personPhotoCiphertext) {
    return { ok: true };
  }

  if (personPhotoCiphertext.length < 32) {
    return { ok: false, error: "person_photo_ciphertext_invalid" };
  }

  const personPhotoSha256 = valueAsString(payload.person_photo_sha256);
  if (!personPhotoSha256 || !/^[a-f0-9]{64}$/.test(personPhotoSha256)) {
    return { ok: false, error: "person_photo_sha256_invalid" };
  }

  if (!valueAsString(payload.person_photo_key_id)) {
    return { ok: false, error: "person_photo_key_id_required" };
  }

  if (!valueAsString(payload.person_photo_nonce)) {
    return { ok: false, error: "person_photo_nonce_required" };
  }

  const personPhotoAlgorithm = valueAsString(payload.person_photo_algorithm);
  if (!personPhotoAlgorithm || !cryptoAlgorithms.has(personPhotoAlgorithm)) {
    return { ok: false, error: "person_photo_algorithm_invalid" };
  }

  const personPhotoContentType = valueAsString(payload.person_photo_content_type);
  if (
    !personPhotoContentType ||
    !["image/jpeg", "image/png", "image/webp"].includes(personPhotoContentType)
  ) {
    return { ok: false, error: "person_photo_content_type_invalid" };
  }

  const personPhotoSizeBytes = payload.person_photo_size_bytes;
  if (
    typeof personPhotoSizeBytes !== "number" ||
    !Number.isInteger(personPhotoSizeBytes) ||
    personPhotoSizeBytes <= 0 ||
    personPhotoSizeBytes > 10_485_760
  ) {
    return { ok: false, error: "person_photo_size_bytes_invalid" };
  }

  if (payload.person_photo_expires_at !== undefined && payload.person_photo_expires_at !== null) {
    const expiresAt = valueAsString(payload.person_photo_expires_at);
    if (!expiresAt || Number.isNaN(Date.parse(expiresAt))) {
      return { ok: false, error: "person_photo_expires_at_invalid" };
    }
  }

  return { ok: true };
}

async function findExistingVisitorFaceObservation(
  supabaseUrl: string,
  serviceKey: string,
  sourceEventId: string,
): Promise<{ id?: string; error?: string }> {
  const params = new URLSearchParams({
    select: "id",
    source_event_id: `eq.${sourceEventId}`,
    limit: "1",
  });

  const response = await fetch(
    `${supabaseUrl.replace(/\/$/, "")}/rest/v1/visitor_face_observations?${params.toString()}`,
    {
      headers: {
        "apikey": serviceKey,
        "authorization": `Bearer ${serviceKey}`,
      },
    },
  );

  if (!response.ok) {
    console.error("visitor face observation lookup failed", response.status, await response.text());
    return { error: "visitor_face_observation_lookup_failed" };
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
