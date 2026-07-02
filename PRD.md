# Meridian PRD v1.1

**From Lumi AI to Meridian: a functional care intelligence platform, built to win YBVC**

Team: Dhairya Gurnani (software, full app, outreach), Pranav Emmadi (hardware, camera systems), Megan (UI/UX, marketing)

Status: Draft v1.1 | Date: July 2, 2026

---

## 1. Executive Summary

Meridian is the production evolution of Lumi AI, the elder-care monitoring system built at Synthesis Hacks in May 2026. Lumi proved the concept: computer vision fall detection genuinely working on a Raspberry Pi in 36 hours. Meridian is the real product: every feature functional, hardware that actually holds up, and a product line structured to be pitched, piloted, and sold.

The core problem is unchanged and it is the strongest asset we have: **the gap between when an elderly resident needs help and when a human caregiver actually notices.** In an understaffed senior home, that gap is measured in minutes to hours, and it is where injuries become emergencies.

The one-line positioning: **Meridian is the care intelligence layer for senior living. It watches so caregivers can care.**

---

## 2. Why Lumi Becomes Meridian

|  | Lumi (Hackathon) | Meridian (Product) |
| --- | --- | --- |
| Camera pipeline | Proof of concept, Base64/JPEG snags, Pi CPU maxed out | Fully functional edge unit, owned end to end by Pranav |
| App | Demo-grade iOS caregiver app | Production caregiver + family apps, owned by Dhairya |
| Design | Locked palette, PRD-stage flows | Full UI/UX system and brand, owned by Megan |
| Features | Fall detection working, rest partially wired | Every shipped feature is functional and demoable live |
| Goal | Win a 36-hour hackathon | Win YBVC and convert to a real pilot |

The hackathon's biggest lesson (hardware adds complexity software alone does not have) is now a team structure decision: hardware is a dedicated full-time role, not a shared afterthought.

---

## 3. Problem Statement

Senior care facilities in the US are structurally understaffed, and the residents most at risk (dementia, mobility impairment, fall history) are the ones least able to call for help. Falls are the canonical failure: roughly 37 million falls globally each year require medical attention, and the majority of falls happen indoors, exactly where monitoring should be easiest. Yet detection still depends on a staff member walking past the right door at the right time, or on wearable pendants that seniors resist wearing due to discomfort and stigma.

The cost of not solving it: preventable injuries, "long lie" incidents where a fallen resident goes undiscovered, liability exposure for facilities, and families choosing facilities based on trust they cannot verify.

---

## 4. Market Opportunity

This section is written to be lifted directly into the pitch deck.

- **Fall detection systems**: roughly $470 to 510M globally in 2025, projected toward $750 to 860M over the next decade
- **AI in aging and elderly care (the category Meridian actually plays in)**: valued at approximately $56.8B in 2025, projected to reach $387.5B by 2035 at a 21.3% CAGR
- **Senior assisted living fall detection segment specifically**: $322M in 2025 growing to roughly $680M by 2034 at 8.5% CAGR, with the US as the largest single market
- **Adoption tailwind**: an estimated 61% of senior care facilities plan to implement smart monitoring systems by 2026; 55% of US assisted living facilities already use some form of fall detection
- **The wedge**: the non-wearable segment is the fastest growing product category, precisely because seniors will not reliably wear pendants and watches. Meridian is non-wearable by design.

Beachhead market: independent and small-chain assisted living facilities in the Bay Area (25 to 120 beds), which cannot afford enterprise systems like SafelyYou but face the same staffing and liability pressure.

---

## 5. Competitive Landscape

| Competitor | What they do | Where Meridian differs |
| --- | --- | --- |
| SafelyYou | AI video fall detection for dementia care, enterprise contracts with large senior living chains | Enterprise pricing and sales cycle; Meridian targets small facilities they ignore |
| Kepler Vision / MOBOTIX | Body-language sensor embedded in commercial cameras | Sold as camera infrastructure, no family-facing layer |
| Kami Fall Detect Camera | Consumer camera for seniors living alone, claims 99.5% detection accuracy | Consumer single-camera product, no facility dashboard, no care workflow |
| Apple Watch / Medical Guardian pendants | Wearable fall detection | Requires the senior to wear it, charge it, and not take it off. They do all three |
| CarePredict | Wearable + analytics for facilities | Wearable dependency again; Meridian is ambient |

**The honest read**: fall detection alone is a commodity. Cameras that detect falls exist. Meridian's defensibility is not the detection event, it is everything wrapped around it: the validation layer that kills false alarms, the family trust product, the facility analytics, and a privacy architecture nobody in the consumer tier has.

---

## 6. Product Vision and Positioning

**Tagline carried forward from Lumi**: "A helping hand you don't have to ask for."

**Positioning shift**: Lumi was pitched as a monitoring camera. Meridian is pitched as a **care intelligence platform** with three audiences and one shared source of truth:

1. **Caregivers** get fewer blind spots and fewer false alarms
2. **Families** get verifiable peace of mind, not a monthly invoice and hope
3. **Facility operators** get staffing intelligence and a liability shield

Scope boundary (unchanged from Lumi, and now a selling point): Meridian stays firmly in **monitoring and communication**. It does not diagnose, treat, or make medical claims, which keeps it out of FDA Class II territory and makes it deployable in weeks, not years. In the pitch, this is framed as a deliberate regulatory strategy, not a limitation.

---

## 7. The Meridian Product Line

This is the "pitchable product line" structure. Four named products, one platform. Judges remember named things.

### 7.1 Meridian Sense (hardware edge unit) — Pranav

The room unit: camera plus edge compute. Key architectural decision from the Lumi postmortem: the Pi could not handle the vision workload, so Sense runs pose estimation on-device on capable hardware (Jetson Orin Nano class, or Pi 5 + accelerator), and only sends **skeletal pose data and event flags** upstream, never raw video by default.

- Fall detection via on-device pose estimation
- Gemini-powered validation layer in the cloud confirms ambiguous events before alerting (kills false alarms, the number one reason facilities rip these systems out)
- Facial recognition at entry points for visitor logging (Supabase-backed, carried over from Lumi)
- New-person detection: if an entry-point face does not match a consented resident, staff member, or approved visitor, Meridian creates a pending encrypted enrollment record in Supabase rather than silently adding the person as known
- Works offline-first: alerts queue locally if WiFi drops

### 7.2 Meridian Care (caregiver app) — Dhairya

The iOS app, rebuilt production-grade in Swift.

- Real-time alert feed with severity tiers (fall confirmed, fall suspected, distress, missed medication, unusual inactivity)
- One-tap acknowledge and resolve, so the facility knows who responded and how fast
- Resident-first copy carried from Lumi's design principles: "Maggie needs help in Room 12," never "Event #4471 triggered"
- Shift handoff summary: what happened in the last 8 hours, auto-generated

### 7.3 Meridian Family (family app + SMS) — Dhairya

The trust product, and the emotional core of the pitch.

- Daily "Maggie had a good day" summaries (activity level, meals attended, visitors)
- Instant SMS/push for confirmed emergencies, with resolution status ("Staff reached her in 90 seconds")
- Visitor log visibility, including clearly labeled unknown/pending visitor entries when the facility has enabled face recognition
- Explicit privacy controls: families see summaries and events, never live video

### 7.4 Meridian Insights (facility dashboard) — Dhairya + Megan

The web dashboard (Next.js, carried over from Lumi's onboarding app) that turns Meridian from a safety gadget into an operations tool. **This is what makes the business model work**, because it is what a facility director pays for.

- Floor-level live status view
- Response-time analytics per shift (this is the metric directors are judged on)
- Fall-risk trend flags per resident based on movement pattern changes over weeks
- Incident reports auto-generated for compliance and liability documentation
- Admin review queue for unknown-person detections: approve, reject, merge with an existing person, or mark as one-time visitor

---

## 8. New Product Recommendations (researched additions)

These come from studying what the market is actually buying and what past YBVC winners had that Lumi lacked. Ranked by pitch value per unit of build effort.

**P0-adjacent, build for the pitch:**

1. **Privacy Mode / Skeleton-Only Processing.** Market research shows privacy is the top adoption objection for camera-based systems (34% of users cite data privacy concerns in connected monitoring). Meridian processes video on-device and transmits only pose skeletons. Demo this live: show the judges the skeleton view. Given that this judge panel is stacked with cybersecurity and AI infrastructure people (PayPal Ventures cybersecurity investor, Perceptix.AI founder, World tech lead, Inception Studio's John Whaley), this single feature is engineered for this room. It converts the creepiest thing about the product into its most impressive moment.
2. **Predictive Fall Risk Scoring.** The industry's clear direction is prediction over detection: gait speed decline, increased nighttime bathroom trips, and unsteadiness patterns precede falls by days to weeks. Meridian Sense already captures pose data continuously, so a weekly risk score per resident is a data product we get almost for free. This reframes Meridian from reactive (camera that sees falls) to proactive (system that prevents them), which directly hits the "creativity and originality" and "industry impact" rubric lines.

**P1, roadmap slides only:**

1. **Night Rounds Automation.** Facilities do scheduled overnight room checks that wake residents and consume staff hours. Meridian verifies "resident in bed, breathing-consistent movement" passively. Pitch line: give every night nurse an extra pair of eyes on every room simultaneously.
2. **Wander / Exit Detection for memory care.** The facial recognition pipeline already exists from Lumi. Pointing it at exits to flag when a memory-care resident approaches a door alone is high value and low incremental build. Dementia-driven wandering is one of the highest liability events a facility faces.
3. **Medication Adherence Verification.** Lumi had medication reminders; Meridian upgrades reminders to verification (event logged when med cart reaches the room). Bridges toward the smart pillbox idea from the original Lumi PRD without new hardware.

**P2, mention only if asked:**

1. Bed and door sensor integrations (from Lumi's original sensor expansion list), voice-based distress detection, insurance-partner reporting APIs.

---

## 9. Requirements

### Must-Have (P0): the "everything functional" bar

The rule: if it is on a pitch slide, it must work live.

- [ ]  Sense unit detects a staged fall in under 5 seconds, end to end to phone alert in under 15 seconds
- [ ]  Gemini validation layer classifies fall vs. sitting-down vs. object-drop with measured accuracy on our own test set (target: over 90% precision on confirmed falls, publish the number in the pitch, judges trust teams who measure themselves)
- [ ]  Caregiver app: live alert feed, acknowledge/resolve flow, resident profiles
- [ ]  Family SMS alert with resolution follow-up
- [ ]  Insights dashboard: live floor view plus response-time metric
- [ ]  Skeleton-only privacy mode demonstrable on demand
- [ ]  Full onboarding flow (six steps plus success screen, carried from Lumi PRD, redesigned by Megan)

### Nice-to-Have (P1)

- [ ]  Predictive fall-risk score (even a v1 heuristic on gait speed)
- [ ]  Shift handoff auto-summary
- [ ]  Visitor recognition and logging polished for demo
- [ ]  New-person detection at entry points: unknown faces create encrypted pending enrollment records in Supabase for admin review, never automatic enrollment

### Future (P2)

- Night rounds automation, wander detection, med verification, sensor integrations

### Non-Goals

- **No medical claims or diagnosis.** Keeps us out of FDA Class II. Deliberate.
- **No raw video storage in the cloud by default.** Privacy architecture is the moat; do not compromise it for a feature.
- **No plaintext biometric database.** Face embeddings, visitor snapshots, and pending enrollment evidence must be encrypted before or during backend persistence. Supabase may hold ciphertext, metadata, RLS policies, and key IDs, but not decryption keys that would make stolen database contents useful by themselves.
- **No silent facial enrollment.** Unknown people are not automatically converted into recognized residents, staff, or visitors. Face recognition requires facility approval and the relevant resident/legal-representative consent path.
- **No Android caregiver app for v1.** Facilities can standardize on managed iPhones; Android doubles Dhairya's surface area for zero pitch value.
- **No in-home consumer version for v1.** B2C is a real market but a different sales motion; it stays a roadmap slide.
- **No custom hardware manufacturing.** Off-the-shelf compute in a clean enclosure. We are a software and intelligence company that ships on commodity hardware.

### 9.1 New-person detection and encrypted Supabase enrollment

This feature extends visitor recognition into a compliant enrollment workflow:

1. The Hub/Sense pipeline detects a face at an entry-point camera and computes a local face embedding.
2. The Hub compares the embedding against the local approved-person store.
3. If no approved match clears the threshold, the Hub emits a `visitor_arrival` event with `match_status: "unknown"` in metadata.
4. The backend writes a `pending_person_enrollments` record in Supabase scoped to `facility_id`.
5. The pending record stores only encrypted biometric data and encrypted evidence references: face embedding ciphertext, optional encrypted snapshot path, key ID, nonce, algorithm, quality score, camera ID, detection time, and status.
6. An admin must approve, reject, merge, or dismiss the record before it can become a known resident/staff/visitor profile.

Security and privacy requirements:

- Default cloud behavior remains metadata-only. Raw frames stay local unless the facility has explicitly enabled encrypted evidence upload.
- If a snapshot is uploaded, it must be encrypted before storage in the private Supabase bucket, with keys kept outside Supabase or wrapped by a facility-controlled key authority.
- Face embeddings are biometric data. Treat them as sensitive even though they are not human-viewable images.
- Row-level security must restrict every pending enrollment, person profile, incident, device heartbeat, and evidence object to the correct facility.
- Admin actions must be audited: who approved/rejected, when, and whether consent was verified.
- The UI must never imply that an unknown person is identified until the approval flow is complete.

---

## 10. Team

| Person | Owns | Pitch framing |
| --- | --- | --- |
| Dhairya | Full software stack: caregiver app (Swift), family app, Insights dashboard (Next.js), Firebase/Supabase backend. Plus outreach: pilot facility relationships, judge-facing narrative | Founder who ships and sells. Built and runs TheSpeakingLab (80+ students coached, national winners), so the "can this kid actually do BD" question answers itself |
| Pranav | Meridian Sense end to end: camera, edge compute, pose pipeline, on-device inference, reliability | The reason "fully functional" is credible. Hardware was the hackathon bottleneck; now it has a dedicated owner |
| Megan | UI/UX system, brand, marketing site, pitch deck design, demo choreography | The reason Meridian looks like a product, not a project |

Three people, zero overlap, every rubric-relevant discipline covered. This clean division of labor is itself a slide.

---

## 11. Business Model

**Primary (B2B): per-room monthly SaaS to facilities.**

- Hardware: Sense unit at cost-plus (~$149 one-time per room) so hardware never blocks the deal
- Software: $9 to 19 per room per month for Care + Insights
- A 60-bed facility is roughly $21K to 28K ARR. Ten small facilities is a real business
- Anchor the price against the alternative: one prevented fall-related hospitalization or one avoided lawsuit pays for years of Meridian

**Secondary (B2C attach): Meridian Family premium at $9.99/month per family**, sold through the facility. This is the expansion revenue and the retention lock: families who check the app daily will not let the facility cancel.

**Why judges will like it**: recurring revenue, a hardware wedge with software margins, land-and-expand within each facility, and a clear articulation of who pays and why (the facility pays to reduce liability and staffing pain; families pay for verified peace of mind).

---

## 12. YBVC Win Strategy

### 12.1 The rubric, mapped

YBVC judges on seven criteria: business model, market opportunity, creativity and originality, scalability and growth potential, presentation quality, feasibility and risk, and social and industry impact.

| Rubric line | Meridian's answer |
| --- | --- |
| Business model | Per-room SaaS + family attach, unit economics on one slide |
| Market opportunity | $56.8B AI elder-care category growing 21% annually; beachhead in small facilities incumbents ignore |
| Creativity & originality | Skeleton-only privacy architecture + prediction-not-just-detection framing |
| Scalability & growth | Commodity hardware, software margins, each facility is a repeatable unit; product line shows the expansion path |
| Presentation quality | Megan owns this as a role, not a task; live demo rehearsed as choreography |
| Feasibility & risk | It already works (fall detection shipped at the hackathon); regulatory risk pre-answered with the monitoring-not-medical boundary; hardware risk answered by team structure |
| Social & industry impact | Understaffed senior care is a labor crisis with a demographic clock; the founding story is personal and true |

### 12.2 What wins this competition (pattern analysis of 2025 winners)

- **SchoolAce won first because it was "already piloted in schools."** Traction beat everything. Lesson: Meridian needs at least one pilot conversation, ideally a signed LOI or an active trial with a local facility, before the pitch. This is Dhairya's outreach mandate and it is the single highest-leverage task in this document.
- **SafeLock took second with hardware + a safety mission + an app**, the exact same shape as Meridian. Lesson: the shape works; the differentiator is execution depth and a live demo that does not flinch.
- **PawScan took third with AI + healthcare + a quantified institutional market.** Lesson: name the number of target facilities, not just market dollars.

### 12.3 The judge room

The 2025 panel skewed heavily toward AI infrastructure and cybersecurity (PayPal Ventures, Perceptix.AI, World, Inception Studio) plus consumer/Gen Z product sense (noplace). If 2026's panel looks similar, two moves are engineered for it:

1. Lead the technical narrative with the **privacy architecture** (on-device inference, skeleton-only transmission, no default cloud video). Security-minded judges will ask about it anyway; answering before they ask reads as maturity.
2. Have the **false-alarm precision number** ready. Every AI investor in that room has seen a demo that only works in demos. A self-reported accuracy figure from our own test protocol, with the methodology on a backup slide, is the credibility unlock.

### 12.4 Pitch choreography (3 hero beats, evolved from Lumi's demo plan)

1. **The gap.** Open on the personal story: a family friend with dementia in an understaffed home. Then the industry framing: when Maggie falls at 2 AM, the average discovery time is however long until the next scheduled round. Show the empty hallway.
2. **The catch.** Live demo: staged fall on camera, skeleton view on screen (privacy point lands visually, no explanation needed), phone buzzes in a judge's hand within seconds, family SMS follows with "Staff responded in 90 seconds."
3. **The business.** One slide: the product line, the per-room math, the pilot facility, the $56.8B category clock. Close on the tagline: a helping hand you don't have to ask for.

### 12.5 Risks judges will probe, and the prepared answers

- *"Why won't SafelyYou crush you?"* They sell six-figure enterprise contracts to national chains. Our beachhead is the 25 to 120 bed facility they will not send a sales team to. We win the segment they ignore, then grow with it.
- *"What about consent for residents with dementia?"* Consent is obtained at admission from the resident or legal representative, monitoring is disclosed in the care agreement, and the skeleton-only default means the system is structurally less invasive than the human alternative (staff opening doors at night). Carried over from Lumi's open questions, now with an answer.
- *"What if it misses a fall?"* Meridian is positioned as augmenting staff, never replacing rounds, and the service agreement says so. Detection lag with Meridian is strictly better than without it. We are a monitoring and communication tool; the standard of care remains the facility's.
- *"Three high schoolers running a company?"* The product already caught a fall on camera under a 36-hour deadline. The founder already runs a coaching business with 80+ clients. Judges bet on evidence of shipping, and we have it.

---

## 13. Success Metrics

**Leading (pre-competition):**

- P0 feature checklist 100% demoable by 4 weeks before pitch day
- Fall detection precision over 90% on internal test protocol (100+ staged events)
- End-to-end alert latency under 15 seconds, measured, not estimated
- At least 1 pilot facility in active trial or signed LOI (stretch: 2)
- Full 3-minute pitch rehearsed to under 2:50 with live demo, 10+ run-throughs

**Lagging (post-competition):**

- YBVC finalist (success) / top 3 (target)
- Pilot converts to first paying facility within 90 days of the competition
- 5 family-app households active at the pilot site

---

## 14. Open Questions

- **[Pranav, blocking]** Final edge hardware selection: Pi 5 + AI accelerator vs. Jetson Orin Nano. Decision needed before enclosure and cost model lock.
- **[Dhairya, blocking]** Pilot facility target list and outreach script. Which 10 local facilities get contacted first, and what is the ask (free 60-day trial in 2 to 4 rooms)?
- **[Megan, non-blocking]** Does Meridian keep the lumi-slate palette or rebrand fully? Recommendation: rebrand, Meridian is a new company story, but keep the calm/emergency two-state design principle.
- **[Team, non-blocking]** Confirm 2026 YBVC application window and requirements (2025 required a full business plan plus pitch video for 54 applicants cut to 15 finalists). Check ybvcompetition.org / ybvchallenge.org for this cycle's dates.
- **[Dhairya, non-blocking]** Whether to file a provisional patent on the validation-layer approach or treat speed as the moat. Likely answer for now: speed.

---

## 15. Timeline (working backward from the pitch)

| Phase | Window | Milestones |
| --- | --- | --- |
| 1. Foundation | Weeks 1 to 3 | Hardware selection locked (Pranav), app architecture and backend scaffolding (Dhairya), brand + design system (Megan) |
| 2. Core build | Weeks 4 to 8 | Fall pipeline reliable on final hardware, caregiver app alert loop working end to end, dashboard v1 |
| 3. Validation | Weeks 9 to 10 | 100+ staged-fall test protocol, precision number locked, false-alarm tuning via Gemini layer |
| 4. Pilot + polish | Weeks 11 to 13 | Facility trial live, family app onboarding real users, Insights populated with real data |
| 5. Pitch | Final 3 weeks | Business plan document, pitch video, deck (Megan), 10+ live-demo rehearsals, Q&A murder board |

Hard dependency: the pilot outreach (Phase 4) must start during Phase 1. Facilities move slowly; the LOI conversation begins now.

---

*Sources for market figures: Grand View Research and Persistence Market Research (fall detection systems), InsightAce Analytic (AI in aging and elderly care, 2026), Market Growth Reports (facility adoption rates), Future Market Insights. Competitive intel: SafelyYou, Kepler Vision/MOBOTIX, Kami Vision public announcements. YBVC 2025 results and judging criteria: Berkeley Summit House event page.*
