# Two minute explainer — production script (120.0s, 3600 frames @ 30fps)

A **standalone** film. Nothing else is on screen beside it, so unlike the
29 second reel it has to carry its own evidence. It ships as a second Remotion
composition, `MeridianExplainer`, in the same project, reusing the demo's beats
and giving each one room to explain itself.

The 29 second cut (`MeridianDemo`, 870 frames) is unchanged and stays the
version that plays next to the deck.

## What changes versus the reel

| | 29s reel | 2min explainer |
|---|---|---|
| Plays | beside the deck | alone |
| Numbers | banned, the deck sourced them | **allowed, if measured** |
| Job | prove the product exists | explain how it works and why to believe it |

**The numbers rule inverts, but the honesty rule does not.** Every figure on
screen must trace to a file in this repo, and must be stated with the bound
that file states. A standalone film that shows no evidence looks evasive; one
that overstates gets punctured in the Q&A that follows it.

### Permitted claims, with their exact wording

| Claim | Source | Wording that is allowed |
|---|---|---|
| Detection latency | `benchmarks/alert_latency_2026-08-07.md` | "Hub detection to ingest acknowledgement, p95: 2.0s confirmed, 3.2s suspected." Immediately followed by the bound: "Camera capture, network and phone display are not included." |
| Concurrent rooms | same benchmark | "12 simultaneous 480p streams, 15.2 FPS per room minimum, measured on one laptop." Add "synthetic streams" — decode cost is not in that figure. |
| Model | `models/yolo11s-pose-480x640.onnx` | "YOLO11 pose, 17 keypoints, ONNX Runtime, GPU accelerated on the Hub." |
| Frames never leave | `tests/test_claim_guards.py` | "Frames are never written to disk and never uploaded — enforced by a test that fails the build if it ever changes." |
| Encryption | same | "Face data is encrypted AES-256-GCM on the Hub. The key never leaves the building." |
| Offline | same | "If the internet drops, detection keeps running and alerts queue locally, then deliver exactly once." |
| Test suite | `python -m pytest -q` | "214 tests." Only as evidence of discipline, never as a quality claim. |

### Forbidden, in a standalone cut especially

- "Alerts staff in under 5 seconds" — the end to end path is unmeasured.
- Any live SMS delivery claim — built, but never exercised against Twilio.
- Any meal or eating claim — a room pose cannot observe it.
- A fixed ETA number — the shipped ETA is derived with a confidence label.
- Unlimited rooms — 12 is the validated ceiling, and without decode cost.

---

## Beat map (3600 frames)

| # | Beat | Frames | Dur |
|---|---|---|---|
| 1 | Cold open: the problem | 0–330 | 11.0s |
| 2 | The fall, and pose lock on | 330–690 | 12.0s |
| 3 | How detection works | 690–1140 | 15.0s |
| 4 | The privacy architecture | 1140–1560 | 14.0s |
| 5 | MeridianCare | 1560–2010 | 15.0s |
| 6 | MeridianHub | 2010–2520 | 17.0s |
| 7 | MeridianFamily | 2520–2910 | 13.0s |
| 8 | What is actually proven | 2910–3330 | 14.0s |
| 9 | Close | 3330–3600 | 9.0s |

---

### Beat 1 — Cold open (0–330)

Dark. The night room from `fall.mp4` before anything happens, held and slowly
pushed in, heavily graded down.

Three lines, each fading in and out on its own, mint keyline, lower left:

1. "One caregiver. Twenty rooms. Three in the morning."
2. "A fall is found when somebody happens to walk past."
3. "Meridian is the layer that notices."

Then the Meridian mark resolves centre screen and dissolves out.

### Beat 2 — The fall (330–690)

The reel's beat 1, given room. Same clip, same `CLIP_START`, same shared zoom
ramp, same screen blended real skeleton.

- Pose locks on while she walks. Label appears beside the skeleton: "Live pose, on the Hub."
- The fall plays raw.
- Footage dims away, skeleton alone remains.
- Caption: "No video ever leaves the building." then "Only the alert does."

### Beat 3 — How detection works (690–1140)

The pipeline diagram, rebuilt with room to read, plus the state machine made
explicit — this is the beat the reel could not afford.

Nodes as in `MeridianDemo`: CAMERA, ON DEVICE POSE, FALL STATE MACHINE,
ALERT DISPATCHED, connectors wiping mint between them.

Then hold on the state machine and expand it:

- Normal → Candidate → Confirmed, each chip lighting in turn.
- Beside them, the actual gates, in words not symbols: "Downward hip speed and torso angle cross together." / "Then either the torso is horizontal and still, or the drop was severe."
- One line underneath: "Every threshold lives in one file, tuned against recorded clips, not guessed."

### Beat 4 — Privacy architecture (1140–1560)

Dark. Three claims, each appearing with its enforcement underneath in smaller
muted type. This is the beat that wins technical audiences.

1. "Pose estimation runs on a Hub inside the building." → "YOLO11, ONNX Runtime, GPU accelerated. No third party AI service sees a resident."
2. "Frames are discarded in memory." → "A test intercepts file writes and network calls during frame processing. If that ever changes, the build fails."
3. "Face data is encrypted on the Hub, AES-256-GCM." → "The key never leaves the building. A full cloud breach yields ciphertext and no keys."

Close the beat on: "You cannot steal what was never sent."

### Beat 5 — MeridianCare (1560–2010)

The reel's Care beat, extended. Urgent alert modal arrives, is acknowledged,
moves to responding, resolution note. Add the explanatory column on the left:

- "Every alert is one tap from acknowledged."
- "Five states, enforced on the server, not in the app: acknowledged, responding, resolved, dismissed as a false alarm, escalated."
- "Response times are logged, so a facility can prove them."

### Beat 6 — MeridianHub (2010–2520)

The longest beat, because it is the least expected and the hardest to explain
in a sentence. Action grid → request → live help status → reminders → visitor
verification.

- "The resident is not only watched. She can act."
- "Request help, call family, or raise an emergency, from the room."
- "When a fall is detected, the request is raised for her automatically."
- Visitor: "An unrecognised visitor asks her, not a screen somewhere else." and "If she says no, the care team is told."

### Beat 7 — MeridianFamily (2520–2910)

Today card, then Updates. Explanatory column:

- "Families get what actually happened, not a reassurance."
- "Movement patterns compared against the resident's own baseline, never against a stranger's."
- "What the system cannot observe, it does not report."

That last line is deliberate and should be on screen long enough to read. It is
the honest answer to the meals question before anybody asks it.

### Beat 8 — What is actually proven (2910–3330)

Light. A quiet evidence card, one row at a time, each with its bound. Wording
verbatim from the table above. Order:

1. Detection to ingest acknowledgement, p95 2.0s / 3.2s — with the "does not include camera, network, phone" bound in muted type directly underneath.
2. 12 simultaneous synthetic streams, 15.2 FPS per room minimum.
3. Frames never written, never uploaded — enforced by test.
4. Offline: queued locally, delivered exactly once.
5. 214 tests.

Then one closing line, which is the point of the whole beat:
**"Everything above is measured in this repository. The things we have not measured, we do not claim."**

### Beat 9 — Close (3330–3600)

The end card, held longer than the reel's: shield, MERIDIAN, "The Care
Intelligence Layer for Senior Living." Then a final line fading in beneath:
"Faster help. Less uncertainty. More dignity."

---

## Hard constraints

1. `MeridianExplainer` is exactly 3600 frames. `MeridianDemo` stays exactly 870 and is not modified.
2. Every number on screen appears in the permitted table above, with its bound.
3. Inline SVG icons only. No decorative Unicode.
4. No hyphens, en dashes or em dashes in on screen copy.
5. Reuse the demo's components rather than forking them, so a fix lands in both.
6. Same verification protocol: frame count, flash frame scan, digit audit.
