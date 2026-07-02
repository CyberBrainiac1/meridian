# Meridian Sense — Technical Integration PRD (for Dhairya)

From: Pranav | To: Dhairya | Date: 2026-07-02 | Status: v1.1 (updated: Pi 4B target, fully local — no Gemini)

## Why this doc exists

This is the contract between **Meridian Sense** (the room edge unit — camera, pose estimation, fall detection, facial recognition, all running on the Pi) and everything you own (Care app, Family app, Insights dashboard, backend/Supabase). You shouldn't need to read Sense's internals to build against it — everything you need to receive events, show alerts, and populate Insights is below. If something here doesn't match what your backend expects, tell me and we change the contract, not the code silently on one side.

Sense is built and running today (on a dev machine, camera-agnostic — same code path deploys to the Pi). It currently talks to a **mock ingestion server I built** that implements the exact contract below, so you can point your backend at the same schema whenever you're ready and nothing on my side has to change.

**Update from v1:** target hardware is a **Raspberry Pi 4B**, and there are **no AI API keys for this project** — Sense runs entirely on-device, including fall validation (no Gemini or any other cloud AI call anywhere in the pipeline). This actually simplifies the contract below: `validated_by` no longer has cloud/timeout variants, and the "suspected → escalate after N seconds" behavior is now near-instant since it's a local compute step, not a network wait.

## 1. What Sense sends you

Sense pushes three payload types, always as an HTTP `POST` with a JSON body, to endpoints you stand up. All three share the same delivery semantics (section 3).

### 1.1 Fall / distress alert — `POST {SENSE_ALERT_ENDPOINT}/alerts`

```json
{
  "event_id": "a1b2c3d4-...",        // UUID, idempotency key — see section 3
  "device_id": "sense-unit-014",     // which Sense unit / room camera
  "room_id": "room-12",
  "resident_id": "res-0298",         // nullable if not yet enrolled/matched
  "event_type": "fall",              // "fall" only in v1 (see section 2 for tier mapping)
  "severity": "confirmed",           // "confirmed" | "suspected"
  "confidence": 0.94,                // 0-1
  "validated_by": "state_machine",   // "state_machine" | "local_secondary_validator"
  "validation_rationale": "Rapid vertical drop, horizontal posture sustained 2.3s, no recovery motion.",
  "detected_at": "2026-07-02T14:03:11.204Z",
  "alert_fired_at": "2026-07-02T14:03:14.881Z"
}
```

- `severity: "suspected"` means the primary state machine wasn't confident enough to auto-confirm, so a second on-device validation pass (`local_secondary_validator` — different signal than the primary, no network call, runs in well under a second) is invoked; if that pass is also inconclusive it fails open to `confirmed` rather than staying silent. Either way, treat `suspected` as a real, page-worthy alert — just with lower confidence — and expect a possible follow-up event superseding it. Because validation is local, this all happens fast and doesn't depend on the Pi's WiFi being up.
- `resident_id` is null until room-to-resident assignment exists in your system — Sense only knows `room_id` for certain. You'll need a lookup on your side (or tell me the assignment API and I'll have Sense resolve it directly).

**PRD note on severity tiers:** the Care app spec (PRD 7.2) lists five tiers — fall confirmed, fall suspected, distress, missed medication, unusual inactivity. Sense v1 only produces the first two (`fall` events with `confirmed`/`suspected` severity). Distress detection, medication tracking, and inactivity flags are not in Sense's v1 scope — if your alert feed UI expects all five tiers to originate from the same event stream, we should talk about whether those come from Sense later or from a different source.

### 1.2 Visitor log — `POST {SENSE_ALERT_ENDPOINT}/visitor-log`

```json
{
  "event_id": "e5f6a7b8-...",
  "device_id": "sense-unit-entry-01",
  "location": "main-entrance",
  "match_status": "known",           // "known" | "unknown"
  "person_id": "visitor-0044",       // nullable if unknown
  "confidence": 0.88,
  "snapshot_ref": "local:2026-07-02T14-01-09_entry01.jpg",  // see note below
  "detected_at": "2026-07-02T14:01:09.552Z"
}
```

- `snapshot_ref` is a **local file reference only** in v1 — Sense does not upload images to any cloud endpoint by default (privacy architecture, PRD section 8). If Insights/Family need to display the snapshot, that requires an explicit opt-in upload path we haven't built yet — flag if you need it and we'll scope it as its own decision, not bundle it into this contract silently.
- This whole path (facial recognition) is P1 per the PRD — functional in the build, but treat it as lower-confidence-of-arrival than the alert path for the pitch timeline.

### 1.3 Weekly risk score — `POST {SENSE_ALERT_ENDPOINT}/risk-score`

```json
{
  "resident_id": "res-0298",
  "week_of": "2026-06-29",
  "score": 62,                        // 0-100, higher = more risk
  "score_version": "v1-heuristic",    // always this literal in v1 — see caveat below
  "signals": {
    "avg_gait_speed_change_pct": -8.4,
    "nighttime_movement_events": 5
  },
  "computed_at": "2026-07-02T06:00:00Z"
}
```

- **Explicitly a v1 heuristic, not a clinical signal.** Please don't surface it in the UI as a medical claim (ties to the PRD's non-goal of avoiding FDA Class II territory) — "trend flag" framing, not "risk diagnosis."

## 2. What Sense needs from you

- **The three endpoint paths above, live somewhere reachable from the Pi.** Until then, Sense talks to my local mock server (`mock_cloud/app.py`) which implements this exact contract — good enough for demos, not for the real pilot.
- **An idempotency-aware write** on your side — see section 3, this matters because of the offline queue.
- **A response contract**: `2xx` = accepted (Sense deletes the item from its local queue), anything else or a timeout = Sense retries with backoff. Please don't do slow synchronous work (e.g., waiting on a push-notification provider) inside the request — ack fast, process async, or Sense's retry logic will pile up duplicate sends.
- **Auth**: not yet specified — v1 mock has none. Tell me what you want (bearer token per device, mTLS, shared secret + HMAC) and I'll wire it into `alerting/client.py`; whatever it is, it needs to work for a device with no human present to do an OAuth flow.

## 3. Delivery guarantees (read this before building dedup logic)

Sense queues every outgoing payload locally (SQLite) before attempting delivery, so alerts survive a WiFi drop — this is a P0 requirement (PRD 7.1, "offline-first"). That means delivery is **at-least-once, not exactly-once**: if your endpoint accepts a payload but the response is lost in transit (e.g., WiFi drops mid-ack), Sense will retry and you'll receive the same `event_id` twice. **Dedup on `event_id` on your side.** This is the one thing most likely to bite you if skipped — a resident's fall alert should never double-page a caregiver, or worse, get treated as two separate incidents in Insights' incident report.

## 4. Latency budget

PRD success metric: staged fall → phone alert in **under 15 seconds**, end to end. Sense's own budget:

| Stage | Budget |
|---|---|
| Fall detected by state machine (capture → CONFIRMED) | < 5s |
| Local secondary validation, if SUSPECTED (on-device, no network) | < 1s |
| Local queue → HTTP POST to your endpoint | < 1s (LAN/WiFi, non-degraded) |
| **Your side: endpoint ack → push notification delivered to phone** | **whatever's left of the 15s budget — realistically needs to be under ~9-10s** |

Worth syncing on early: since validation is fully local now (no cloud round-trip), the confirmed-and-suspected paths both leave you most of the 15s budget — Sense's own latency no longer depends on connectivity at all. If push notification delivery (APNs round-trip, etc.) has its own tail latency, we should each measure our half separately rather than only discovering the combined number is over budget during a rehearsal.

One more Pi 4B-specific note: pose estimation runs at 320×256 / ~10 FPS by default on this hardware (no accelerator) — this is a measured number, not a guess: we benchmarked the actual pose model on the actual Pi 4B unit and 640×480 turned out to only sustain ~2.9 FPS (too slow), while 320×256 comfortably hits ~10 FPS with zero thermal throttling. The state machine's thresholds are time-based (seconds), not frame-count-based, so this doesn't change correctness, just gives less visual headroom than a higher-FPS setup would. Flagging in case it matters for how you scope any video-adjacent UI (it shouldn't — you never receive video from Sense either way).

## 5. What's mocked vs. real today

| Piece | Status |
|---|---|
| Fall detection pipeline | Real, running against webcam/video-file input |
| Gemini validation | Mocked (rule-based `MockValidator`) — same interface, swaps to real Gemini via `GEMINI_API_KEY` env var, zero code change |
| Facial recognition | Real (InsightFace), matches against a local SQLite `VisitorStore` — swaps to Supabase via `SUPABASE_URL`/`SUPABASE_KEY` env vars once your schema exists |
| Alert/visitor-log/risk-score delivery | Real, POSTing to a local mock FastAPI server that implements this exact contract |
| Your real backend | Not built yet — this doc is the spec for it |

## 6. Action items for you

1. Decide auth scheme for the ingestion endpoint (device identity matters here — no human in the loop to log in).
2. Decide the `resident_id` ⟷ `room_id` assignment source of truth — does Sense look it up, or do you resolve it on ingest?
3. Confirm whether the five Care-app severity tiers all need to originate from Sense, or whether distress/medication/inactivity come from elsewhere.
4. When your real endpoint exists, send me the URL/path and I point `SENSE_ALERT_ENDPOINT_URL` at it — no other change needed on my end.
5. Weigh in on whether family/Insights ever need the visitor snapshot image itself (currently local-only, not uploaded) — if yes, that's a privacy-relevant scope decision worth making deliberately, not by default.
