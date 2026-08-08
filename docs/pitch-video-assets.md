# Stock asset manifest — 30-second product demo video

Companion to `docs/pitch-video-plan.md`. Every candidate below was researched
and, where noted, opened and read. **Titles on stock sites lie regularly** — two
of the most promising candidates turned out to be something completely different
once I read the actual page. Status column says what was verified.

Status key:

| | Meaning |
|---|---|
| ✅ | Page read, content matches the need |
| ⚠️ | Page read, metadata is contradictory — **watch before using** |
| ❌ | Page read, does **not** match despite the title |

**Pexels and Pixabay license:** free for commercial use, no attribution
required, no release needed. Safe for a pitch video.

---

## Beat 1 + 2 — the fall (drives the skeleton)

This is the one hard asset, exactly as predicted. It serves two beats: the
footage itself, and the skeleton the detector generates *from* that footage via
`run_live_demo.py --source`.

### Free candidates

| Clip | URL | Status |
|---|---|---|
| Woman Falling Off Bed | [pexels 11956328](https://www.pexels.com/video/woman-falling-off-bed-11956328/) | ⚠️ Title says she falls; the page description says "a woman sitting in a bed at night, dim lighting." **Watch it.** If she genuinely goes to the floor, this is the whole problem solved for free — dark bedroom, correct mood, right setting. |
| Woman Waking Up Scared in Darkness | [pexels 11956329](https://www.pexels.com/video/woman-waking-up-scared-in-darkness-11956329/) | ⚠️ Consecutive ID — same shoot as above. Check both. |
| Sad Woman Lying Down On Floor | [pexels 10496637](https://www.pexels.com/video/sad-woman-lying-down-on-floor-10496637/) | ⚠️ Indoor floor, but emotional distress rather than a fall. Usable as *aftermath* only — no fall motion for the detector. |
| Elderly Man Lying Down on the Stairs | [pexels 5264815](https://www.pexels.com/video/elderly-man-lying-down-on-the-stairs-5264815/) | ❌ **Not a fall.** It is a senior resting outdoors on stone steps on a sunny day. The title is badly misleading. |
| People Lying on the Floor | [pexels 7696095](https://www.pexels.com/video/people-lying-on-the-floor-7696095/) | ❌ Two people on a blue studio floor, artistic lighting. Wrong entirely. |

Pixabay's "fall down" search returns autumn leaves, waterfalls and escalators.
Nothing usable.

### Paid fallback — exact matches exist

If 11956328 does not deliver, buy one clip. iStock has 3,200+ and Getty 1,500+,
with precisely the needed scenario. Titles and durations confirmed on
[iStock](https://www.istockphoto.com/videos/elderly-person-falling):

- *"Asian senior elderly female fall on the ground while walk alone in house"* (0:18)
- *"Asian senior elderly male fall on the ground while walk alone in house"* (0:12)
- *"Helpless lonely old 60s man falls to the floor while getting up from the couch"* (0:15)
- *"Elder senior man lying on floor after falling down with wooden walking stick"* (0:05)

Per-clip pricing is not shown on the search page — check at checkout. This would
be the **only paid asset in the entire video**, and it buys the hero beat. Prefer
a clip of 10s+ so there is room to cut.

**Pick the longest, best-lit, most side-on clip available.** The detector needs
visible hip and shoulder keypoints through the descent; a fall shot from directly
head-on or mostly out of frame will not trip the state machine cleanly.

---

## Beat 1 setup — dim room at night

| Clip | URL | Status |
|---|---|---|
| An Elderly Man Turning On the Lights, Looking at the Other Bed | [pexels 10387906](https://www.pexels.com/video/an-elderly-man-turning-on-the-lights-while-looking-on-the-other-bed-10387906/) | ✅ Elderly man, residential bedroom at night, dim ambient lamp light, 4K. Contributor Ron Lach. Best scene-setter found. |
| Man in Bed Wakes Up to Late Night Phone Call | [pexels 30285726](https://www.pexels.com/video/man-in-bed-wakes-up-to-late-night-phone-call-30285726/) | ✅ Night bedroom, phone motif |
| Man Staring by the Window of His Bedroom | [pexels 6944075](https://www.pexels.com/video/a-man-staring-by-the-window-of-his-bedroom-6944075/) | ✅ Quiet, dim, contemplative |

---

## Beat 3 — caregiver with phone

Cut from the stock hand/phone to the animated MeridianCare screen.

| Clip | URL | Status |
|---|---|---|
| Woman Using Smartphone | [pexels 6096721](https://www.pexels.com/video/woman-using-smartphone-6096721/) | ✅ Scrubs, medical context — closest to a night-shift caregiver |
| Woman Using Smartphone | [pexels 6096746](https://www.pexels.com/video/woman-using-smartphone-6096746/) | ✅ Same set, alternate angle |
| Female in Scrub Suit Drinking Coffee and Taking Picture | [pexels 6096704](https://www.pexels.com/video/female-in-scrub-suit-drinking-coffee-and-taking-picture-6096704/) | ✅ Scrubs + phone, more relaxed |
| Man Using Cellphone Inside an Ambulance | [pexels 8944111](https://www.pexels.com/video/man-using-cellphone-inside-an-ambulance-8944111/) | ✅ Reads as emergency response |

---

## Beat 6 — family member with phone

| Clip | URL | Status |
|---|---|---|
| A Woman Checking Her Phone While Staring Blankly | [pexels 6964003](https://www.pexels.com/video/a-woman-checking-her-phone-while-staring-blankly-6964003/) | ✅ **Best fit** — reads as uncertainty, not melodrama. Matches the deck's "Is she safe?" panel. |
| Woman Got Worried After a Phone Call | [pexels 8052328](https://www.pexels.com/video/woman-got-worried-after-a-phone-call-8052328/) | ✅ Stronger emotion — may be too much for a 4s cut |
| A Lonely Woman Thinking While Holding Her Mobile Phone | [pexels 7279746](https://www.pexels.com/video/a-lonely-woman-thinking-while-holding-her-mobile-phone-7279746/) | ✅ Quieter alternative |

Avoid the "depressed" and "sad woman" variants — the deck's tone is reassurance,
not despair.

---

## Optional B-roll — care setting

Only if a beat runs short. Do not add beats to use these.

| Clip | URL | Status |
|---|---|---|
| Elderly Man Sitting on the Chair | [pexels 7516767](https://www.pexels.com/video/elderly-man-sitting-on-the-chair-7516767/) | ✅ Solo resident |
| A Man Lying on the Bed | [pexels 7516933](https://www.pexels.com/video/a-man-lying-on-the-bed-7516933/) | ✅ Resident in bed |
| A Woman Assisting an Elderly Man | [pexels 7522215](https://www.pexels.com/video/a-woman-assisting-an-elderly-man-7522215/) | ✅ Caregiver helping — good for the resolution beat |
| A Nurse Putting the Vase on the Table | [pexels 7475245](https://www.pexels.com/video/a-nurse-putting-the-vase-on-the-table-and-getting-the-patient-s-cup-7475245/) | ✅ Care facility interior |

---

## Action order

1. **Watch [pexels 11956328](https://www.pexels.com/video/woman-falling-off-bed-11956328/) first.** Everything downstream depends on whether it contains a real fall. Two minutes of work decides whether this video costs $0 or one iStock license.
2. If it fails, buy one iStock clip from the list above — longest, best-lit, most side-on.
3. Download the confirmed ✅ clips at the top resolution offered into `assets/video/`.
4. Run the chosen fall clip through the detector and confirm it actually fires:
   ```powershell
   python tools/run_live_demo.py --source assets/video/stock-fall.mp4 --loop
   ```
   If the state machine never reaches a confirmed fall, try another clip. **Do
   not hand-animate a skeleton** — see `pitch-video-plan.md` §0.
5. Only then start the Remotion assembly.

`assets/video/` is not currently in the repo and these files are large — add it
to `.gitignore` rather than committing the footage.
