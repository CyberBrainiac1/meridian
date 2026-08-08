# 30-second product demo video — production plan

Runs **alongside** the pitch deck, not instead of it. The deck carries the
claims; this video carries the proof that the product exists and works.

Three rules, in priority order:

1. **No numbers.** No latency, no room counts, no percentages, no ARR, no ETA
   digits. Every metric lives on a slide where it can be sourced and defended.
   The video's only job is "this is real, watch it work."
2. **Product surfaces only.** Real screens, real interactions. No explainer
   graphics, no architecture diagrams, no talking head.
3. **Every human on screen is stock footage.** No team members, no residents,
   no staged falls performed by anyone we know.

**No camera required.** Everything below can be filmed today, before the
XIAO ESP32S3 Sense arrives.

---

## 0. How the skeleton beat works without hardware

`tools/run_live_demo.py --source <path-to-video.mp4>` accepts a **file**, not
just a webcam index. So:

```
stock fall clip  ->  real YOLO11 pose  ->  real fall state machine  ->  real skeleton
```

The skeleton on screen is genuinely produced by our detector, from stock footage
of a person we have never met. Nobody is filmed, nothing is simulated, and the
privacy claim is literally true on screen: the raw frame is discarded, only the
17-point pose survives.

```powershell
python tools/seed_demo_data.py
python tools/run_live_demo.py --source assets/video/stock-fall.mp4 --loop
# then screen-record meridian_insights -> /demo/skeleton
```

If the stock clip does not trip the fall thresholds — likely, since stock falls
are often partial or off-frame — **do not hand-animate a skeleton.** Re-cut the
clip, try another, or drop the beat. A fabricated skeleton in a video about a
real detector is the one lie that would actually be fatal if spotted.

---

## 1. Shot list (30 seconds)

| # | Time | Shot | Source |
|---|---|---|---|
| 1 | 0:00–0:04 | Older adult on the floor of a dim room, alone | Stock |
| 2 | 0:04–0:09 | **Hero.** Same frame dissolves from video to skeleton-only | **Real** — `/demo/skeleton` |
| 3 | 0:09–0:13 | Caregiver phone: alert arrives, tap, Acknowledge → Responding | Remotion, from `assets/pitch-deck/` |
| 4 | 0:13–0:18 | Resident's Hub: help is on the way | **Real** — `meridian_hub_ui` |
| 5 | 0:18–0:22 | Resident's Hub: *"Is this person expected?"* | **Real** — `meridian_hub_ui` |
| 6 | 0:22–0:27 | Family phone: notification, then resolved | Remotion |
| 7 | 0:27–0:30 | Logo + `Faster help. Less uncertainty. More dignity.` | Remotion |

**Beat 2 is the whole video.** Five seconds, the longest slice. It is the only
thing here no competitor can show, and it converts "creepy camera" into
"privacy architecture" without a word of narration. Everything else is
supporting evidence.

**Beat 5 earns its place.** Resident-facing visitor verification is the surface
slide 3 claimed and the codebase did not have until recently. It is also the
clearest single answer to "how is this different from a fall camera?" — the
resident *acts*, they are not merely watched.

Captions: keep to beat 7 only, or none at all. The deck is on screen next to
this; the video does not need to argue.

---

## 2. What is recorded live vs animated

**Screen-record for real** — these run on this machine today:

| Surface | Route | Beat |
|---|---|---|
| `meridian_insights` | `/demo/skeleton` | 2 |
| `meridian_hub_ui` | help request + status | 4 |
| `meridian_hub_ui` | visitor verification prompt | 5 |

Run `python tools/seed_demo_data.py` first so every surface shows a populated
facility instead of empty states. It is idempotent — safe to re-run between
takes.

**Animate in Remotion** — SwiftUI cannot run here (no Mac):

- MeridianCare caregiver app — beat 3
- MeridianFamily app — beat 6

Stills are in `assets/pitch-deck/`. Animating real screenshots is honest: the
audit confirmed they match the shipped code exactly, including the five status
transitions and the tab bar. Do not invent screens the app does not have.

**Skip `/analytics`.** It is a real page and it looks good, but it is wall-to-wall
numbers. Wrong surface for this video.

---

## 3. Tooling

**Remotion** for assembly. It is React, which this team already writes;
"automated app movements" are interpolations rather than hand-keyframed motion;
and a copy change is a re-render, not a re-edit. A `remotion-best-practices`
skill is available in this environment.

Screen captures and stock clips both drop in as `<OffthreadVideo>`. Render 1080p30
MP4.

Fallback if Remotion stalls: DaVinci Resolve (free), same shot list.

---

## 4. Stock sourcing

Free, no attribution: **Pexels**, **Pixabay**, **Mixkit**.
Paid if needed: Adobe Stock, Storyblocks.

Terms that actually return usable material: `senior living`, `nursing home
hallway night`, `elderly woman alone room`, `caregiver nurse phone`, `adult
daughter phone worried`.

**Beat 1 is the long pole.** Clean stock footage of an older adult falling
barely exists, and most of what does is insurance-ad melodrama. Two better
approaches:

1. **Aftermath, not impact** — open with the person already on the floor. More
   tasteful, matches the deck's tone, and far easier to source.
2. **Off-frame** — feet or a shadow, then cut straight to the skeleton.

Start sourcing before anything else. Every other beat can be filmed in an hour;
this one can hold up the edit for days.

---

## 5. Do not show

"No numbers" removes most of the risk, but three product-surface claims can
still put something false on screen. Sources: `deck-claim-audit.md`,
`deck-corrections.md`.

| Do not show | Why |
|---|---|
| A literal ETA number on the Hub | ETA is derived from acknowledgement history with a confidence level, not a fixed value. Check what `etaCopy` renders before recording; capture a qualitative state. |
| `✓ Breakfast` in the family summary | Meals have no data source and were deliberately refused — a room pose cannot see a meal. Show visitor and activity signals, which are real. |
| An SMS thread | SMS is built as a consent-gated escalation but live delivery is unverified. Show the in-app notification, which is real today. |

---

## 6. Order of work

1. **Source stock clips** — start here, it is the only step with unbounded time
2. `python tools/seed_demo_data.py`
3. Record `/demo/skeleton`, driven by the stock clip (beat 2)
4. Record `meridian_hub_ui` — help status, then visitor prompt (beats 4–5)
5. Build the Remotion comp: beats 1, 3, 6, 7 — then drop in the three captures
6. Render, watch once against §5, ship

Steps 2–5 need only this repo and this laptop. Step 1 can run in parallel
starting now.
