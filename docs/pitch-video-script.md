# Pitch video — final production script (29.0s, 870 frames @ 30fps)

This is the authoritative cut. Every frame is assigned. It supersedes the
timing tables in `pitch-video-plan.md`; the honesty rules there (§5 "Do not
show") still bind. Implementation lives in `video/src/Composition.tsx`,
rendered by `cd video && npm run render` to `video/out/meridian-demo.mp4`.

Global rules:

- **1920×1080, 30fps, 870 frames, no audio track** (scored/voiced live on stage).
- **No numbers on screen** except "Room 101" (a name, not a metric).
- Persistent brand mark top-right on every beat (mint on dark, brand blue on
  light), fading 826→840 so it never coexists with the end card.
- Type: system UI stack already in the comp. Headline size 66–76, sub 30–40.
- **App-name hierarchy (user direction):** in every headline block the app
  name — MeridianCare / MeridianHub / MeridianFamily — is the dominant
  element: ~42px, weight 850–900, near-black `#08131B`. The name outranks the
  tagline because the app name is what the audience must retain.
- Palette: the `C` constants in the comp (brand blue `#0369A1`, mint
  `#22FFC2`, dark `#05060A`, deck navy `#0B111B`).
- Every app screen mirrors shipped code (`hub-surface.tsx`, AlertFeedView,
  UpdatesView). Copy is quoted below and must not be paraphrased.

Source-clip facts the timing depends on: `fall.mp4`/`skeleton.mp4` are 291
frames (211 live + 80 held), H.264 CFR. In clip-time the fall impact is at
frame ≈143 and she is settled on the floor by ≈150. Both beats below use
`startFrom={58}`, which puts impact at beat-frame ≈85.

---

## Beat 1 — Fall + skeleton lock-on — frames 0–165 (5.5s)

**Purpose:** the only thing no competitor can show: live pose extraction, and
video that never leaves the building. Compressed per direction — the fallen
hold is now ~1.5s, not 4.

| Frames | What happens |
|---|---|
| 0–12 | Fade in from black (12f). fall.mp4 playing, `startFrom={58}`: she is already mid-room, walking. Grade: brightness .56, saturate .72, contrast 1.08. Slow push-in: scale 1.02→1.10 across the whole beat, one shared ramp for BOTH layers. |
| 18–48 | Skeleton layer (screen blend) fades 0→1 over 30f. She is upright and walking: the audience watches tracking lock on *before* anything goes wrong. |
| ≈85 | Impact (clip frame ≈143). No cut, no speed ramp — the fall plays raw with the skeleton riding it. |
| 100–132 | Footage brightness .56→.05 over 32f. The room disappears; the mint skeleton alone remains on near-black. |
| 96–120 | Caption slides up 14px + fades in, lower-left, mint keyline bar: **"No video ever leaves the building."** |
| 150–165 | Caption holds. Skeleton holds on the floor pose. |

**Transition out (163–170):** 7-frame luminance dip — skeleton and caption fade
to pure `#05060A`, then Beat 2's light surface fades straight in. Dark→light is
the visual cut from "the incident" to "the response"; it should feel like a
breath, not a slide.

## Beat 2 — MeridianCare: alert → acknowledge → responding — frames 165–345 (6.0s)

**Purpose:** the caregiver workflow, the deck's core loop: alert, one-tap
acknowledge, responding — with the shift-handoff surface implied by the tab bar.

Layout: left headline block + right phone device (as built). Headline:
**MeridianCare / "Care, in sync." / "One clear alert. One clear response."**

| Frames (local 0–180) | Phone action |
|---|---|
| 0–14 | Screen fades in; phone slides up 24px settling with the standard ease. |
| 8–22 | Alert card drops in from -80px: red keyline, **Emergency** pill, alert SVG icon. Title: **"Maggie may need help in Room 101."** Sub: **"Fall detected"**. |
| 55–72 | Tap ripple expands on **Acknowledge** (92px ring, 17f). Button swaps to **Acknowledged** amber pill at 72. |
| 96–112 | **Mark responding** pressed (same ripple, 16f); pill flips to green **Responding** at 112. |
| 118–140 | Screen translates up 145px; **RESPONSE / "Care team is responding."** panel fades in below. |
| 140–180 | Hold. Nothing moves for the last 1.3s — presenter talking room. |

**Transition out (340–350):** 10-frame cross-dissolve, both beats share the
same light background family so the dissolve reads as one product, new screen.

## Beat 3 — MeridianHub: help is coming — frames 345–495 (5.0s)

**Purpose:** the resident is a participant, not a subject. This is the surface
the deck claimed and the repo now ships.

Headline: **MeridianHub / "Help is on the way." / "The resident sees every step
clearly."** Right side: tablet-proportioned device (as built).

| Frames (local 0–150) | Screen action |
|---|---|
| 0–12 | Fade in. Header: **"Hello, Maggie"** / **"Choose what you need. Your care team is here to help."** |
| 10–26 | HELP STATUS panel (green keyline, check-circle SVG) scales 0.97→1: **"Help is coming. A caregiver is on the way."** |
| 26–68 | Three progress rows stagger in, 14f apart: **"Your request was sent" / "A caregiver has seen it" / "A caregiver is on the way"** — each row: dot pops (scale 0→1.15→1) then label fades. |
| 80–95 | **Emergency help** pill (red, alert SVG) fades in beneath. |
| 95–150 | Hold ~1.8s. |

**No ETA digits anywhere** — the shipped surface derives ETA with a confidence
label, and the video must not invent "60 seconds".

**Transition out (490–500):** same-device content swap — the panel slides left
40px and fades as the visitor panel slides in from right 40px. Reads as the Hub
changing screens, because it is.

## Beat 4 — MeridianHub: visitor check — frames 495–660 (5.5s)

**Purpose:** the sharpest differentiator ("the resident acts"): unknown visitor
at the entrance, resident decides.

Headline: **MeridianHub / "Your voice matters." / "A calm choice for an
unexpected visitor."**

| Frames (local 0–165) | Screen action |
|---|---|
| 0–14 | VISITOR CHECK panel (blue keyline, person SVG) enters per transition above. **"Is this person expected?"** / **"Someone we do not recognise was seen at the entrance."** ("recognise" is the shipped spelling — keep it.) |
| 20–34 | Two buttons rise 12px + fade in: green **"Yes, expected"**, red **"No, get help"** (alert SVG). |
| 76–92 | Ripple on **"Yes, expected"**; button brightens. |
| 92–110 | Confirmation banner fades in below: **"Thank you. The care team has been told to come and check."** wait — shipped copy fires on *deny/help*; on "expected" the shipped confirmation is the calm acknowledgement. Use the comp's existing green banner copy verbatim from `hub-surface.tsx`; do not invent new copy. |
| 110–165 | Hold ~1.8s. |

**Transition out (655–665):** 10-frame cross-dissolve to the family beat.

## Beat 5 — MeridianFamily: the loop closes — frames 660–840 (6.0s)

**Purpose:** the family's uncertainty problem, answered. Notification, then
staff response, resolution visible.

Headline: **MeridianFamily / "Stay informed. Stay close." / "Updates arrive in
the family app—not as a text message."**

| Frames (local 0–180) | Phone action |
|---|---|
| 0–12 | Fade in, phone slides up as in Beat 2. Header: **Updates**. |
| 8–26 | Amber-keyline card drops in: **"Maggie may need help in Room 101."** / **"Care team has been alerted."** |
| 60–75 | **STAFF RESPONSES** label fades. |
| 75–95 | Green check card rises: **"A caregiver is responding."** / **"Maggie is not alone."** |
| 120–145 | The amber card's ring cools to green (border-color interpolation) — resolution without a single word added. |
| 145–180 | Hold ~1.2s. |

**Transition out (836–842):** 6-frame fade to `#0B111B`.

## Beat 6 — End card — frames 840–870 (1.0s, hard cap)

Exactly as shipped: deck-navy background, M-notched shield + cross in deck
blue, **MERIDIAN** caps (spacing 8), **"The Care Intelligence Layer for Senior
Living."** Fade in 0–9, hold to 870. Nothing animates after frame 852.

---

## Copy manifest (verbatim, single source of truth)

| Surface | Line |
|---|---|
| B1 caption | No video ever leaves the building. |
| B2 headline | Care, in sync. / One clear alert. One clear response. |
| B2 alert | Maggie may need help in Room 101. / Fall detected |
| B2 states | Acknowledge → Acknowledged → Mark responding → Responding / Care team is responding. |
| B3 headline | Help is on the way. / The resident sees every step clearly. |
| B3 panel | Help is coming. A caregiver is on the way. (+3 progress rows) |
| B4 headline | Your voice matters. / A calm choice for an unexpected visitor. |
| B4 panel | Is this person expected? / Someone we do not recognise was seen at the entrance. / Yes, expected / No, get help |
| B5 headline | Stay informed. Stay close. / Updates arrive in the family app—not as a text message. |
| B5 cards | Maggie may need help in Room 101. / Care team has been alerted. / A caregiver is responding. / Maggie is not alone. |
| B6 | MERIDIAN / The Care Intelligence Layer for Senior Living |

## Hard constraints (fail the review if violated)

1. Total exactly 870 frames; end card ≤ 30 frames.
2. Fall and skeleton layers share one scale ramp (overlay must not drift).
3. No digits on screen other than "101" in "Room 101".
4. No ETA number, no meal/breakfast row, nothing styled as an SMS thread.
5. All icons inline SVG — no decorative Unicode (font fallback broke it once).
6. Brand mark visible on every beat except the end card.
7. `npx tsc --noEmit` clean, `npm run lint` clean, render exits 0 at 870 frames.

## Verification protocol (run after render)

1. Frame count == 870 exactly (`cv2.CAP_PROP_FRAME_COUNT`).
2. Extract frames 6, 30, 90, 130, 160, 200, 250, 320, 360, 430, 480, 520,
   600, 680, 760, 820, 855 — eyeball every one against this script.
3. Boundary checks: 164/166, 344/346, 494/496, 659/661, 839/841 — confirm each
   transition is the specified type and there is no flash frame.
4. Grep rendered comp source for `\d` digits in copy strings; only "101"
   may appear.
5. `python -m pytest -q` still green (nothing outside `video/` touched).
