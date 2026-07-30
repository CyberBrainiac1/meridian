# Pitch Deck — Screenshot Plan

Status: v1 | Deck: *Meridian AI Pitch Deck (A)* | Assets: `docs/deck-assets/`

Every image referenced here is a real screenshot of software that runs today — nothing is a mockup or a comp. Files are numbered in the order the story uses them, so filling the deck is drag-and-drop in sequence.

---

## 1. The one idea the screenshots have to land

A deck full of app screenshots is boring. A deck that walks one incident from **detection → response → accountability** is a story. So the images are ordered as a single continuous narrative about one resident, Maggie, in Room 101:

> Maggie falls → the caregiver's phone lights up → they respond and resolve it → the shift log proves how fast → and the whole time, all Meridian ever saw was a skeleton.

That last beat is the differentiator, so it gets its own full-bleed slide rather than being buried in a feature list.

---

## 2. Asset inventory

| # | File | What it shows | Source |
|---|---|---|---|
| 01 | `01-skeleton-privacy-view.png` | Live pose skeleton, green on black, captioned "NO VIDEO TRANSMITTED — SKELETON DATA ONLY" | Real pipeline output, 1920×1080. Regenerate anytime (§5) |
| 02 | `02-alert-arrives.png` | Alerts list — "Maggie may need help in Room 101", *Needs attention*, 4m ago | Meridian Care, iPhone 17e |
| 03 | `03-caregiver-responds.png` | Alert detail — "Fall suspected", with Acknowledge / Mark responding / Resolve / Dismiss as false alarm / Escalate | Meridian Care |
| 04 | `04-shift-handoff.png` | "3 alerts in the last 8 hours. 2 resolved. 1 still open." with severity tiers + a visitor event | Meridian Care |
| 05 | `05-resident-context.png` | Residents — Maggie R., `fall history` tag, "Prefers morning walks; mild dementia" | Meridian Care |

**Deliberately excluded.** `MeridianCare v1 SS2.png` is a near-duplicate of SS1 (same screen, different timestamp) — using both makes the deck look padded. `SS6` is the Settings screen (facility name, sign out); it's a utility screen that proves nothing a judge cares about. Two fewer slides beats two weak ones.

---

## 3. Slide-by-slide placement

The deck currently has 7 slides. Here's what goes where and why.

### Slide 1 — Title
No screenshot. Keep it clean.

### Slide 2 — THE PROBLEMS
No app screenshot. This slide is about the world *before* Meridian; showing the product here spoils the reveal. Keep the existing imagery.

### Slide 3 — THE SOLUTIONS ← **replace the generic phone mockups**
Use **02 → 03 → 04**, left to right, as three phones in a row. This is the highest-value change in the deck: it turns an abstract "solutions" slide into a visible workflow.

Caption each one with the *outcome*, not the feature:
- **02** — "The phone knows before anyone walks by."
- **03** — "One tap: acknowledged, responding, resolved."
- **04** — "Every response is timestamped and handed off."

Speaker line: *"This is one incident, start to finish, in three screens."*

### Slide 4 — currently the placeholder "Add team slide … in deckB" ← **make this the privacy slide**
Full-bleed **01**, minimal text. The image already has empty space on the left, so put the line there:

> **All Meridian ever sees is this.**
> On-device pose estimation. No video leaves the room.

This is the slide people remember, and it pre-empts the first objection every judge raises about cameras in bedrooms. If the team slide is genuinely needed, add it *after* this one — don't displace the privacy beat.

### Slide 5 — PRODUCT-MARKET FIT
No new screenshot. It's already dense with text; an image would compete. Optionally reuse a small crop of **04** beside "Directors asked for visitor verification. We built it." — the visitor line is literally visible in that screenshot, which is a nice proof-in-passing.

### Slide 6 — COMPETITIVE ADVANTAGE
Add **05** small, next to the "Capability Edge" column. The `fall history` tag and "mild dementia" note make the resident-first design concrete, which is exactly the contrast against a wearable that just knows an accelerometer spiked.

### Slide 7 — Impact ← **currently near-empty, and the one real gap**
This wants the **Insights dashboard response-time analytics** — the metric a facility director is judged on. **That screenshot cannot be taken yet** (see §4). Until it exists, use the numbers as large type rather than a fake chart:

> Detected in **under 5 seconds**. Caregiver notified in **under 15**.
> Verified across **50/50** staged falls.

Those are measured figures from the test suite, so they're honest to put on a slide.

---

## 4. What's blocked, and exactly how to unblock it

**The Insights dashboard cannot be screenshotted right now.** Two separate causes, both must be fixed:

1. **The Supabase project is paused.** Free-tier projects pause after 7 days idle; `wgpvaazhpfceountxxel.supabase.co` currently doesn't respond. Unpause it from the Supabase dashboard (data is retained for 90 days).
2. **The dashboard has no Supabase credentials configured.** `/login` renders but shows: *"No Supabase project is configured yet (NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY are unset)."* Set both in `meridian_insights/.env.local`.

Once both are done, the shots worth capturing — in priority order:
- **Response-time analytics** (`/analytics`) → slide 7. The single most valuable missing image.
- **Floor / live status view** (`/`) → optional addition to slide 3.
- **Incident detail** (`/incidents/[id]`) → backup slide for Q&A about documentation and liability.

The Care and Family **iOS apps need a Mac with Xcode** to run, so any *new* iOS screenshots have to come from Dhairya. The five existing ones are enough for the deck as planned.

---

## 5. Regenerating the skeleton image

The skeleton still is reproducible on demand — it isn't a one-off capture:

```bash
python tools/hold_pose_frame.py --source tests/fixtures/videos/one-by-one-person-detection.mp4 --export docs/deck-assets/01-skeleton-privacy-view.png --no-serve
```

It scans the clip with the real pose pipeline, picks the frame with the cleanest full-body figure, and writes a 1920×1080 PNG styled like the live demo page. Drop `--no-serve` to instead hold that pose on the relay so the actual `/demo/skeleton` page renders it steadily — useful for filming the demo or grabbing a browser-native screenshot.

**Once you have real staged-fall footage, re-export from that instead.** A skeleton mid-fall is a far stronger slide-4 image than someone walking, and it makes the privacy slide and the fall-detection claim the same picture.

---

## 6. Quick checklist

- [ ] Slide 3: swap generic mockups for 02 → 03 → 04 with outcome captions
- [ ] Slide 4: full-bleed 01 + "All Meridian ever sees is this."
- [ ] Slide 6: add 05 beside the Capability Edge column
- [ ] Slide 7: measured numbers as large type (until the analytics shot exists)
- [ ] Unpause Supabase + set `meridian_insights/.env.local` → capture `/analytics` → finish slide 7
- [ ] Re-export 01 from real staged-fall footage when available
