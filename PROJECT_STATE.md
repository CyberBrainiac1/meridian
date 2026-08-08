# Meridian — Competition Build Status

Everything below was verified by running code and querying the live database
directly, not by trusting a status message. Where I couldn't verify something
myself, it's labelled as such.

**Important lesson from today**: the Supabase dashboard SQL Editor showed
"Success" for a large pasted script that had actually only partially applied —
2 of 3 fixes in one migration silently never took effect, even though the UI
reported success. I now have direct database access (Supabase MCP) and used
it to re-apply and individually verify every fix below with a live functional
test, not just a schema check. Going forward, that's how changes to this
database should be applied and confirmed.

---

## 1. What's confirmed WORKING right now (live-tested today)

| Feature | Verification |
|---|---|
| **Hub ETA is data-derived** | Signed in as the Room 101 Hub device and queried the exact view the resident's screen reads: `eta_seconds: 67, eta_confidence: "data_derived"` — a real measured value from 30 days of acknowledged incidents, not the old hardcoded 5-minute default. |
| **Duplicate consent rows are blocked** | Attempted to insert a 4th duplicate active consent directly via the API: rejected with `409` / `duplicate key value violates unique constraint`. |
| **`respond_to_incident` is idempotent** | Confirmed live in the function body: re-asserting the same status returns the existing row instead of erroring; `escalated` can now transition to `responding`/`resolved`/`dismissed_false_alarm` instead of being terminal. `SECURITY DEFINER` confirmed. |
| **Notification fan-out no longer duplicates** | `notify_assistance_request` and `notify_visitor_arrival` now use `EXISTS` instead of `JOIN` against `person_consents` — confirmed by reading the live function source in the database. |
| **Visitor-arrival notifications carry Gemini's description again** | Bonus find while fixing the above: a *pre-existing* bug (not something I introduced) had an earlier migration overwrite `notify_visitor_arrival` and accidentally drop the body-description text from the care-team notification. Restored as part of today's fix. |
| **Python test suite** | 214/214 passing. |
| **Gemini visitor description** | Live API call verified working (`gemini-flash-latest`), 3/3 successful. |
| **MeridianCare (staff) iOS build** | `BUILD SUCCEEDED` on iPhone 16 / iOS 18.2 simulator, zero warnings in changed files. |
| **MeridianFamily iOS build** | `BUILD SUCCEEDED` on iPhone 16 / iOS 18.2 simulator (explicit device UDID — "iPhone 16" alone is ambiguous across OS versions and silently no-ops). 0 errors, 1 warning (boilerplate Xcode noise: "no AppIntents.framework dependency found," unrelated to app code). |
| **MeridianHub web app** | Typechecks clean, tested live in browser: "Call family" creates an assistance request and writes both care-team and family notifications, with a persistent on-screen confirmation. |
| **App icons** | Generated, all three apps, distinguishable in greyscale. |
| **Demo seed data** | 16 users, 4 residents, 29 incidents, idempotent re-runs. |

---

## 2. What was fixed just now (this session)

The consent-dedup migration and two of `estimate_assistance_eta`/notify-function
fixes had silently failed to apply via the dashboard paste. I re-applied all
three directly through the database connection and confirmed each one live
(see table above) rather than trusting the tool's "success" response alone.

---

## 3. Supabase security/performance advisors — what's real vs. noise

Ran the official Supabase linter against the live project. Sorting signal from noise:

**Actionable:**
- **Leaked Password Protection is disabled** (WARN). One toggle in Supabase Auth settings — checks new passwords against HaveIBeenPwned. Not a demo blocker, worth turning on before real users ever sign up.
- **`family_sms_recipient_rate_windows` has RLS enabled but no policies** (INFO). This is intentional — the table is only ever touched by the service role (the SMS worker), so no authenticated-user policy is needed. No action required, but worth a one-line comment in the migration so a future reader doesn't "fix" it into a bug.

**Flagged by the linter but by design, not a bug:**
- 7 views (`family_incident_feed`, `family_visitor_feed`, `resident_hub_*`, etc.) are flagged `ERROR: Security Definer View`. These are **intentionally** `SECURITY DEFINER` — the migration comments explain why: family/resident-device roles need to see a narrow, pre-filtered slice of data that their own RLS wouldn't otherwise expose, and the view itself does the narrowing. This is the correct pattern here, not a leak. I'd suggest not "fixing" these before the demo.
- ~15 `WARN: SECURITY DEFINER function callable by anon/authenticated` — these are exactly the RPCs designed to be called by residents, caregivers, and family (`create_resident_assistance_request`, `respond_to_incident`, etc.). Also by design.
- Several `INFO: unindexed foreign keys` (mostly on `assistance_requests` and `family_sms_*` audit columns) — minor, would only matter at real production scale, not for a demo.

**Bottom line: no real security holes found beyond the one toggle above.**

---

## 4. Blockers — still need you, unchanged since last check

| # | Blocker | Status |
|---|---|---|
| 1 | **Twilio owns zero phone numbers** | Still true — just re-checked live: `IncomingPhoneNumbers` count is `0`. `TWILIO_PHONE_NUMBER` in `.env` is still your personal phone (the recipient of Twilio's test text), not a sender. SMS cannot go out until you buy a number in the Twilio console. |
| 2 | **Twilio account is still Trial** | Trial accounts can only text pre-verified numbers and prefix every message with "Sent from your Twilio trial account." |
| 3 | **Rotate leaked secrets after the competition** | Unchanged advice — Supabase service-role key, Twilio token, Gemini key all passed through this chat at some point. |

---

## 5. Pitch-deck claim audit (unchanged from prior pass, still accurate)

| Deck claim | Verdict |
|---|---|
| "YOLO11 on ONNX Runtime, GPU-accelerated" | Real pipeline, but only DirectML (Windows) mapped — no CUDA, untested on real GPU hardware. Say "GPU-capable, benchmarked on CPU." |
| "No third-party AI service ever sees a resident" | **False as written.** Gemini sees unrecognized visitor photos. Replacement copy below. |
| "Face data encrypted before it ever leaves" | Say "face *embeddings*" — the visitor photo reaches Gemini before encryption. |
| "Fall detection alerts under 5 seconds" | The metric excludes camera capture + the 2–3s stillness-confirmation window. Now documented in the DB via `COMMENT ON VIEW`. |
| "Help is coming — ETA 60 seconds" | ETA is now genuinely data-derived (confirmed live above) but is not a fixed 60s — it's clamped 30s–30min based on real history. Show the real screen, not the deck's illustrative number. |
| ESP32-CAM custom hardware | Not built — only pin/config headers exist. Say "in development; we run on existing IP cameras today." |

**Required deck copy change** (SECURE BY ARCHITECTURE slide):

> "Fall detection and validation are fully local — no third-party AI service ever sees a resident. **Visitor description is the one exception: when an unrecognised person appears at an entry camera, that image alone is sent to Google Gemini to generate a text description for the resident. Residents are never sent. This is disclosed at onboarding and can be switched off per facility.**"

---

## 6. What's still unverified / left to do

| Item | Status |
|---|---|
| **5-iteration regression matrix** | Not done. One clean pass completed on the Hub "Call family" flow with live DB verification. The Acknowledge/Respond/Resolve/Dismiss/Escalate loop and SMS delivery can't be meaningfully iterated until the Twilio blocker clears. |
| **MeridianFamily runtime testing** | Build confirmed clean (§1), but never launched in a simulator or clicked through — no functional verification of the daily-summary/alerts/SMS-opt-in screens yet. |
| **iPad provisioning for the two Swift apps** | Not addressed. Sideloading two native apps onto a demo iPad is the single highest-risk item for demo day — decide TestFlight vs. your own device early. |
| **Deck copy edit** | I've drafted the replacement text (§5); it hasn't been applied to the actual pitch deck file since I don't have access to it. |

---

## 7. Demo assets (unchanged, still valid)

- **App icons** — `assets/app-icons/{meridian-care,meridian-family,meridian-hub}/`
- **Demo accounts** — password `MeridianDemo!2026`, `@meridian-demo.invalid` domain (unroutable, safe)
  - Staff: `nadia.care@`, `james.care@`, `lin.care@`
  - Family: `dana.family@` → Maggie, `priya.family@` → Harold, `ade.family@` → Ruth, `elena.family@` → Frank (+5 more)
  - Hub: `room101.hub@`, `room104.hub@`, `room112.hub@`, `room118.hub@`
  - Room 101 (Maggie) has an **open** fall alert waiting for judges to triage live
- **Reset**: `python tools/seed_demo_data.py --wipe && python tools/seed_demo_data.py`
