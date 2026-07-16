# Meridian — Live Demo Plan & Runbook

Status: v1 | For: YBVC pitch (and any live pilot/investor demo) | Owner: whole team

This is the on-stage runbook. It is built around what is **actually working and tested today**, not aspirations. Every command here has been run. Read the "Reality check" box before planning the choreography — it lists what's live vs. what still needs a Mac / live cloud.

---

## 0. Reality check (what's live today, what isn't)

| Piece | State | Runs where |
|---|---|---|
| Fall detection (pose → state machine → event) | ✅ Live, tested (50/50 staged falls, re-armable) | Windows laptop (RTX 5060), ~137 fps |
| Live skeleton view ("the privacy moment") | ✅ Live, tested end-to-end over WebSocket | Laptop Hub → browser page |
| Visitor detection + encrypted face/embedding storage | ✅ Live, tested (real InsightFace, AES-256-GCM) | Laptop Hub |
| AI visitor body-description (clothing/appearance) | ⚠️ Works, but **degrades gracefully** if the Hack Club key is out of quota (currently returning HTTP 402 — top up before demo or run without it) | Laptop Hub → Hack Club API |
| App-notification delivery (Hub → backend → app push) | ✅ Hub side live + offline-first queued delivery | Laptop Hub → backend |
| Insights web dashboard (floor view, incidents, analytics, skeleton page) | ✅ Builds clean, all 9 routes | Laptop, `next` server |
| Meridian Care / Family iOS apps | ⚠️ SwiftUI, **need a Mac + Xcode + real iPhone** to run (MVP screenshots exist) | Dhairya's Mac / iPhone |
| Live Supabase cloud round-trip (Hub → Supabase → real iOS push) | ⚠️ Backend built; live project DNS/auth was flaky from the dev machine — **rehearse it, but do not make the demo depend on it** | Cloud |

**The golden rule:** the visible demo (skeleton + fall banner + on-screen alert) runs **entirely on one laptop with a camera and never needs the network.** Everything cloud/phone is a bonus layer on top. Build the choreography so a dead network or an unbuilt app is invisible to the audience.

---

## 1. What the demo proves (the story arc)

Mapped to PRD section 26's five beats. The demo has to make one point land hard: **Meridian sees the fall and gets help moving before anyone walks by — and it does it without ever showing a person's body on a screen.**

1. **The gap** — a resident falls at 2 AM; discovery today waits for the next scheduled round.
2. **The catch** *(the hero beat)* — stage a fall; the **skeleton** (not video) shows Meridian watching; within seconds a **fall-confirmed alert** fires with resident-first copy ("Maggie may have fallen in room-12").
3. **Privacy & permissions** — the screen shows a skeleton, never raw video; families see events, not live feeds; each role sees only what it's authorized to.
4. **Feature breadth** — fall + long-lie + dementia zone/exit + visitor detection + mobility trends, all one platform.
5. **The business** — per-room SaaS + family attach, the market clock, the pilot ask.

---

## 2. Roles on the day

| Person | Owns during the demo |
|---|---|
| **Pranav** | The Hub laptop + camera. Starts `run_live_demo.py`, stages/triggers the fall, watches the terminal banner, owns the technical fallback if anything hiccups. |
| **Dhairya** | The screens: Insights dashboard + the Care/Family app (on an iPhone if Mac-built, else the recorded screen-capture fallback). Narrates the app-side "the caregiver just got the alert." |
| **Megan** | Presenter/narrator + timing + demo choreography. Runs the deck, drives the story beats, calls the fall cue, keeps to <2:50. |

Everyone should be able to run the Hub laptop steps in a pinch — single point of failure is the enemy.

---

## 3. Equipment checklist (pack this)

- [ ] **Hub laptop** (the Windows machine — RTX 5060), charged + charger
- [ ] **Camera**: the laptop webcam is enough; a USB webcam on a small tripod is better (frames the "fall" cleanly)
- [ ] **A soft surface / mat** to actually fall onto, or a chair to slump from — rehearse the exact motion the model reliably fires on
- [ ] **Second screen / projector adapter** (HDMI + USB-C dongles) — one screen for the skeleton, one for the deck/dashboard
- [ ] **iPhone** with Meridian Care installed (if Mac-built) — else a screen-recording of the app receiving an alert
- [ ] **Phone hotspot** as network backup (do NOT rely on venue WiFi)
- [ ] **Pre-recorded staged-fall clip** on the laptop (see §7 — the single most important fallback)
- [ ] A printed copy of this runbook + the go/no-go checklist (§8)

---

## 4. Startup runbook (do this 15 min before, in this order)

All commands run from the repo root `C:\Users\emmad\Documents\meridian`.

**Step 1 — one-time per machine (already done on the dev laptop):**
```
python -m pip install -e ".[dev]"
# pose model present at models/yolo11s-pose-480x640.onnx
# (if missing: python tools/export_pose_model.py)
```

**Step 2 — start the Insights dashboard (Terminal A):**
```
cd meridian_insights
npm install      # first time only
npm run build && npm start     # serves on http://localhost:3000
```
Open **http://localhost:3000/demo/skeleton** on the screen the audience will see. It will say "waiting for relay" until Step 3.

**Step 3 — start the Hub + live demo (Terminal B):**
```
python tools/run_live_demo.py --source 0 --resident Maggie --room room-12
```
- `--source 0` = laptop webcam. Use `--source path/to/staged_fall.mp4 --loop` to run the rehearsed clip instead.
- You'll see: `Pose model ready on: directml` → `Skeleton relay live` → `Running. Stage a fall...`
- The moment a person is in frame: `Person detected -- skeleton is now streaming`. The `/demo/skeleton` page fills with a live skeleton. **This is the beat that wins the room — confirm it before going live.**

**Step 4 — (optional, if doing the full cloud path) point delivery at the real backend:**
```
python tools/run_live_demo.py --source 0 --backend-url https://<your-app>/ingest-event
```
If the backend is down, the event stays safely queued and the on-screen banner still fires — the audience sees no difference.

---

## 5. Run of show (target < 2:50)

| Time | Who | On screen | Says / does |
|---|---|---|---|
| 0:00–0:25 | Megan | Deck: the empty hallway | The gap — "When Maggie falls at 2 AM, who notices, and when?" |
| 0:25–0:35 | Megan → Pranav | Switch to the **skeleton page** | "Watch what Meridian sees." Pranav confirms skeleton is live. |
| 0:35–1:05 | Pranav | Skeleton page (live) | **Stage the fall.** Skeleton drops. Terminal banner: `FALL CONFIRMED — Maggie may have fallen in room-12`. Say the timing out loud: "That's under five seconds." |
| 1:05–1:25 | Dhairya | iPhone / app screen-cap | "And here's the caregiver's phone — the alert's already there, one tap to acknowledge." |
| 1:25–1:45 | Megan | Skeleton page again | Privacy: "Notice — that was a skeleton the whole time. We never put a person's body on a screen. Families see events, never a live feed." |
| 1:45–2:10 | Dhairya | Insights dashboard | Breadth: floor view, incident log, response-time analytics, visitor log — "one platform, not a camera." |
| 2:10–2:50 | Megan | Deck: business slide | Per-room math, the $56.8B clock, the pilot ask. Close on the tagline: "A helping hand you don't have to ask for." |

**Do it twice if asked.** The fall detector is now re-armable (verified) — Pranav can get up and fall again and it fires cleanly a second time. Judges love "do it again"; you can say yes.

---

## 6. Contingency matrix (rehearse each recovery)

| If this fails… | You'll see… | Recovery (rehearsed) |
|---|---|---|
| Live fall doesn't trigger | No banner within ~5s | Say "let me show the rehearsed capture" → switch Terminal B to `--source staged_fall.mp4 --loop`. Never re-fall repeatedly on stage hoping — cut to the clip. |
| Skeleton page blank | "waiting for relay" persists | Confirm Terminal B shows "relay live"; refresh the browser tab; check the page URL is `/demo/skeleton` and relay port is 8765. |
| Camera won't open | `Could not open source` | Try `--source 1` (external cam) or fall straight to the pre-recorded clip. |
| Network / venue WiFi dead | Backend delivery fails | **Nothing visible breaks** — the banner + skeleton are local. Mention offline-first as a feature: "notice it kept working with no internet — that's by design." |
| iOS app not available | No phone to show | Use the screen-recording of the app receiving an alert (record this in advance). |
| Hack Club vision 402 / down | No AI clothing description | Visitor detection still works; just don't feature the AI sentence. It degrades silently. |
| Whole laptop wedges | Frozen | Have the 60-second screen-recording of a full successful run as the absolute last resort. |

---

## 7. The single most important prep task: record a staged-fall clip

A live fall can miss (lighting, angle, the model's a nano model). **Film a clean staged-fall clip during rehearsal that you have personally confirmed triggers `FALL CONFIRMED`**, and carry it. This is both the demo fallback and, per PRD §13/§28, the start of the 100+ staged-event validation set that produces the precision number for the pitch.

```
# record while running the demo, or use any phone; then verify it fires:
python tools/run_live_demo.py --source staged_fall.mp4
# you MUST see the red FALL CONFIRMED banner. If not, re-film with a
# faster, more vertical drop and more floor-time, or tune
# meridian_hub/classifiers/thresholds.py against the clip.
```

---

## 8. Go / No-Go pre-flight (run on stage, before you start talking)

Tick all before beat 1:
- [ ] Terminal A: dashboard at `localhost:3000` loads (floor view renders)
- [ ] Terminal B: `run_live_demo.py` printed `Pose model ready on: directml` and `Skeleton relay live`
- [ ] `/demo/skeleton` page shows a live skeleton when you step in front of the camera
- [ ] Staged-fall in rehearsal produced the red `FALL CONFIRMED` banner **at least once in the last 30 min**
- [ ] Rehearsed-clip fallback is one command away and confirmed working
- [ ] Phone hotspot on; screen-recording fallback file located and openable
- [ ] Deck cued to slide 1

If any of the first four are red → open with the rehearsed clip (`--source staged_fall.mp4 --loop`) instead of a live fall. A clip that always works beats a live fall that might not.

---

## 9. Rehearsal plan (PRD §27 calls for 10+ run-throughs)

1. **Solo tech rehearsal** (Pranav): 10× staged falls against the webcam, confirm the banner fires every time and the re-arm works (fall, get up, fall again). Note the exact body motion that's most reliable.
2. **Full-team run-throughs**: 10×, timed, hitting < 2:50, each person on their station. Practice the hand-offs (Megan's "watch what Meridian sees" → Pranav's fall → Dhairya's phone).
3. **Failure drills**: at least 3 rehearsals where someone deliberately kills the WiFi / unplugs the camera mid-run so the recovery is muscle memory, not panic.
4. **Q&A murder board** (PRD §12.5): rehearse the judge questions — "why won't SafelyYou crush you," "consent for dementia residents," "what if it misses a fall," "three high schoolers?" — answers are in the PRD.

---

## 10. One-paragraph "if you only read one thing"

Open the dashboard (`npm start` in `meridian_insights`, go to `/demo/skeleton`). Run `python tools/run_live_demo.py --source 0`. Confirm a skeleton appears when you step in front of the camera. Stage a fall — the red `FALL CONFIRMED` banner fires in under 5 seconds and the skeleton is the only thing that was ever on screen. That's the whole demo, and it runs on one laptop with no network. Everything else (the phone alert, the cloud, the analytics) is a bonus layer you show if it's green and skip if it's not. Carry a pre-recorded staged-fall clip as your fallback and you cannot lose the room.
