import React from "react";
import {
  AbsoluteFill,
  Audio,
  interpolate,
  Sequence,
  staticFile,
  useCurrentFrame,
} from "remotion";
import {
  AppName,
  AudienceLine,
  Background,
  BrandMark,
  BrandShield,
  C,
  Card,
  CareDevice,
  clamp,
  CLIP_START,
  DarkCaption,
  EndCard,
  FamilyDevice,
  FullVideo,
  GLYPH_ARROW_RIGHT,
  GLYPH_CAMERA,
  GLYPH_CPU,
  HubFrame,
  HubHelpPanel,
  HubVisitorPanel,
  L_CHECK_CIRCLE,
  L_CLOCK,
  L_LOCK,
  L_WIFI_OFF,
  PipelineDiagram,
  ramp,
  svgGlyph,
  Vignette,
} from "./shared";

// ---------------------------------------------------------------------------
// MeridianExplainer -- 3600 frames @ 30fps, the standalone two minute cut.
//
// Nothing else is on screen beside this film, so unlike the 29 second reel it
// has to carry its own evidence. That inverts the reel's numbers rule and only
// that rule: every figure below is quoted from
// benchmarks/alert_latency_2026-08-07.md or from the claim guards, and every
// figure is followed by the bound its source states. Nothing that has not been
// measured end to end is claimed here -- no "under five seconds", no SMS
// delivery, no meal observation, no fixed ETA number, no unbounded room count.
//
// Every screen, glyph and token is imported from ./shared, the same module
// Composition.tsx draws MeridianDemo from, so a correction lands in both cuts.
// The app screens take their action clock as a prop, which is how this cut
// plays them slower without forking them.
//
//   Beat 1  Cold open           0-330    the problem
//   Beat 2  The fall          330-690    pose lock on, privacy caption
//   Beat 3  How detection works 690-1140 pipeline, then the state machine
//   Beat 4  Privacy          1140-1560   three claims, each with enforcement
//   Beat 5  MeridianCare     1560-2010
//   Beat 6  MeridianHub      2010-2520   help, then visitor verification
//   Beat 7  MeridianFamily   2520-2910
//   Beat 8  What is proven   2910-3330   the evidence card
//   Beat 9  Close            3330-3600
//
// Sequences overlap by the length of their transition and their zIndex
// descends with time, so the OUTGOING beat always sits above the incoming one
// and fades its own surface away to reveal a beat that is already opaque
// underneath. That is what keeps every dissolve free of a flash frame.
// ---------------------------------------------------------------------------
const E = {
  openFrom: 0, openDur: 336,
  fallFrom: 330, fallDur: 366,
  pipeFrom: 690, pipeDur: 456,
  privacyFrom: 1140, privacyDur: 428,
  careFrom: 1544, careDur: 472, careOffset: 16,
  hubFrom: 1996, hubDur: 320, hubOffset: 14,
  visitorFrom: 2296, visitorDur: 230, visitorOffset: 14,
  familyFrom: 2504, familyDur: 412, familyOffset: 16,
  provenFrom: 2898, provenDur: 436, provenOffset: 12,
  closeFrom: 3330, closeDur: 270,
  // Where the film stops being dark: the brand bug's tint flips here, at the
  // darkest frame of the privacy -> MeridianCare handoff.
  darkEnd: 1554,
};

// The app screens are shared with the reel, where each of them plays out over
// roughly 130 frames. This cut gives them three times that, so it feeds them a
// warped clock instead of a straight frame count: the same actions, in the same
// order, with the reading pauses put where a standalone viewer needs them.
const warp = (local: number, from: number[], to: number[]) =>
  interpolate(local, from, to, {extrapolateLeft: "clamp", extrapolateRight: "clamp"});

// ---------------------------------------------------------------------------
// Beat 1 -- Cold open, frames 0-336. The night room before anything happens.
// fall.mp4 from its first frame at .18 speed, which stops at clip frame 60 --
// thirty frames before the stumble starts -- and so reads as a held shot with
// a slow push in.
// ---------------------------------------------------------------------------
const COLD_LINES: [string, number][] = [
  ["One caregiver. Twenty rooms. Three in the morning.", 24],
  ["A fall is found when somebody happens to walk past.", 112],
  ["Meridian is the layer that notices.", 200],
];
const ColdOpen = () => {
  const f = useCurrentFrame();
  const zoom = clamp(f, [0, 336], [1, 1.09]);
  const footage = ramp(f, [0, 20, 300, 330], [0, 1, 1, 0]);
  // The mark resolves centre screen and dissolves out, covering the handoff
  // into the graded fall footage that beat 2 opens on.
  const markIn = ramp(f, [262, 296], [0, 1]);
  const markOut = ramp(f, [306, 330], [1, 0]);
  const markScale = clamp(f, [262, 300], [0.94, 1]);
  const plate = ramp(f, [330, 336], [1, 0]);
  return <AbsoluteFill style={{background: C.dark, opacity: plate}}>
    <AbsoluteFill style={{opacity: footage}}>
      <FullVideo src="fall.mp4" startFrom={0} scale={zoom} playbackRate={0.18} filter="brightness(.30) saturate(.6) contrast(1.1)" />
      <Vignette />
    </AbsoluteFill>
    {COLD_LINES.map(([line, at]) => {
      const o = ramp(f, [at, at + 20, at + 76, at + 94], [0, 1, 1, 0]);
      const y = clamp(f, [at, at + 20], [12, 0]);
      return <div key={line} style={{position: "absolute", left: 120, bottom: 210, width: 1400, opacity: o, translate: `0 ${y}px`,
                                     color: "white", fontSize: 50, fontWeight: 740, letterSpacing: -1.2, lineHeight: 1.25,
                                     padding: "20px 30px", borderLeft: `5px solid ${C.mint}`, background: "rgba(5,6,10,.66)", borderRadius: "0 16px 16px 0"}}>{line}</div>;
    })}
    <AbsoluteFill style={{justifyContent: "center", alignItems: "center", display: "flex", opacity: markIn * markOut}}>
      <div style={{textAlign: "center", scale: markScale}}>
        <BrandShield size={126} tint={C.mint} stroke={58} style={{display: "block", margin: "0 auto 24px", filter: "drop-shadow(0 4px 18px rgba(0,0,0,.7))"}} />
        <div style={{fontSize: 62, fontWeight: 800, letterSpacing: 9, color: C.mint}}>MERIDIAN</div>
      </div>
    </AbsoluteFill>
  </AbsoluteFill>;
};

// ---------------------------------------------------------------------------
// Beat 2 -- The fall, frames 330-696. The reel's opening beat, given room:
// same clip, same CLIP_START, one shared zoom ramp across both layers, the
// real screen blended skeleton. playbackRate .45 walks 366 comp frames over
// 165 clip frames, so the request never runs past the 291-frame clip. On that
// clock she walks for the first 71 frames of the beat, the fall runs from 71
// to about 138, and the rest of the beat is the aftermath the captions need.
// ---------------------------------------------------------------------------
const FallBeat = () => {
  const f = useCurrentFrame();
  // Both layers MUST share one scale ramp. preprocess_frame does a plain
  // resize rather than a letterbox, so pose coordinates map linearly onto the
  // full source frame and the skeleton lands exactly on her body -- but only
  // while the two layers are transformed identically.
  const zoom = clamp(f, [0, 366], [1.02, 1.12]);
  // Pose locks on while she is still walking, so the fall is watched being
  // tracked rather than revealed after the fact.
  const skeleton = ramp(f, [20, 60], [0, 1]);
  // Out before local 120: the real detector loses her between clip frames 112
  // and 142, and a label reading "Live pose" over a frame with no pose on it
  // would be claiming something the render does not show.
  const label = ramp(f, [44, 64, 104, 122], [0, 1, 1, 0]);
  // Only after the fall does the footage fall away, leaving pose alone on
  // screen for the privacy line.
  const videoBrightness = ramp(f, [200, 250], [0.56, 0.05]);
  const caption = ramp(f, [250, 278], [0, 1]);
  const captionY = clamp(f, [250, 278], [14, 0]);
  const bridge = ramp(f, [300, 326], [0, 1]);
  const beat = ramp(f, [0, 14, 360, 366], [0, 1, 1, 0]);
  return <AbsoluteFill style={{background: C.dark, opacity: beat}}>
    <FullVideo src="fall.mp4" startFrom={CLIP_START} scale={zoom} playbackRate={0.45} filter={`brightness(${videoBrightness}) saturate(.72) contrast(1.08)`} />
    {/* screen blend drops the skeleton render's black background to fully
        transparent, so the strokes composite straight onto her. */}
    <AbsoluteFill style={{opacity: skeleton, mixBlendMode: "screen"}}><FullVideo src="skeleton.mp4" startFrom={CLIP_START} scale={zoom} playbackRate={0.45} /></AbsoluteFill>
    <Vignette />
    <div style={{position: "absolute", left: 120, top: 210, opacity: label, color: C.mint, fontSize: 34, fontWeight: 760, letterSpacing: -0.4,
                 padding: "14px 26px", borderLeft: `5px solid ${C.mint}`, background: "rgba(5,6,10,.66)", borderRadius: "0 14px 14px 0"}}>Live pose, on the Hub.</div>
    <DarkCaption opacity={1} y={captionY} privacy={caption} bridge={bridge} bridgeText="Only the alert does." />
  </AbsoluteFill>;
};

// ---------------------------------------------------------------------------
// Beat 3 -- How detection works, frames 690-1146. The reel could not afford
// this beat: the pipeline at half speed, then a hold on the state machine with
// its gates written out in words rather than symbols.
// ---------------------------------------------------------------------------
const STATE_CHIPS: [string, number][] = [["Normal", 250], ["Candidate", 292], ["Confirmed", 334]];
const STATE_GATES: [string, number][] = [
  ["Downward hip speed and torso angle cross together.", 292],
  ["Then either the torso is horizontal and still, or the drop was severe.", 334],
];
const DetectionBeat = () => {
  const f = useCurrentFrame();
  // The diagram runs on half the reel's clock: nodes land at local 16, 64, 120
  // and 180, the state chips at 132, 152 and 172, and the bell settles by 204.
  const diagram = ramp(f, [212, 232], [1, 0]);
  const machine = ramp(f, [238, 258], [0, 1]);
  const machineY = clamp(f, [238, 258], [18, 0]);
  const skeleton = ramp(f, [0, 18], [1, 0.12]);
  const caption = ramp(f, [8, 24], [1, 0]);
  const content = ramp(f, [438, 450], [1, 0]);
  return <AbsoluteFill>
    <AbsoluteFill style={{background: C.dark}} />
    <AbsoluteFill style={{opacity: content}}>
      {/* startFrom 265 sits inside the clip's 80 held frames, and playbackRate
          .05 walks 456 comp frames over 23 clip frames so the request never
          runs past the 291-frame clip while staying on the held floor pose. */}
      <AbsoluteFill style={{opacity: skeleton, mixBlendMode: "screen"}}><FullVideo src="skeleton.mp4" startFrom={265} scale={1.12} playbackRate={0.05} /></AbsoluteFill>
      <Vignette />
      <AbsoluteFill style={{opacity: diagram}}><PipelineDiagram local={f * 0.5} /></AbsoluteFill>
      {/* Beat 2's bridge line rides across the cut and hands off to node 4's
          "Only the alert leaves the room". The echo is the point. */}
      <DarkCaption opacity={caption} y={0} privacy={1} bridge={1} bridgeText="Only the alert does." />
      <div style={{position: "absolute", left: 260, top: 250, width: 1400, opacity: machine, translate: `0 ${machineY}px`}}>
        <div style={{fontSize: 20, fontWeight: 800, letterSpacing: 3.4, color: C.mint}}>THE FALL STATE MACHINE</div>
        <div style={{display: "flex", alignItems: "center", gap: 24, marginTop: 40}}>
          {STATE_CHIPS.map(([chip, at], i) => {
            const lit = f >= at;
            const pop = clamp(f, [at, at + 8, at + 14], [0.94, 1.04, 1]);
            return <React.Fragment key={chip}>
              {i > 0 && <span style={{opacity: lit ? 1 : 0.25}}>{svgGlyph(GLYPH_ARROW_RIGHT, C.mint, 40, 2)}</span>}
              <span style={{fontSize: 42, fontWeight: 800, letterSpacing: -0.8, padding: "18px 34px", borderRadius: 999, scale: lit ? `${pop}` : "1",
                            background: lit ? "rgba(34,255,194,.16)" : "rgba(255,255,255,.05)",
                            border: `2px solid ${lit ? "rgba(34,255,194,.7)" : "rgba(255,255,255,.14)"}`,
                            color: lit ? C.mint : "rgba(255,255,255,.34)"}}>{chip}</span>
            </React.Fragment>;
          })}
        </div>
        <div style={{marginTop: 54, display: "flex", flexDirection: "column", gap: 26}}>
          {STATE_GATES.map(([gate, at]) => {
            const o = ramp(f, [at, at + 22], [0, 1]);
            return <div key={gate} style={{display: "flex", alignItems: "flex-start", gap: 18, opacity: o}}>
              <span style={{marginTop: 7}}>{svgGlyph(GLYPH_ARROW_RIGHT, C.mint, 30, 2)}</span>
              <span style={{fontSize: 36, fontWeight: 620, lineHeight: 1.35, color: "rgba(255,255,255,.86)"}}>{gate}</span>
            </div>;
          })}
        </div>
        <div style={{marginTop: 54, fontSize: 28, lineHeight: 1.4, color: "rgba(255,255,255,.5)", opacity: ramp(f, [386, 410], [0, 1])}}>
          Every threshold lives in one file, tuned against recorded clips, not guessed.
        </div>
      </div>
    </AbsoluteFill>
  </AbsoluteFill>;
};

// ---------------------------------------------------------------------------
// Beat 4 -- The privacy architecture, frames 1140-1568. Three claims, each
// with its enforcement underneath in smaller muted type. The claim is only
// worth stating because the line under it says what stops it from drifting.
//
// The permitted-claims table words the third claim "AES-256-GCM". That token
// carries two hyphens, and the standing rule for on screen copy is to rewrite
// rather than to substitute punctuation, so the cipher is named in full:
// same algorithm, same key length, no dash.
// ---------------------------------------------------------------------------
const PRIVACY_CLAIMS: [React.ReactNode, string, string][] = [
  [GLYPH_CPU, "Pose estimation runs on a Hub inside the building.",
    "YOLO11, ONNX Runtime, GPU accelerated. No third party AI service sees a resident."],
  [GLYPH_CAMERA, "Frames are discarded in memory.",
    "A test intercepts file writes and network calls during frame processing. If that ever changes, the build fails."],
  [L_LOCK, "Face data is encrypted on the Hub.",
    "AES in Galois Counter Mode with 256 bit keys. The key never leaves the building. A full cloud breach yields ciphertext and no keys."],
];
const PrivacyBeat = () => {
  const f = useCurrentFrame();
  const content = ramp(f, [386, 404], [1, 0]);
  const plate = ramp(f, [404, 428], [1, 0]);
  return <AbsoluteFill style={{opacity: plate}}>
    <AbsoluteFill style={{background: C.dark}} />
    <AbsoluteFill style={{opacity: content}}>
      <div style={{position: "absolute", left: 200, top: 168, width: 1520}}>
        <div style={{fontSize: 20, fontWeight: 800, letterSpacing: 3.4, color: C.mint, opacity: ramp(f, [6, 26], [0, 1])}}>PRIVACY BY ARCHITECTURE</div>
        {PRIVACY_CLAIMS.map(([glyph, claim, enforcement], i) => {
          const at = 24 + i * 96;
          const o = ramp(f, [at, at + 22], [0, 1]);
          const y = clamp(f, [at, at + 22], [16, 0]);
          const sub = ramp(f, [at + 16, at + 40], [0, 1]);
          return <div key={claim} style={{display: "flex", gap: 26, marginTop: i === 0 ? 46 : 54, opacity: o, translate: `0 ${y}px`}}>
            <span style={{marginTop: 10}}>{svgGlyph(glyph, C.mint, 44, 1.9)}</span>
            <div style={{flex: 1}}>
              <div style={{fontSize: 46, fontWeight: 780, letterSpacing: -1.2, lineHeight: 1.2, color: "white"}}>{claim}</div>
              <div style={{fontSize: 27, lineHeight: 1.45, color: "rgba(255,255,255,.52)", marginTop: 12, maxWidth: 1240, opacity: sub}}>{enforcement}</div>
            </div>
          </div>;
        })}
        <div style={{marginTop: 66, paddingLeft: 26, borderLeft: `5px solid ${C.mint}`, fontSize: 44, fontWeight: 800, letterSpacing: -1.2, color: C.mint,
                     opacity: ramp(f, [320, 346], [0, 1])}}>You cannot steal what was never sent.</div>
      </div>
    </AbsoluteFill>
  </AbsoluteFill>;
};

// A left-column explanatory line for the app beats. The reel's app beats carry
// one story line each; a standalone film has to say how the screen works, so
// each beat gets a short stack of these instead.
const ExplainLine = ({at, children, lead}: {at: number; children: React.ReactNode; lead?: boolean}) => {
  const f = useCurrentFrame();
  const o = ramp(f, [at, at + 22], [0, 1]);
  const y = clamp(f, [at, at + 22], [14, 0]);
  return <div style={{display: "flex", gap: 16, marginTop: 26, opacity: o, translate: `0 ${y}px`}}>
    <span style={{marginTop: 6}}>{svgGlyph(L_CHECK_CIRCLE, C.primary, 30, 2.1)}</span>
    <span style={{flex: 1, fontSize: lead ? 33 : 30, fontWeight: lead ? 700 : 400, lineHeight: 1.38, color: lead ? C.foreground : C.foregroundMuted}}>{children}</span>
  </div>;
};

// ---------------------------------------------------------------------------
// Beat 5 -- MeridianCare, frames 1544-2016. The reel's Care beat with the
// explanatory column added: the urgent modal arrives, is acknowledged, moves
// to responding, and the response note lands.
// ---------------------------------------------------------------------------
const CareBeat = () => {
  const raw = useCurrentFrame();
  const local = raw - E.careOffset;
  const beat = ramp(raw, [4, 30, 452, 472], [0, 1, 1, 0]);
  const clock = warp(local, [16, 60, 150, 210, 280, 350, 410], [0, 24, 40, 62, 92, 118, 142]);
  return <Background opacity={beat}>
    <div style={{position: "absolute", left: 150, top: 132, width: 880}}>
      <AppName>MeridianCare</AppName>
      <AudienceLine>For caregivers working the night shift</AudienceLine>
      <div style={{marginTop: 34}}>
        <ExplainLine at={40} lead>Every alert is one tap from acknowledged.</ExplainLine>
        <ExplainLine at={170}>Five states, enforced on the server, not in the app: acknowledged, responding, resolved, dismissed as a false alarm, escalated.</ExplainLine>
        <ExplainLine at={330}>Response times are logged, so a facility can prove them.</ExplainLine>
      </div>
    </div>
    <CareDevice local={clock} style={{position: "absolute", right: 220, top: 55}} />
  </Background>;
};

// ---------------------------------------------------------------------------
// Beat 6 -- MeridianHub, frames 1996-2526. The longest beat, because it is the
// least expected and the hardest to explain in a sentence: the action grid,
// the request, the live help status and the reminders, then the same physical
// device swapping to visitor verification.
// ---------------------------------------------------------------------------
const HubSub = ({lines}: {lines: [string, number][]}) => {
  const f = useCurrentFrame();
  return <>{lines.map(([line, at]) => (
    <div key={line} style={{marginTop: 14, opacity: ramp(f, [at, at + 22], [0, 1])}}>{line}</div>
  ))}</>;
};
const HubBeat = () => {
  const raw = useCurrentFrame();
  const local = raw - E.hubOffset;
  const bgOpacity = ramp(raw, [300, 320], [1, 0]);
  const contentOpacity = ramp(raw, [0, 16], [0, 1]);
  // The panel leaves to the left as the visitor card arrives from the right.
  const panelX = clamp(local, [286, 300], [0, -40]);
  const clock = warp(local, [20, 120, 150, 200, 230, 280], [0, 24, 40, 60, 76, 104]);
  return <HubFrame title="The resident is not only watched. She can act."
                   sub={<HubSub lines={[["Request help, call family, or raise an emergency, from the room.", 74],
                                        ["When a fall is detected, the request is raised for her automatically.", 184]]} />}
                   bgOpacity={bgOpacity} contentOpacity={contentOpacity} panelX={panelX}>
    <HubHelpPanel local={clock} />
  </HubFrame>;
};
const VisitorBeat = () => {
  const raw = useCurrentFrame();
  const local = raw - E.visitorOffset;
  const bgOpacity = ramp(raw, [208, 230], [1, 0]);
  const contentOpacity = ramp(raw, [0, 16], [0, 1]);
  const panelX = clamp(raw, [0, 14], [40, 0]);
  const clock = warp(local, [10, 60, 120, 165, 205], [0, 22, 60, 92, 115]);
  return <HubFrame title="An unrecognised visitor asks her, not a screen somewhere else."
                   sub={<HubSub lines={[["If she says no, the care team is told.", 120]]} />}
                   bgOpacity={bgOpacity} contentOpacity={contentOpacity} panelX={panelX}>
    <HubVisitorPanel local={clock} />
  </HubFrame>;
};

// ---------------------------------------------------------------------------
// Beat 7 -- MeridianFamily, frames 2504-2916. Today, then a real tab change to
// Updates. The third explanatory line is the honest answer to the meals
// question, and it holds on screen long enough to be read twice.
// ---------------------------------------------------------------------------
const FamilyBeat = () => {
  const raw = useCurrentFrame();
  const local = raw - E.familyOffset;
  const bgOpacity = ramp(raw, [394, 412], [1, 0]);
  const contentOpacity = ramp(raw, [0, 16], [0, 1]);
  const clock = warp(local, [12, 100, 165, 215, 275, 335, 385], [0, 22, 40, 62, 80, 110, 152]);
  return <Background opacity={bgOpacity}>
    <div style={{position: "absolute", left: 150, top: 140, width: 880, opacity: contentOpacity}}>
      <AppName>MeridianFamily</AppName>
      <AudienceLine>For worried families</AudienceLine>
      <div style={{marginTop: 34}}>
        <ExplainLine at={40} lead>Families get what actually happened, not a reassurance.</ExplainLine>
        <ExplainLine at={150}>Movement patterns compared against the resident&rsquo;s own baseline, never against a stranger&rsquo;s.</ExplainLine>
        <ExplainLine at={270} lead>What the system cannot observe, it does not report.</ExplainLine>
      </div>
    </div>
    <FamilyDevice local={clock} style={{position: "absolute", right: 230, top: 55, opacity: contentOpacity}} />
  </Background>;
};

// ---------------------------------------------------------------------------
// Beat 8 -- What is actually proven, frames 2898-3334. Every row is quoted
// from the permitted-claims table with the bound its source states, and the
// closing line is the point of the beat. The two figures come from
// benchmarks/alert_latency_2026-08-07.md: the conservative Hub to loopback ack
// totals, and the validated 12 stream operating limit. Neither is restated
// without the sentence that says what the measurement excludes.
// ---------------------------------------------------------------------------
const EVIDENCE: [React.ReactNode, string, string][] = [
  [L_CLOCK,
    "Hub detection to ingest acknowledgement, p95: 2.0s confirmed, 3.2s suspected.",
    "Camera capture, network and phone display are not included."],
  [GLYPH_CPU,
    "12 simultaneous 480p streams, 15.2 FPS per room minimum, measured on one laptop.",
    "Synthetic streams. Decode cost is not in that figure."],
  [L_LOCK,
    "Frames are never written to disk and never uploaded.",
    "Enforced by a test that fails the build if it ever changes."],
  [L_WIFI_OFF,
    "If the internet drops, detection keeps running and alerts queue locally, then deliver exactly once.",
    "Enforced by the same test file."],
  [L_CHECK_CIRCLE,
    "214 tests.",
    "Evidence of discipline, not a claim about quality."],
];
const ProvenBeat = () => {
  const raw = useCurrentFrame();
  const f = raw - E.provenOffset;
  const toNavy = ramp(raw, [426, 434], [0, 1]);
  return <Background>
    {/* The block is sized so the closing line still clears the 108px
        title-safe margin at the bottom of a 1080 frame. */}
    <div style={{position: "absolute", left: 220, top: 76, width: 1480}}>
      <Card style={{borderRadius: 24, padding: 42, opacity: ramp(f, [0, 18], [0, 1])}}>
        <div style={{fontSize: 20, fontWeight: 800, letterSpacing: 3.4, color: C.primary}}>MEASURED IN THIS REPOSITORY</div>
        <div style={{fontSize: 52, fontWeight: 820, letterSpacing: -2, marginTop: 12}}>What is actually proven</div>
        {EVIDENCE.map(([glyph, claim, bound], i) => {
          const at = 30 + i * 62;
          const o = ramp(f, [at, at + 20], [0, 1]);
          const y = clamp(f, [at, at + 20], [12, 0]);
          const sub = ramp(f, [at + 12, at + 32], [0, 1]);
          return <div key={claim} style={{display: "flex", gap: 22, paddingTop: 18, marginTop: 18, borderTop: `1px solid ${C.border}`, opacity: o, translate: `0 ${y}px`}}>
            <span style={{marginTop: 4}}>{svgGlyph(glyph, C.primary, 34, 2)}</span>
            <div style={{flex: 1}}>
              <div style={{fontSize: 32, fontWeight: 700, lineHeight: 1.24, letterSpacing: -0.6}}>{claim}</div>
              <div style={{fontSize: 22, lineHeight: 1.35, color: C.foregroundMuted, marginTop: 7, opacity: sub}}>{bound}</div>
            </div>
          </div>;
        })}
      </Card>
      <div style={{marginTop: 26, paddingLeft: 24, borderLeft: `6px solid ${C.primaryAlt}`, fontSize: 32, fontWeight: 700, lineHeight: 1.35,
                   letterSpacing: -0.6, color: C.primary, opacity: ramp(f, [340, 366], [0, 1])}}>
        Everything above is measured in this repository. The things we have not measured, we do not claim.
      </div>
    </div>
    <AbsoluteFill style={{background: C.deckNavy, opacity: toNavy, pointerEvents: "none"}} />
  </Background>;
};

// The score is the reel's, re-enveloped for two minutes: present under the
// night room, pulled back for the fall so the track never feels cheerful over
// a person on the floor, steady under the explanation, warmest through the app
// beats, quietest under the evidence card where the copy has to be read, then
// lifted once for the close.
const musicVolume = (f: number) =>
  interpolate(f, [0, 30, 330, 420, 690, 820, 1560, 1620, 2880, 2940, 3300, 3350, 3592],
    [0, 0.22, 0.22, 0.14, 0.14, 0.3, 0.3, 0.38, 0.38, 0.3, 0.3, 0.4, 0],
    {extrapolateLeft: "clamp", extrapolateRight: "clamp"});

export const MeridianExplainer = () => <AbsoluteFill style={{background: C.dark}}>
  <Audio src={staticFile("music.mp3")} volume={musicVolume} />
  <Sequence from={E.openFrom} durationInFrames={E.openDur} style={{zIndex: 12}}><ColdOpen /></Sequence>
  <Sequence from={E.fallFrom} durationInFrames={E.fallDur} style={{zIndex: 11}}><FallBeat /></Sequence>
  <Sequence from={E.pipeFrom} durationInFrames={E.pipeDur} style={{zIndex: 10}}><DetectionBeat /></Sequence>
  <Sequence from={E.privacyFrom} durationInFrames={E.privacyDur} style={{zIndex: 9}}><PrivacyBeat /></Sequence>
  <Sequence from={E.careFrom} durationInFrames={E.careDur} style={{zIndex: 8}}><CareBeat /></Sequence>
  <Sequence from={E.hubFrom} durationInFrames={E.hubDur} style={{zIndex: 7}}><HubBeat /></Sequence>
  <Sequence from={E.visitorFrom} durationInFrames={E.visitorDur} style={{zIndex: 6}}><VisitorBeat /></Sequence>
  <Sequence from={E.familyFrom} durationInFrames={E.familyDur} style={{zIndex: 5}}><FamilyBeat /></Sequence>
  <Sequence from={E.provenFrom} durationInFrames={E.provenDur} style={{zIndex: 4}}><ProvenBeat /></Sequence>
  <Sequence from={E.closeFrom} durationInFrames={E.closeDur} style={{zIndex: 15}}>
    <EndCard footer="Faster help. Less uncertainty. More dignity." footerIn={[70, 100]} />
  </Sequence>
  <BrandMark darkEnd={E.darkEnd} fade={[330, 350, 3312, 3330]} />
</AbsoluteFill>;
