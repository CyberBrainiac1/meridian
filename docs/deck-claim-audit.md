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
| "Instant fall detection alerts to staff in under 5 seconds" | 🟡 PARTIAL | `benchmarks/alert_latency_2026-08-07.md`: reproducible Hub-to-local-HTTP-ack p95 is **2.027s confirmed / 3.200s suspected**, including measured DirectML inference substituted into a deterministic pose timeline. It does **not** include physical camera, WAN/backend, push, or staff-phone display time, so the stronger “alerts to staff” wording remains unproven and must not be presented as measured end-to-end. |
| "One-tap acknowledge confirms response time" | ✅ TRUE | `meridian_care/.../IncidentActionService.swift` → `respond_to_incident` RPC (`supabase/migrations/20260703000100_incident_rpc_and_views.sql:38`), writes `acknowledged_by` / `acknowledged_at`. |
| "Real-time visibility across all resident rooms simultaneously" | ✅ TRUE, bounded | `tools/run_live_demo.py` now accepts repeated `--source` values and schedules them fairly. `tests/test_claim_guards.py` proves independent per-camera state and a camera-B fall while camera A is busy. `benchmarks/alert_latency_2026-08-07.md` measured 12 synthetic 480p streams at **15.2 FPS minimum per room** on this laptop; claim the stated limit, not unlimited rooms. |
| "Response time tracked and logged for compliance" | ✅ TRUE | `avg_ack_seconds` view (`...incident_rpc_and_views.sql:122`), surfaced in `meridian_insights/lib/queries/analytics.ts`. |
| "Eliminates 'detection depends on random chance'" | ✅ TRUE | Continuous per-frame inference, not scheduled rounds. |

### MeridianFamily

| Claim | Verdict | Evidence |
|---|---|---|
| "Daily summaries showing resident activity and wellbeing" | ✅ TRUE for activity (built) / ❌ FALSE for meals | Activity is now real: `20260807000200_resident_activity_rollup.sql` + Hub-local aggregation deliver day/night movement **patterns compared to the resident's own baseline** ("lower than usual"), with `insufficient_observation` when the resident was simply out of view — a sparse day is never reported as a low-activity day. The family receives categories only: no counts, coordinates, camera or room IDs, and no daily trace (enforced by test). **Meals remain unbuildable and were deliberately refused** — see `docs/resident-activity-rollup.md`. The mock's "✓ Breakfast" must come off the slide. |
| "Instant emergency notifications with resolution status" | ✅ TRUE | `notifications` table + `notify-family` Edge Function; resolution status flows through `family_incident_feed`. |
| "Verified visibility into what's actually happening" | ✅ TRUE | RLS-scoped `family_incident_feed` / `family_visitor_feed`. |

### MeridianHub

| Claim | Verdict | Evidence |
|---|---|---|
| "Immediate help dispatch when falls detected" | ✅ TRUE (built) | An idempotent trigger on `incident_events` turns a `fall_confirmed` row into exactly one `auto_fall_dispatch` assistance request, so the resident sees help coming without pressing anything. `supabase/migrations/20260807000000_meridian_hub_resident_surface.sql`. |
| "Independent assistance requests for seniors" | ✅ TRUE (built) | `assistance_requests` + security-definer RPC; facility/resident/room come from the authenticated device mapping, never a browser parameter. UI in `meridian_hub_ui/`. |
| "Visitor verification capability for seniors" | ✅ TRUE (built) | `visitor_verification_prompts`: an unrecognized visitor prompts the resident, a denial escalates to the care team, and an unanswered prompt expires after two minutes rather than hanging. |
| "Help is coming — ETA 60 seconds" (mock) | 🟡 PARTIAL (built, honestly) | There is now a real ETA — `estimate_assistance_eta` derives it from the facility's 30-day acknowledgement history and returns a confidence (`data_derived` / `limited_history` / `facility_default`). **It is not 60 seconds**, and it should not be presented as a fixed number. Update the mock to show a derived estimate. |

**This was the single largest gap in the deck — an entire claimed product
surface did not exist — and it has now been built.** See `docs/meridian-hub.md`
for the auth/RLS model and for what still cannot be verified without a live
Supabase project (no Docker/CLI/psql/Deno on this machine, so migrations,
policies and triggers are statically verified, not executed).

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
| "frames … discarded, never written to disk, never uploaded" | ✅ TRUE | `test_process_frame_cannot_write_image_or_open_network_connection` intercepts write-mode `open`, `cv2.imwrite`, and socket connects while running `HubDaemon.process_frame`; `test_process_frame_does_not_retain_raw_pixel_array` checks the input array can be collected after return. |
| "Fall detection and validation are fully local — no third-party AI service ever sees a resident" | ✅ TRUE, with a footnote | The daemon path test blocks network connections during `process_frame`, and `test_daemon_dependency_graph_excludes_third_party_visitor_photo_describer` prevents it depending on `face/body_description.py`. That visitor-only tool path can call Hack Club → Gemini only from `tools/smoke_test_full_integration.py`. |
| "If the internet drops, detection keeps running and alerts queue locally" | ✅ TRUE | `test_offline_event_survives_restart_then_delivers_exactly_once` simulates an outage, closes/reopens the SQLite database, then verifies one eventual 202 delivery and no duplicate drain. |
| "Face data encrypted AES-256-GCM on the Hub; the key never leaves the building" | ✅ TRUE | `test_encrypted_outbound_observation_has_no_key_or_plaintext_embedding` serializes the actual observation payload and rejects plaintext vector markers and key material; it requires AES-256-GCM ciphertext. |
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
| "MeridianFamily delivers daily summaries **and emergency SMS** to families" | 🟡 PARTIAL (built; live delivery unverified) | Emergency SMS is now a consent-gated escalation only: an active family SMS opt-in and resident `family_visibility` consent are required, the incident must remain critical/unacknowledged for the facility-configurable five-minute default, and rate/idempotency/delivery audit records are enforced in the additive SMS migration. `notify-family` calls Twilio only for claimed escalations; normal app notifications remain push-first. This machine could not deploy or test Twilio/Supabase live, so do not call delivery demonstrated until the deployment checklist in `docs/family-sms-escalation.md` passes. |
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

## Summary — what was built, and what is now known

| # | Gap | Slides | Outcome |
|---|---|---|---|
| 1 | MeridianHub resident product did not exist | 3, 8 | **Built.** Assistance requests, auto-dispatch on confirmed fall, resident visitor verification, device-scoped RLS, accessible UI. |
| 2 | Emergency SMS removed but still claimed | 8 | **Built** as a consent-gated escalation. Live delivery still unverified — do not say "SMS" on stage yet. |
| 3 | "Under 5 seconds" never measured | 3 | **Measured.** 2.027s / 3.200s p95 Hub-to-ingest. Under budget, but **not** end-to-end — the stronger "to staff" wording stays unproven. |
| 4 | "Activity and wellbeing" had no data source | 3 | **Activity built** against the resident's own baseline. **Meals refused** — must come off the mock. |
| 5 | Privacy claims true but unproven | 6 | **Now enforced by construction**, and mutation-tested. |
| 6 | Multi-camera simultaneity untested | 3 | **Verified and bounded**: 12 rooms at ≥15.2 FPS on this laptop. |

### On the strength of this evidence

Not all green checks are equally strong, and the difference matters more than
the count:

- **Strongest — mutation-tested guards.** Three guards were verified by
  deliberately introducing the violation they exist to catch (a frame written to
  disk, face ciphertext joined into a resident view, an SQL gate removed from the
  SMS escalation). Each failed as designed. These claims are true *by
  construction*: a future refactor that breaks them breaks the build.
- **Strong — measured numbers.** The latency and multi-camera figures were
  produced on this machine and are reproducible from the commands in
  `benchmarks/alert_latency_2026-08-07.md`. Their stated limits are part of the
  claim, not a footnote.
- **Weaker — statically verified SQL.** This machine has no Docker, supabase
  CLI, psql or Deno, so **no migration, RLS policy, trigger or Edge Function in
  this work has ever been executed.** They are parsed, AST-asserted, and
  reviewed. The SMS decision matrix is tested against a Python *model* of the
  SQL, with a drift guard pinning the model's gates to the function body — but a
  model is not the database.
- **Weakest — uncompiled Swift.** No Mac, so `meridian_care` and
  `meridian_family` changes have not been compiled, let alone run.

**Before the pitch, the highest-value verification left is deploying the three
new migrations to a live Supabase project and exercising the RLS policies with
distinct JWTs.** That is where a real defect is most likely to still be hiding.

Items that cannot be fixed by building — and must be fixed by **editing the
deck** — are in `docs/deck-corrections.md`.
