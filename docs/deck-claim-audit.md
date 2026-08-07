# Pitch Deck Claim Audit — "Meridian AI Pitch Deck (A)"

Every claim on all 9 slides, mapped to the code that does or does not back it.
Audited against commit `9940e71` on `main`, with `170/170` Python tests passing.

Verdicts:

| Verdict | Meaning |
|---|---|
| ✅ TRUE | Implemented and covered by tests or a runnable demo path |
| 🟡 PARTIAL | Something real exists, but the claim overstates it |
| ❌ FALSE | Nothing in the repo backs it, or it was removed |
| 🔵 BUSINESS | Not a software claim — cannot be verified from this repo |

---

## Slide 1 — Title

> "The Care Intelligence Layer for Senior Living"

Positioning, not a claim. No action.

---

## Slide 2 — The Problems

All three panels are market/problem statements about the world, not about
Meridian. Nothing to verify in code. The specific figures used as narration
("one caregiver manages 20+ residents at night", "$5,000 per month",
"15+ minutes on the floor") are 🔵 BUSINESS claims that need a citation in
the speaker notes, not an implementation.

---

## Slide 3 — The Solutions

### MeridianCaregivers

| Claim | Verdict | Evidence |
|---|---|---|
| "Instant fall detection alerts to staff in under 5 seconds" | 🟡 PARTIAL → ✅ | Detection is real (`meridian_hub/classifiers/fall_state_machine.py`) and fires with no I/O in the hot path. But `STILLNESS_CONFIRM_SECONDS = 2.0` + `CANDIDATE_WINDOW_SECONDS = 3.0` mean confirmation is 2–3 s after onset *before* delivery, and **no end-to-end measurement existed**. Now measured — see `benchmarks/alert_latency_*.md`. |
| "One-tap acknowledge confirms response time" | ✅ TRUE | `meridian_care/.../IncidentActionService.swift` → `respond_to_incident` RPC (`supabase/migrations/20260703000100_incident_rpc_and_views.sql:38`), writes `acknowledged_by` / `acknowledged_at`. |
| "Real-time visibility across all resident rooms simultaneously" | 🟡 PARTIAL | `InferenceScheduler` does fair round-robin across cameras and `camera_sources` is a list, but the shipped runner (`tools/run_live_demo.py`) drove a single source. See task 7. |
| "Response time tracked and logged for compliance" | ✅ TRUE | `avg_ack_seconds` view (`...incident_rpc_and_views.sql:122`), surfaced in `meridian_insights/lib/queries/analytics.ts`. |
| "Eliminates 'detection depends on random chance'" | ✅ TRUE | Continuous per-frame inference, not scheduled rounds. |

### MeridianFamily

| Claim | Verdict | Evidence |
|---|---|---|
| "Daily summaries showing resident activity and wellbeing" | 🟡 PARTIAL | `DailySummaryViewModel.swift` exists and works, but its own doc comment admits activity/meals **have no data source**. It only counts incidents + visitors. The slide mock shows "✓ Breakfast ✓ Activity time" — neither is detectable today. See task 5. |
| "Instant emergency notifications with resolution status" | ✅ TRUE | `notifications` table + `notify-family` Edge Function; resolution status flows through `family_incident_feed`. |
| "Verified visibility into what's actually happening" | ✅ TRUE | RLS-scoped `family_incident_feed` / `family_visitor_feed`. |

### MeridianHub

| Claim | Verdict | Evidence |
|---|---|---|
| "Immediate help dispatch when falls detected" | ❌ FALSE | No resident-facing dispatch surface existed. |
| "Independent assistance requests for seniors" | ❌ FALSE | No `assistance_request` concept anywhere — grep for "request assistance", "call family", "assistance_request" returned **zero hits** across Swift, TS, Python and SQL. |
| "Visitor verification capability for seniors" | ❌ FALSE | Visitor detection exists and notifies *caregivers*; the resident was never asked anything. |
| "Help is coming — ETA 60 seconds" (mock) | ❌ FALSE | No ETA concept. |

**This was the single largest gap in the deck: an entire claimed product surface
did not exist.** See task 2.

---

## Slide 4 — Meet the Team

🔵 BUSINESS. Two claims are checkable outside this repo (the Lumi AI and EvoLoRa
GitHub repositories); they are not in scope here.

---

## Slide 5 — MeridianCare App screenshots

| Screenshot element | Verdict | Evidence |
|---|---|---|
| Alerts feed, "Maggie may need help in Room 101" | ✅ TRUE | `AlertFeedView.swift`, resident-first copy in `alert_formatter.py`. |
| Alert detail: Acknowledge / Mark responding / Resolve / Dismiss as false alarm / Escalate | ✅ TRUE | Exactly these five transitions are enforced server-side (`...incident_rpc_and_views.sql:38-44`). |
| Optional note field | ✅ TRUE | `IncidentDetailView.swift`. |
| Shift handoff ("3 alerts in the last 8 hours. 2 resolved, 1 still open.") | ✅ TRUE | `ShiftHandoffViewModel.swift`. |
| Tab bar: Alerts / Handoff / Residents / Settings | ✅ TRUE | `RootView.swift:22-33` — matches the screenshot exactly. |

Caveat: the app is SwiftUI and has never been run on a device from this
machine (no Mac). The screenshots are real renders; the runtime path is
unverified from here. That limitation is already documented in
`docs/demo-plan.md` §0.

---

## Slide 6 — Technical Overview

| Claim | Verdict | Evidence |
|---|---|---|
| "Pose estimation runs on a Hub inside the building" | ✅ TRUE | `meridian_hub/vision/pose_estimator.py`, local ONNX session. |
| "YOLO11 on ONNX Runtime, GPU-accelerated" | ✅ TRUE | `models/yolo11s-pose-480x640.onnx`, DirectML provider with a **loudly logged** CPU fallback (`pose_estimator.py:83`). |
| "17-point skeleton" | ✅ TRUE | `NUM_KEYPOINTS = 17`. |
| "frames … discarded, never written to disk, never uploaded" | ✅ TRUE | Only `tools/hold_pose_frame.py` writes an image, and only behind an explicit `--export` flag in a dev tool. Nothing in `meridian_hub/` writes or uploads a frame. Now enforced by a test — see task 6. |
| "Fall detection and validation are fully local — no third-party AI service ever sees a resident" | ✅ TRUE, with a footnote | The daemon path (`hub_daemon.py`) makes zero network calls. The one third-party vision call (`face/body_description.py` → Hack Club → Gemini) is reached only from `tools/smoke_test_full_integration.py`, is **visitor-only**, and is not wired into the production loop. Worth stating precisely rather than absolutely. |
| "If the internet drops, detection keeps running and alerts queue locally" | ✅ TRUE | `offline_queue/queue_store.py` + `NotificationDispatcher` nacks on failure and never drops. |
| "Face data encrypted AES-256-GCM on the Hub; the key never leaves the building" | ✅ TRUE | `face/embedding_encryption.py`; the key is Hub-side config, never in a payload. |
| "The cloud stores ciphertext only — the ingest endpoint rejects plaintext outright" | ✅ TRUE | `supabase/functions/ingest-visitor-face`. |
| "A full cloud breach yields encrypted vectors and no keys" | ✅ TRUE | Follows from the two above. |
| "You can't steal what was never sent." | ✅ TRUE | Accurate and appropriately non-absolute. |

---

## Slide 7 — Product-Market Fit

| Claim | Verdict | Note |
|---|---|---|
| "Google Cloud VP approached us unsolicited…" | 🔵 BUSINESS | Unverifiable from the repo. Needs to be true and attributable if a judge asks. |
| "built a working fall detection on Raspberry Pi in 8 hours" | 🟡 PARTIAL | The Pi work is real — `benchmarks/pi4b_pose_benchmark_2026-07-02.md` and `pi4b_hub_capacity_2026-07-02.md` exist with measured numbers. The "8 hours" figure is not something code can prove. |
| "Three pilot facilities requested us without cold outreach" | 🔵 BUSINESS | |
| "Directors asked for visitor verification. We built it." | ✅ TRUE (caregiver side) | Visitor detection + encrypted observation + caregiver banner all exist. |
| "60-bed facility deploys in 2 weeks, generates 7–10K ARR" | 🔵 BUSINESS | Pricing model, not code. |

**Recommendation:** every 🔵 on this slide should be sourced in the speaker
notes. Slide 7 is where a judge is most likely to ask "says who?".

---

## Slide 8 — Competitive Advantage

| Claim | Verdict | Evidence |
|---|---|---|
| "MeridianFamily delivers daily summaries **and emergency SMS** to families" | ❌ FALSE | Commit `17a60d4` explicitly **removed Twilio SMS** in favour of in-app notification delivery. `notification_dispatcher.py`'s own docstring says "This replaces SMS as the alert-delivery mechanism." The slide claims a channel that was deleted. See task 3. |
| "MeridianHub gives seniors independent help requests and visitor verification" (×2) | ❌ FALSE | Same gap as slide 3. See task 2. |
| "Camera-based detection with zero wearable compliance issues" | ✅ TRUE | No wearable anywhere in the system. |
| "Open-source pose model with more parameters for higher accuracy" | 🟡 PARTIAL | `yolo11s-pose` is genuinely open-source and genuinely larger than `yolo11n`. But "more parameters than SafelyYou/CarePredict" is unknowable — their models are proprietary. Reword to what is defensible: open-source, auditable, and swappable. |
| "Wearables dominate (68.7% market share)" | 🔵 BUSINESS | Needs a citation. |
| "Meridian has unique advantages against each and every competitive angle!" | 🟡 PARTIAL | Overclaim. SafelyYou has FDA-adjacent deployment scale Meridian does not. |

---

## Slide 9 — Impact

> "Faster help. Less uncertainty. More dignity." / "Private by design. Human-first."

Thesis statement backed by slide 6's architecture. ✅ TRUE in spirit; nothing
to build.

---

## Summary of what had to be built

| # | Gap | Slides affected | Severity |
|---|---|---|---|
| 1 | MeridianHub resident product did not exist | 3, 8 | **Critical** — a whole claimed product |
| 2 | Emergency SMS was removed but is still claimed | 8 | **High** — claims a deleted feature |
| 3 | "Under 5 seconds" was never measured | 3 | **High** — a falsifiable number |
| 4 | "Activity and wellbeing" had no data source | 3 | Medium |
| 5 | Privacy claims were true but unproven | 6 | Medium — needs executable proof |
| 6 | Multi-camera simultaneity was untested | 3 | Medium |

Items that cannot be fixed by building and must be fixed by **editing the deck**
are listed in `docs/deck-corrections.md`.
