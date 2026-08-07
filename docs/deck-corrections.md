# Deck corrections — claims that must be fixed by editing, not by building

Companion to `docs/deck-claim-audit.md`. Everything here is a claim that
**cannot be made true by writing code**, either because it is a statement about
the world rather than the product, or because it overclaims in a way a judge can
puncture. Fix these in the deck itself.

Live deck: https://docs.google.com/presentation/d/1PxWPKxMAnFazC8NlKDcssM6M2DeyCW9DQKKZ1iUaBYM/edit

---

## 1. Slide 8 — "Open-source pose model with more parameters for higher accuracy"

**Problem.** The comparison is unknowable. SafelyYou and CarePredict do not
publish their model architectures, so "more parameters than theirs" is a claim
nobody in the room — including us — can check. If a judge asks "more than
what?", the honest answer is "we don't know", and the whole Technical Edge box
collapses.

**What is actually true and stronger:** the model is `yolo11s-pose`, open
source, auditable, self-hostable, and swappable without a vendor negotiation.
It runs entirely on hardware we control. That is a real architectural
advantage against a closed vendor stack, and it survives cross-examination.

**Suggested replacement:**
> Open-source, auditable pose model running on hardware you own — swappable and
> inspectable, not a vendor black box.

---

## 2. Slide 8 — "Meridian has unique advantages against each and every competitive angle!"

**Problem.** Not true, and it is the kind of line that invites a judge to find
the counterexample. SafelyYou has deployment scale, clinical validation history,
and enterprise health-system relationships that a two-person team does not.
Claiming *total* superiority costs credibility that the genuinely strong parts
of the slide have already earned.

**Suggested replacement:**
> Where the incumbents are strong, we are different by design — no wearables, no
> video leaving the building, and a resident who can act, not just be watched.

---

## 3. Slide 8 — "emergency SMS to families"

**Status: being fixed in code**, but read this before presenting.

SMS delivery was deliberately removed in commit `17a60d4` and replaced with
in-app notification delivery. `notification_dispatcher.py` still says so in its
own docstring. Until the SMS work lands and is verified against a live Twilio
account, **do not say "SMS" on stage** — say "instant notification to the
family's phone", which is true today.

Note the deck also implies SMS is a differentiator versus SafelyYou. It is not
much of one; the differentiator is *who gets told and how fast*, not the transport.

---

## 4. Slide 3 — the MeridianFamily mock: "✓ Breakfast ✓ Visitor ✓ Activity time"

**Problem.** Visitor tracking is real. **Breakfast is not, and cannot be.** A
17-point skeleton in a resident's room does not observe meals, and no
meal-tracking pipeline exists anywhere in the system. The family app's own
source code flags this honestly:

> "the PRD's 'meals attended' and generic 'activity level' metrics have no data
> source anywhere in meridian_hub today — deliberately omitted rather than
> fabricated."

The mock in the deck fabricates exactly what the engineering deliberately
refused to fabricate. If a judge asks "how do you know she ate breakfast?",
there is no answer.

**Fix:** replace "Breakfast" in the mock with a signal the system genuinely
produces. Activity/mobility signals are being made real (see
`docs/deck-claim-audit.md` task 5); meals are not.

---

## 5. Slide 7 — every business claim needs a source in the speaker notes

None of these are checkable from the repo, and slide 7 is where a judge is most
likely to ask "says who?":

- "Google Cloud VP approached us unsolicited and introduced us to their venture fund"
- "Three pilot facilities requested us without cold outreach"
- "60-bed facility deploys in 2 weeks, generates 7–10K ARR"
- "each pilot becomes proof for next 3–5 facilities"
- Slide 8's "Wearables dominate (68.7% market share)"
- Slide 2's "$5,000 per month", "20+ residents at night", "15+ minutes on the floor"

Each needs a name, a date, or a citation in the notes. Not on the slide — in the
notes, so the answer is one glance away when it is asked.

**One of these is partly checkable and holds up:** "we built a working fall
detection on Raspberry Pi in 8 hours". The Pi work is real and measured —
`benchmarks/pi4b_pose_benchmark_2026-07-02.md` and
`benchmarks/pi4b_hub_capacity_2026-07-02.md` have the numbers. The "8 hours" is
the unverifiable part; the capability is not.

---

## 6. Slide 6 — one precision edit worth making

> "no third-party AI service ever sees a resident"

This is **true as written** and worth keeping — the daemon path makes zero
network calls, and there is now a test that fails if that ever changes.

But know the footnote cold, because it is the kind of thing a sharp judge
finds: there *is* one third-party vision call in the codebase
(`meridian_hub/face/body_description.py` → Hack Club → Gemini) that generates a
clothing description for an **unrecognized visitor**. It is visitor-only, it is
not wired into the detection loop, and it never touches a resident. If asked,
say that plainly. It is a good answer. Being surprised by it on stage would be
a bad one.

---

## 7. Slide 5 — the app screenshots are honest; the runtime is not yet proven

The MeridianCare screenshots match the code exactly — the five status
transitions, the tab bar, the shift-handoff copy are all really implemented.
But per `docs/demo-plan.md` §0, the SwiftUI apps have never been run on a
device from the dev machine (no Mac). Have the screen recording ready, and do
not claim "running on my phone right now" unless it is.
