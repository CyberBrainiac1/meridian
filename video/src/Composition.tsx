import React from "react";
import {
  AbsoluteFill,
  Audio,
  Easing,
  interpolate,
  interpolateColors,
  OffthreadVideo,
  Sequence,
  staticFile,
  useCurrentFrame,
} from "remotion";

const C = {
  primary: "#0369A1", primaryAlt: "#0891B2", success: "#047857", warning: "#92400E",
  destructive: "#991B1B", foreground: "#0C4A6E", muted: "#E7EFF5", border: "#E0F2FE",
  background: "#F0F9FF", surface: "#FFFFFF", foregroundMuted: "#2F5D77", dark: "#05060A", mint: "#22FFC2",
  deckNavy: "#0B111B", appName: "#08131B",
};
const ease = Easing.bezier(0.16, 1, 0.3, 1);
const clamp = (value: number, input: number[], output: number[]) => interpolate(value, input, output, {extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: ease});
// Motion gets the out-expo above; opacity does not. That curve is ~90% done a
// third of the way through, which over a 6-10 frame dissolve reads as a cut --
// it put an 83-point luminance step on the first frame of the 163-170 dip and
// a 150-point one on the fade to deck navy. Every transition envelope is
// linear so the ramp is spread evenly over the frames the script allots it.
const ramp = (value: number, input: number[], output: number[]) => interpolate(value, input, output, {extrapolateLeft: "clamp", extrapolateRight: "clamp"});

// Inline SVG rather than decorative Unicode. Remotion renders in headless
// Chromium with whatever fonts the machine happens to have, and glyphs like
// U+2301 fell back to a bare "~" on this box while U+2659 rendered as a chess
// pawn. Paths always draw.
const svgIcon = (d: string, color: string, size = 30, filled = true) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{flexShrink: 0, display: "block"}}
       fill={filled ? color : "none"} stroke={filled ? "none" : color} strokeWidth={filled ? 0 : 2.2}
       strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d={d} />
  </svg>
);
const PATH_STATUS = "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm4.7 7.7-5.6 5.6a1 1 0 0 1-1.4 0l-2.4-2.4a1 1 0 1 1 1.4-1.4l1.7 1.7 4.9-4.9a1 1 0 0 1 1.4 1.4Z";
const PATH_VISITOR = "M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10Zm0 2c-5 0-9 2.5-9 5.5V22h18v-2.5c0-3-4-5.5-9-5.5Z";
const alertIcon = (color: string, size = 30) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{flexShrink: 0, display: "block"}}
       fill="none" stroke={color} strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M10.3 3.2 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.2a2 2 0 0 0-3.4 0Z" />
    <path d="M12 9v4" /><path d="M12 17h.01" />
  </svg>
);
// Same rule as svgIcon, but for glyphs that need more than one element (the
// pipeline's cpu and camera, the reminder icons). Stroked, never filled.
const svgGlyph = (children: React.ReactNode, color: string, size: number, strokeWidth = 1.8) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{flexShrink: 0, display: "block"}}
       fill="none" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    {children}
  </svg>
);
const GLYPH_CAMERA = <><path d="M14.5 5h-5L7.5 8H4a1.5 1.5 0 0 0-1.5 1.5v9A1.5 1.5 0 0 0 4 20h16a1.5 1.5 0 0 0 1.5-1.5v-9A1.5 1.5 0 0 0 20 8h-3.5L14.5 5Z" /><circle cx={12} cy={13.2} r={3.4} /></>;
const GLYPH_CPU = <>
  <rect x={7} y={7} width={10} height={10} rx={1.4} /><rect x={10} y={10} width={4} height={4} rx={0.6} />
  {[8, 12, 16].map((p) => <React.Fragment key={p}>
    <path d={`M${p} 7V3.6`} /><path d={`M${p} 17v3.4`} /><path d={`M7 ${p}H3.6`} /><path d={`M17 ${p}h3.4`} />
  </React.Fragment>)}
</>;
const GLYPH_ACTIVITY = <path d="M3 12.5h4l2.2-7.5 4 15 2.2-7.5H21" />;
const GLYPH_BELL = <><path d="M6.5 8.5a5.5 5.5 0 0 1 11 0c0 4.6 1.8 5.7 1.8 5.7H4.7s1.8-1.1 1.8-5.7Z" /><path d="M10.3 18.2a1.9 1.9 0 0 0 3.4 0" /></>;
const GLYPH_PILL = <><path d="M10.5 20.5 3.5 13.5a5 5 0 0 1 7-7l7 7a5 5 0 0 1-7 7Z" /><path d="M7 10 14 17" /></>;
const GLYPH_MEAL = <><path d="M7 2v6a2.5 2.5 0 0 0 5 0V2" /><path d="M9.5 2v6" /><path d="M9.5 8v14" /><path d="M17 2c-2 0-3.5 2-3.5 4.5S15 11 17 11s3.5-2 3.5-4.5S19 2 17 2Z" /><path d="M17 11v11" /></>;
const GLYPH_WALK = <><circle cx={13} cy={4.2} r={2.2} /><path d="M13 6.6v6" /><path d="M13 12.6 10 21" /><path d="M13 12.6 16.4 19.6" /><path d="M13 8.4 9.6 10.8" /><path d="M13 8.4 16.8 10.6" /></>;
const GLYPH_CHECK = <path d="M4.5 12.5 9.5 17.5 19.5 6.5" />;

// ---------------------------------------------------------------------------
// Cut map (870 frames @ 30fps). Sequences overlap by the length of their
// transition so nothing ever unmounts onto an empty frame. Stacking is set
// with an explicit zIndex per Sequence, descending with time, so the OUTGOING
// beat always sits above the incoming one: the outgoing beat fades its own
// background out and reveals the next beat, which is already opaque
// underneath. That is what keeps every dissolve free of a flash frame.
//
// Revision 2 inserted the 120-frame pipeline beat without moving the 870-frame
// cap: every app beat gave up trailing HOLD only, so no action timing inside
// any beat changed (last action per beat: Care local 140, Hub help 95, Hub
// visitor 110, Family 145 -- all still land before their new end).
//
//   Fall        0-154   (beat 0-155,   no dip: the pipeline is the same dark)
//   Pipeline  155-274   (beat 155-275, 7f fade out 268-275)
//   Care      268-434   (beat 275-430, 10f cross-dissolve 425-435)
//   Hub help  425-549   (beat 430-545, in-device slide swap 540-550)
//   Hub visit 540-679   (beat 545-675, 10f cross-dissolve 670-680)
//   Family    670-841   (beat 675-840, 6f fade to deck navy 836-842)
//   End card  840-869
// ---------------------------------------------------------------------------
const T = {
  fallEnd: 155,
  pipeFrom: 155, pipeDur: 120,
  // Where the reel stops being dark: the brand mark's tint flips here, at the
  // darkest frame of the pipeline -> MeridianCare handoff.
  darkEnd: 272,
  careFrom: 268, careDur: 167, careOffset: 7,
  hubFrom: 425, hubDur: 125, hubOffset: 5,
  visitorFrom: 540, visitorDur: 140, visitorOffset: 5,
  familyFrom: 670, familyDur: 172, familyOffset: 5,
  endFrom: 840, endDur: 30,
};

// Persistent brand bug, top right. Sits above every beat so the reel is
// attributable on any frame someone screenshots. Tint flips with the beat
// underneath it: mint over the dark pose footage, brand blue over the light
// app screens. Hidden only on the end card, which already carries the mark
// full size.
const BrandMark = () => {
  const f = useCurrentFrame();
  const onDark = f < T.darkEnd;
  const tint = onDark ? C.mint : C.primary;
  // Fade out just before the end card takes over, so the two marks never
  // appear at once.
  const opacity = ramp(f, [0, 18, 826, 840], [0, 1, 1, 0]) * (onDark ? 0.92 : 0.8);
  return (
    <div style={{position: "absolute", top: 46, right: 56, zIndex: 20, opacity,
                 display: "flex", alignItems: "center", gap: 12, pointerEvents: "none"}}>
      {/* Same mark as the end card and the deck title slide: M-notched shield
          with the medical cross. NOT the MeridianHub app icon (house glyph) --
          that is a product icon, not the brand. */}
      <svg width={34} height={34} viewBox="0 0 1024 1024" aria-label="Meridian" style={{display: "block",
           filter: onDark ? "drop-shadow(0 2px 6px rgba(0,0,0,.65))" : "none"}}>
        <path d="M242 250 L420 196 L512 320 L604 196 L782 250 L782 540 C782 694 668 800 512 858 C356 800 242 694 242 540 Z"
              fill="none" stroke={tint} strokeWidth={62} strokeLinejoin="round" strokeLinecap="round" />
        <path d="M462 400 H562 V470 H632 V570 H562 V640 H462 V570 H392 V470 H462 Z" fill={tint} />
      </svg>
      <span style={{fontSize: 23, fontWeight: 800, letterSpacing: 3, color: tint,
                    textShadow: onDark ? "0 2px 6px rgba(0,0,0,.6)" : "none"}}>MERIDIAN</span>
    </div>
  );
};

const Panel = ({children, style}: {children: React.ReactNode; style?: React.CSSProperties}) => <div style={{background: C.surface, border: `1px solid ${C.border}`, borderRadius: 26, boxShadow: "0 18px 45px rgba(12,74,110,.11)", ...style}}>{children}</div>;
const Pill = ({children, color = C.primary}: {children: React.ReactNode; color?: string}) => <span style={{background: `${color}18`, color, borderRadius: 99, padding: "10px 16px", fontWeight: 750, fontSize: 20}}>{children}</span>;
// Tap affordance: a ring that expands out of the button centre and fades as it
// reaches full size. Without the fade the ring is still sitting on the button
// a second later, which reads as a rendering artefact rather than a press.
// color: the ring is white on the coloured buttons, but a reminder row is
// white-on-white, so that one presses in the success green instead.
const Ripple = ({size, opacity, color = "rgba(255,255,255,.7)"}: {size: number; opacity: number; color?: string}) => <span style={{position: "absolute", left: "50%", top: "50%", marginLeft: -size / 2, marginTop: -size / 2, width: size, height: size, borderRadius: "50%", border: `3px solid ${color}`, opacity, pointerEvents: "none"}} />;
// The app name outranks the tagline: it is the thing the audience must retain.
const AppName = ({children}: {children: React.ReactNode}) => <div style={{fontSize: 84, fontWeight: 880, color: C.appName, letterSpacing: -3.2, lineHeight: 1}}>{children}</div>;
// Who this screen belongs to, as part of the header lockup itself -- a
// first-time viewer reads "MeridianFamily / FOR WORRIED FAMILIES" as one
// unit. (Was a small pill; user direction: make it header-scale.)
const AudienceLine = ({children}: {children: React.ReactNode}) => <div style={{marginTop: 16, paddingLeft: 18, borderLeft: `6px solid ${C.primaryAlt}`, fontSize: 38, fontWeight: 830, color: C.primary, letterSpacing: -0.4}}>{children}</div>;
// The causal thread. Each beat's sub-line states how it follows from the
// fall the viewer just watched, so the reel reads as one story instead of
// four unrelated screens.
const StoryLine = ({children}: {children: React.ReactNode}) => <div style={{marginTop: 30, fontSize: 31, color: C.foregroundMuted, lineHeight: 1.4}}>{children}</div>;

const Device = ({children, label}: {children: React.ReactNode; label: string}) => <div aria-label={label} style={{width: 560, height: 970, padding: 15, background: "#102833", borderRadius: 64, boxShadow: "0 40px 90px rgba(0,0,0,.28)", border: "3px solid #31505d"}}>
  <div style={{height: "100%", overflow: "hidden", borderRadius: 49, background: C.background, position: "relative"}}>
    <div style={{position: "absolute", zIndex: 4, top: 14, left: "50%", marginLeft: -62, width: 124, height: 29, borderRadius: 99, background: "#102833"}} />
    {children}
  </div>
</div>;

const Background = ({children, opacity = 1}: {children: React.ReactNode; opacity?: number}) => <AbsoluteFill style={{background: `radial-gradient(circle at 18% 18%, #dff5ff 0, transparent 32%), radial-gradient(circle at 84% 82%, #d9fbef 0, transparent 30%), ${C.background}`, color: C.foreground, overflow: "hidden", opacity}}>{children}</AbsoluteFill>;

const FullVideo = ({src, startFrom, scale = 1, filter, playbackRate}: {src: string; startFrom: number; scale?: number; filter?: string; playbackRate?: number}) => <OffthreadVideo src={staticFile(src)} startFrom={startFrom} playbackRate={playbackRate} style={{width: "100%", height: "100%", objectFit: "cover", scale, filter}} />;

// Both lines live in ONE bottom-anchored stack. Previously they were two
// independently positioned elements, which let the second drift into the
// title-safe margin -- on 1080p that is 108px, and it was sitting at 60. The
// stack's bottom edge is now at 150, so the whole caption clears the safe area
// and the two lines read as one statement.
// The bridge is what tells a first-time viewer why the pipeline (and then the
// phone screens) follow: the video stays, the alert travels. It is carried
// across the 155 cut by the pipeline beat and faded there, because beats 1 and
// 2 are one continuous dark shot.
const DarkCaption = ({opacity, y, privacy, bridge}: {opacity: number; y: number; privacy: number; bridge: number}) => (
  <div style={{position: "absolute", left: 120, bottom: 150, translate: `0 ${y}px`, opacity}}>
    <div style={{opacity: privacy, color: "white", fontSize: 56, fontWeight: 760, letterSpacing: -1.5, padding: "22px 30px", borderLeft: `5px solid ${C.mint}`, background: "rgba(5,6,10,.72)", borderRadius: "0 16px 16px 0"}}>No video ever leaves the building.</div>
    <div style={{opacity: bridge, marginTop: 16, marginLeft: 5, color: C.mint, fontSize: 37, fontWeight: 700, letterSpacing: -0.5, padding: "0 30px"}}>Only the alert does — here is where it goes.</div>
  </div>
);

// Beat 1 -- frames 0-155. It no longer dips out: the pipeline beat that follows
// is the same near-black surface, so the cut at 155 is invisible and the only
// luminance handoff in the dark half of the reel is at 268-275.
// startFrom=58 on both clips puts the impact (clip frame ~143) at beat frame
// ~85, which leaves 30 frames of upright walking for the skeleton to lock on
// in front of the audience.
const CLIP_START = 58;
const FallAndSkeleton = () => {
  const f = useCurrentFrame();
  // Both layers MUST share one scale ramp. preprocess_frame does a plain
  // resize rather than a letterbox, so pose coordinates map linearly onto the
  // full source frame and the skeleton lands exactly on her body -- but only
  // while the two layers are transformed identically.
  const zoom = clamp(f, [0, 165], [1.02, 1.1]);
  // Skeleton locks on while she is still upright, so the fall is watched being
  // tracked rather than revealed after the fact.
  const skeleton = ramp(f, [18, 48], [0, 1]);
  // Only after the fall does the footage fall away, leaving pose alone on
  // screen for the privacy line.
  const videoBrightness = ramp(f, [100, 132], [0.56, 0.05]);
  const caption = ramp(f, [96, 120], [0, 1]);
  const captionY = clamp(f, [96, 120], [14, 0]);
  const bridge = ramp(f, [128, 148], [0, 1]);
  // 12f fade up from black and no fade out: the pipeline beat picks the frame
  // up unchanged at 155.
  const beat = ramp(f, [0, 12], [0, 1]);
  return <AbsoluteFill style={{background: C.dark, opacity: beat}}>
    <FullVideo src="fall.mp4" startFrom={CLIP_START} scale={zoom} filter={`brightness(${videoBrightness}) saturate(.72) contrast(1.08)`} />
    {/* screen blend drops the skeleton render's black background to fully
        transparent, so the strokes composite straight onto her. */}
    <AbsoluteFill style={{opacity: skeleton, mixBlendMode: "screen"}}><FullVideo src="skeleton.mp4" startFrom={CLIP_START} scale={zoom} /></AbsoluteFill>
    <AbsoluteFill style={{background: "radial-gradient(circle, transparent 44%, rgba(0,0,0,.32))"}} />
    <DarkCaption opacity={1} y={captionY} privacy={caption} bridge={bridge} />
  </AbsoluteFill>;
};

// Beat 2 -- frames 155-275 (local 0-120). The connective tissue: how a person
// on the floor becomes a phone buzzing in a caregiver's pocket, which the reel
// previously asked the viewer to infer. Ported from the imported Claude Design
// animation (meridian-scene.jsx, NODES) -- its node styling, labels and subs.
//
// Deliberately NOT ported: that file's assets/img-pose-skeleton.png. It is a
// pre-rendered still the browser harness fell back to because it could not
// decode our clip. Remotion decodes it fine, so the pose on screen here is the
// real model output from skeleton.mp4, dimmed to 0.12 as context under the
// diagram. Baking in a picture of a skeleton would fake the one thing in this
// reel that is genuinely ours.
const PIPE_X = [220, 700, 1180, 1660];
const PIPE_Y = 660;
const PIPE_NODES = [
  {at: 8, label: "CAMERA", sub: "Continuous on-site capture", glyph: GLYPH_CAMERA},
  // "17-point" stays numeric. The no-digits rule targets METRICS a judge would
  // ask us to source -- latency, room counts, ARR. This is a product
  // descriptor, it is the deck's own slide-6 wording, and "Seventeen-point"
  // reads as an affectation.
  {at: 32, label: "ON-DEVICE POSE", sub: "17-point skeleton, no cloud round-trip", glyph: GLYPH_CPU},
  {at: 60, label: "FALL STATE MACHINE", sub: "", glyph: GLYPH_ACTIVITY},
  {at: 90, label: "ALERT DISPATCHED", sub: "Only the alert leaves the room", glyph: GLYPH_BELL},
];
// Node 3 states the machine in words where the other nodes carry a sub line.
const PIPE_CHIPS: [string, number][] = [["Normal", 66], ["Candidate", 76], ["Confirmed", 86]];
const PipelineBeat = () => {
  const local = useCurrentFrame();
  // The 268-275 hand-off, in two stages inside the seven frames the script
  // allots it: the diagram clears first (268-272), then the dark plate under it
  // fades (270-275) and reveals MeridianCare's light surface, which is rising
  // from 271. Fading plate and diagram together instead put the nodes on top of
  // a half-visible phone, which read as a double exposure rather than a cut.
  const content = ramp(local, [113, 117], [1, 0]);
  const plate = ramp(local, [115, 120], [1, 0]);
  // Beat 1's push-in keeps running on the same clock so the pose does not jump
  // at the cut; it clamps out at frame 165 and the layer then sits still.
  const zoom = clamp(T.pipeFrom + local, [0, 165], [1.02, 1.1]);
  const skeleton = ramp(local, [0, 18], [1, 0.12]);
  const caption = ramp(local, [8, 24], [1, 0]);
  // One shake on arrival, ~0.4s of decay. Guarded so the decay ramp's clamped
  // left edge cannot rotate the bell before the node exists.
  const bell = local >= 90 ? 8 * ramp(local, [90, 102], [1, 0]) * Math.sin((local - 90) * 0.9) : 0;
  return <AbsoluteFill style={{opacity: plate}}>
    <AbsoluteFill style={{background: C.dark}} />
    <AbsoluteFill style={{opacity: content}}>
    {/* startFrom lands on clip frame 213 -- beat 1's last frame plus one, and
        inside the clip's 80 held frames. playbackRate .5 walks 120 comp frames
        over 60 clip frames so the request never runs past the 291-frame clip
        while staying on the held floor pose. */}
    <AbsoluteFill style={{opacity: skeleton, mixBlendMode: "screen"}}><FullVideo src="skeleton.mp4" startFrom={CLIP_START + T.fallEnd} scale={zoom} playbackRate={0.5} /></AbsoluteFill>
    <AbsoluteFill style={{background: "radial-gradient(circle, transparent 44%, rgba(0,0,0,.32))"}} />
    {[0, 1, 2].map((i) => {
      // Each connector starts 9f after its left node lands and wipes for 15f.
      // The unlit track fades in with its left node -- drawn from frame 0 it was
      // three grey lines popping onto the cut before any node existed.
      const start = PIPE_NODES[i].at + 9;
      const left = PIPE_X[i] + 56;
      const width = PIPE_X[i + 1] - 56 - left;
      const wipe = clamp(local, [start, start + 15], [0, 1]);
      const track = ramp(local, [PIPE_NODES[i].at, PIPE_NODES[i].at + 9], [0, 1]);
      return <div key={left} style={{position: "absolute", left, top: PIPE_Y - 1, width, height: 2, background: "rgba(255,255,255,.14)", opacity: track}}>
        <div style={{height: "100%", width: `${wipe * 100}%`, background: C.mint}} />
      </div>;
    })}
    {PIPE_NODES.map((node, i) => {
      const scale = clamp(local, [node.at, node.at + 6, node.at + 11], [0.8, 1.06, 1]);
      const opacity = ramp(local, [node.at, node.at + 9], [0, 1]);
      return <div key={node.label} style={{position: "absolute", left: PIPE_X[i] - 125, top: PIPE_Y - 90, width: 250, textAlign: "center", opacity, scale}}>
        <div style={{width: 96, height: 96, borderRadius: "50%", margin: "0 auto 18px", display: "flex", alignItems: "center", justifyContent: "center", background: "rgba(34,255,194,.08)", border: "1.5px solid rgba(34,255,194,.55)", rotate: `${i === 3 ? bell : 0}deg`}}>
          {svgGlyph(node.glyph, C.mint, 40)}
        </div>
        <div style={{fontSize: 17, fontWeight: 800, letterSpacing: 1.6, color: C.mint}}>{node.label}</div>
        {node.sub
          ? <div style={{fontSize: 14, color: "rgba(255,255,255,.5)", marginTop: 8, lineHeight: 1.35}}>{node.sub}</div>
          : <div style={{display: "flex", gap: 6, justifyContent: "center", marginTop: 12}}>{PIPE_CHIPS.map(([chip, at]) => {
              const lit = local >= at;
              return <span key={chip} style={{fontSize: 14, fontWeight: 700, padding: "4px 8px", borderRadius: 99, whiteSpace: "nowrap",
                                              background: lit ? "rgba(34,255,194,.18)" : "rgba(255,255,255,.06)", color: lit ? C.mint : "rgba(255,255,255,.4)"}}>{chip}</span>;
            })}</div>}
      </div>;
    })}
    {/* Beat 1's bridge line rides across the cut and hands off to node 4's
        "Only the alert leaves the room". The echo is the point. */}
    <DarkCaption opacity={caption} y={0} privacy={1} bridge={1} />
    </AbsoluteFill>
  </AbsoluteFill>;
};

// Beat 3 -- frames 275-430 (local 0-155). Mounted seven frames early, because
// this is the only beat whose background fades IN as well as out: it receives
// the pipeline's 268-275 fade-out, so the light surface has to be already
// rising underneath while the dark plate above it goes.
const CareScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.careOffset;
  // In from 271 (the frame the pipeline's plate starts clearing) to 285; out on
  // the 425-435 cross-dissolve into MeridianHub.
  const beat = ramp(raw, [3, 17, 157, 167], [0, 1, 1, 0]);
  const phoneY = clamp(local, [0, 14], [24, 0]);
  const alertY = clamp(local, [8, 22], [-80, 0]);
  const alertIn = ramp(local, [8, 18], [0, 1]);
  const ackRipple = clamp(local, [55, 72], [0, 92]);
  const ackRippleFade = ramp(local, [64, 72], [1, 0]);
  const respRipple = clamp(local, [96, 112], [0, 92]);
  const respRippleFade = ramp(local, [104, 112], [1, 0]);
  const acknowledged = local >= 72;
  const responding = local >= 112;
  const screenY = clamp(local, [118, 140], [0, -145]);
  const responsePanel = ramp(local, [118, 140], [0, 1]);
  return <Background opacity={beat}><div style={{position: "absolute", left: 205, top: 150, width: 790}}>
    <AppName>MeridianCare</AppName>
    <AudienceLine>For night-shift caregivers</AudienceLine>
    <div style={{fontSize: 44, letterSpacing: -1.5, fontWeight: 780, marginTop: 26}}>Care, in sync.</div>
    <StoryLine>The instant Maggie falls, her care team knows.</StoryLine>
  </div><div style={{position: "absolute", right: 270, top: 55, translate: `0 ${phoneY}px`}}><Device label="MeridianCare caregiver alerts">
    <div style={{padding: "72px 28px 102px", height: "100%", translate: `0 ${screenY}px`}}>
      <h1 style={{fontSize: 42, margin: "4px 0 25px", letterSpacing: -1.2}}>Alerts</h1>
      <div style={{position: "relative", translate: `0 ${alertY}px`, opacity: alertIn}}>
        <Panel style={{padding: 22, borderLeft: `7px solid ${C.destructive}`}}><div style={{display: "flex", justifyContent: "space-between", alignItems: "center"}}><Pill color={C.destructive}>Emergency</Pill>{alertIcon(C.destructive, 26)}</div>
          <div style={{fontSize: 30, lineHeight: 1.22, fontWeight: 760, marginTop: 18}}>Maggie may need help in Room 101.</div>
          <div style={{fontSize: 22, marginTop: 12, color: C.foregroundMuted}}>Fall detected</div>
          {!acknowledged && <button style={{marginTop: 22, border: 0, width: "100%", padding: "17px", borderRadius: 17, color: "white", fontWeight: 800, fontSize: 24, background: C.primary, position: "relative", overflow: "hidden"}}>Acknowledge<Ripple size={ackRipple} opacity={ackRippleFade} /></button>}
          {acknowledged && <div style={{marginTop: 22}}><Pill color={responding ? C.success : C.warning}>{responding ? "Responding" : "Acknowledged"}</Pill>{!responding && <button style={{marginTop: 18, border: 0, width: "100%", padding: "17px", borderRadius: 17, color: "white", fontWeight: 800, fontSize: 24, background: C.primary, position: "relative", overflow: "hidden"}}>Mark responding<Ripple size={respRipple} opacity={respRippleFade} /></button>}</div>}
        </Panel>
      </div>
      {responding && <Panel style={{padding: 22, marginTop: 20, opacity: responsePanel}}><div style={{fontSize: 21, fontWeight: 750, color: C.foregroundMuted}}>RESPONSE</div><div style={{fontSize: 28, fontWeight: 740, marginTop: 8}}>Care team is responding.</div></Panel>}
    </div>
    <div style={{position: "absolute", bottom: 0, left: 0, right: 0, height: 88, display: "flex", justifyContent: "space-around", alignItems: "center", background: "rgba(255,255,255,.95)", borderTop: `1px solid ${C.border}`, fontSize: 16, fontWeight: 700, color: C.foregroundMuted}}>{([["Alerts", PATH_STATUS, true], ["Handoff", "M4 5h16v3H4Zm0 5.5h16v3H4Zm0 5.5h11v3H4Z", false], ["Residents", PATH_VISITOR, false], ["Settings", "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Zm9.4 4a9.4 9.4 0 0 0-.15-1.6l2.05-1.55-2-3.46-2.4 1a9.5 9.5 0 0 0-2.77-1.6L15.8 2h-4l-.33 2.79a9.5 9.5 0 0 0-2.77 1.6l-2.4-1-2 3.46L6.35 10.4a9.5 9.5 0 0 0 0 3.2L4.3 15.15l2 3.46 2.4-1a9.5 9.5 0 0 0 2.77 1.6L11.8 22h4l.33-2.79a9.5 9.5 0 0 0 2.77-1.6l2.4 1 2-3.46-2.05-1.55c.1-.52.15-1.06.15-1.6Z", false]] as [string, string, boolean][]).map(([label, path, active]) => <span key={label} style={{display: "flex", flexDirection: "column", alignItems: "center", gap: 5, color: active ? C.primary : C.foregroundMuted}}>{svgIcon(path, active ? C.primary : C.foregroundMuted, 21)}{label}</span>)}</div>
  </Device></div></Background>;
};

// Shared Hub chrome. Beats 4 and 5 are the same physical device on stage, so
// they share the frame and only the card inside it changes -- which is exactly
// what the 540-550 swap has to sell. The panel geometry is deliberately shared:
// the help beat now carries the reminders checklist as well, so the header and
// paddings are tighter than they were and the card starts just under the brand
// mark, which is what buys that card its room.
const HubFrame = ({title, sub, bgOpacity, contentOpacity, panelX, children}: {title: string; sub: string; bgOpacity: number; contentOpacity: number; panelX: number; children: React.ReactNode}) => (
  <Background opacity={bgOpacity}>
    <div style={{position: "absolute", left: 140, top: 142, width: 740, opacity: contentOpacity}}>
      <AppName>MeridianHub</AppName>
      <AudienceLine>For residents like Maggie</AudienceLine>
      <div style={{fontSize: 44, fontWeight: 780, lineHeight: 1.08, letterSpacing: -1.5, marginTop: 26}}>{title}</div>
      <div style={{fontSize: 30, color: C.foregroundMuted, lineHeight: 1.38, marginTop: 28}}>{sub}</div>
    </div>
    <div style={{position: "absolute", right: 215, top: 92, width: 770, minHeight: 850, padding: 44, borderRadius: 42, background: C.surface, boxShadow: "0 30px 80px rgba(12,74,110,.18)", opacity: contentOpacity, translate: `${panelX}px 0`}}>
      <div style={{fontSize: 20, color: C.primary, fontWeight: 760, letterSpacing: 1.2}}>MERIDIANHUB</div>
      <h1 style={{fontSize: 44, letterSpacing: -1.6, margin: "12px 0 8px"}}>Hello, Maggie</h1>
      <p style={{fontSize: 23, lineHeight: 1.3, color: C.foregroundMuted, margin: 0}}>Choose what you need. Your care team is here to help.</p>
      {children}
    </div>
  </Background>
);

// Beat 4 -- frames 430-545 (local 0-115). Mounted five frames early so the
// cross-dissolve out of MeridianCare has something to dissolve to.
const HUB_ROWS = ["Your request was sent", "A caregiver has seen it", "A caregiver is on the way"];
// The shipped Today's reminders checklist (b14a18b), verbatim. A reminder the
// resident can tick is a PROMPT, not an observation, which is why it is allowed
// here while the family-facing "she ate breakfast" row still is not: nothing in
// the system observes a meal. The shipped card also shows a "n of n done" count
// and a clock time per row; both are digits, so both are dropped -- the
// progress bar carries the same information without a number.
const HUB_REMINDERS: [string, React.ReactNode][] = [
  ["Take your medication", GLYPH_PILL],
  ["Time for lunch", GLYPH_MEAL],
  ["Afternoon walk", GLYPH_WALK],
];
const HubHelpScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.hubOffset;
  const bgOpacity = ramp(raw, [115, 125], [1, 0]);
  const contentOpacity = ramp(raw, [0, 10], [0, 1]);
  // The panel leaves to the left as the visitor card arrives from the right.
  const panelX = clamp(local, [110, 120], [0, -40]);
  const panelScale = clamp(local, [10, 26], [0.97, 1]);
  const panelIn = ramp(local, [10, 26], [0, 1]);
  const remindersIn = ramp(local, [38, 50], [0, 1]);
  const remindersY = clamp(local, [38, 50], [14, 0]);
  // Maggie ticks the first reminder off herself: ripple 64-78, the row commits
  // at 74, the progress bar catches up by 86 -- all before the emergency pill's
  // 80-95 fade, which is the beat's last action.
  // Row-wide flash rather than an expanding ring: the row is short and clips
  // a circle into a lens. Ramps up fast, decays through the commit at 74.
  const tapFlash = ramp(local, [64, 70, 82], [0, 1, 0]);
  const ticked = local >= 74;
  const progress = ramp(local, [74, 86], [0, 100 / 3]);
  const emergency = ramp(local, [80, 95], [0, 1]);
  return <HubFrame title="Help is on the way." sub="And Maggie sees it too — every step, from her own room." bgOpacity={bgOpacity} contentOpacity={contentOpacity} panelX={panelX}>
    <Panel style={{padding: 26, marginTop: 18, border: "2px solid #b6efd8", background: "#f3fdf8", opacity: panelIn, scale: panelScale}}>
      <div style={{display: "flex", alignItems: "center", gap: 9, fontWeight: 800, color: C.success, fontSize: 20, letterSpacing: 1}}>{svgIcon(PATH_STATUS, C.success, 22)}<span>HELP STATUS</span></div>
      <h2 style={{fontSize: 31, lineHeight: 1.15, margin: "12px 0 16px"}}>Help is coming. A caregiver is on the way.</h2>
      {HUB_ROWS.map((row, i) => {
        // Rows stagger 14f apart: the dot pops, then its label catches up.
        const start = 26 + i * 14;
        const dot = clamp(local, [start, start + 6, start + 12], [0, 1.15, 1]);
        const label = ramp(local, [start + 4, start + 14], [0, 1]);
        return <div key={row} style={{display: "flex", alignItems: "center", gap: 15, marginTop: 12, fontSize: 22, color: C.foreground}}>
          <span style={{width: 18, height: 18, borderRadius: "50%", background: C.success, flexShrink: 0, scale: dot}} />
          <span style={{opacity: label}}>{row}</span>
        </div>;
      })}
    </Panel>
    <Panel style={{padding: 18, marginTop: 14, opacity: remindersIn, translate: `0 ${remindersY}px`}}>
      <div style={{fontSize: 26, fontWeight: 800, letterSpacing: -0.6}}>Today&rsquo;s reminders</div>
      <div style={{fontSize: 19, color: C.foregroundMuted, marginTop: 5}}>Tap a reminder when you&rsquo;ve done it.</div>
      <div style={{marginTop: 11, height: 10, borderRadius: 99, background: C.background, border: `2px solid ${C.border}`, overflow: "hidden"}}>
        <div style={{height: "100%", borderRadius: 99, background: C.success, width: `${progress}%`}} />
      </div>
      {HUB_REMINDERS.map(([label, glyph], i) => {
        const start = 42 + i * 5;
        const rowIn = ramp(local, [start, start + 9], [0, 1]);
        const done = i === 0 && ticked;
        return <div key={label} style={{display: "flex", alignItems: "center", gap: 13, marginTop: i === 0 ? 13 : 9, padding: "7px 12px", borderRadius: 15,
                                       border: `2px solid ${done ? "#b6efd8" : C.border}`, background: done ? "#f3fdf8" : C.surface,
                                       opacity: rowIn, position: "relative", overflow: "hidden"}}>
          <span style={{width: 40, height: 40, borderRadius: 12, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center", background: done ? C.success : C.muted}}>{svgGlyph(glyph, done ? "#ffffff" : C.primary, 24, 2)}</span>
          <span style={{flex: 1, fontSize: 21, fontWeight: 740, color: done ? C.foregroundMuted : C.foreground, textDecoration: done ? "line-through" : "none"}}>{label}</span>
          <span style={{width: 28, height: 28, borderRadius: "50%", flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center", border: `2px solid ${done ? C.success : C.border}`, background: done ? C.success : "transparent"}}>{done && svgGlyph(GLYPH_CHECK, "#ffffff", 16, 3)}</span>
          {i === 0 && <div style={{position: "absolute", inset: 0, background: C.success, opacity: tapFlash * 0.16, pointerEvents: "none"}} />}
        </div>;
      })}
    </Panel>
    <div style={{marginTop: 14, borderRadius: 20, background: "#ffe9e5", padding: 18, fontSize: 24, fontWeight: 760, color: C.destructive, display: "flex", alignItems: "center", gap: 11, opacity: emergency}}>{alertIcon(C.destructive, 27)}<span>Emergency help</span></div>
  </HubFrame>;
};

// Beat 5 -- frames 545-675 (local 0-130). Mounted at 540 underneath beat 4 so
// the in-device swap is a real slide, not a cut.
const HubVisitorScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.visitorOffset;
  const bgOpacity = ramp(raw, [130, 140], [1, 0]);
  const contentOpacity = ramp(raw, [0, 10], [0, 1]);
  const panelX = clamp(raw, [0, 10], [40, 0]);
  const buttonY = clamp(local, [20, 34], [12, 0]);
  const buttonIn = ramp(local, [20, 34], [0, 1]);
  const ripple = clamp(local, [76, 92], [0, 92]);
  const rippleFade = ramp(local, [84, 92], [1, 0]);
  const brighten = clamp(local, [76, 92], [1, 1.22]);
  const answer = ramp(local, [92, 110], [0, 1]);
  return <HubFrame title="Your voice matters." sub="Not just falls — an unexpected visitor is Maggie's call to make." bgOpacity={bgOpacity} contentOpacity={contentOpacity} panelX={panelX}>
    <Panel style={{padding: 30, marginTop: 32, border: "2px solid #bae6fd"}}>
      <div style={{display: "flex", alignItems: "center", gap: 9, fontWeight: 800, color: C.primary, fontSize: 20, letterSpacing: 1}}>{svgIcon(PATH_VISITOR, C.primary, 22)}<span>VISITOR CHECK</span></div>
      <h2 style={{fontSize: 37, lineHeight: 1.1, margin: "14px 0"}}>Is this person expected?</h2>
      <p style={{fontSize: 24, lineHeight: 1.35, color: C.foregroundMuted}}>Someone we do not recognise was seen at the entrance.</p>
      <div style={{display: "flex", gap: 16, marginTop: 27, opacity: buttonIn, translate: `0 ${buttonY}px`}}>
        <div style={{flex: 1, borderRadius: 18, padding: "19px 16px", background: C.success, color: "white", fontWeight: 790, fontSize: 21, display: "flex", alignItems: "center", justifyContent: "center", gap: 9, position: "relative", overflow: "hidden", filter: `brightness(${brighten})`}}>{svgIcon(PATH_STATUS, "#ffffff", 22)}<span>Yes, expected</span><Ripple size={ripple} opacity={rippleFade} /></div>
        <div style={{flex: 1, borderRadius: 18, padding: "19px 16px", background: C.destructive, color: "white", fontWeight: 790, fontSize: 21, display: "flex", alignItems: "center", justifyContent: "center", gap: 9}}>{alertIcon("#ffffff", 22)}<span>No, get help</span></div>
      </div>
    </Panel>
    <div style={{marginTop: 28, opacity: answer, borderRadius: 18, padding: 22, background: "#edfdf5", fontWeight: 740, fontSize: 25, color: C.success, display: "flex", alignItems: "center", gap: 12}}>{svgIcon(PATH_STATUS, C.success, 26)}<span>Thank you. The care team has been told to come and check.</span></div>
  </HubFrame>;
};

// Beat 6 -- frames 675-840 (local 0-165). Carries the 6f fade to deck navy
// that hands the last thirty frames to the end card.
const FamilyScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.familyOffset;
  const contentOpacity = ramp(raw, [0, 10], [0, 1]);
  const phoneY = clamp(local, [0, 12], [24, 0]);
  const notification = ramp(local, [8, 26], [0, 1]);
  const notificationY = clamp(local, [8, 26], [-80, 0]);
  const staffLabel = ramp(local, [60, 75], [0, 1]);
  const responseCard = ramp(local, [75, 95], [0, 1]);
  const responseY = clamp(local, [75, 95], [24, 0]);
  // Resolution stated in colour, not in a new line of copy: the amber ring on
  // the original alert cools to the green of the response.
  const resolved = interpolateColors(ramp(local, [120, 145], [0, 1]), [0, 1], [C.warning, C.success]);
  const toNavy = ramp(raw, [166, 172], [0, 1]);
  return <Background>
    <div style={{position: "absolute", left: 200, top: 158, width: 790, opacity: contentOpacity}}>
      <AppName>MeridianFamily</AppName>
      <AudienceLine>For worried families</AudienceLine>
      <div style={{fontSize: 44, lineHeight: 1.08, letterSpacing: -1.5, fontWeight: 780, marginTop: 26}}>Stay informed. Stay close.</div>
      <StoryLine>And her family watches the same story — including how it ends.</StoryLine>
    </div>
    <div style={{position: "absolute", right: 280, top: 55, opacity: contentOpacity, translate: `0 ${phoneY}px`}}><Device label="MeridianFamily updates">
      <div style={{padding: "75px 28px 42px"}}>
        <h1 style={{fontSize: 42, margin: "4px 0 22px"}}>Updates</h1>
        <Panel style={{padding: 24, opacity: notification, translate: `0 ${notificationY}px`, borderLeft: `7px solid ${resolved}`}}><div style={{display: "flex", gap: 15}}>{alertIcon(C.warning, 30)}<div><div style={{fontSize: 26, fontWeight: 760, lineHeight: 1.25}}>Maggie may need help in Room 101.</div><div style={{fontSize: 20, color: C.foregroundMuted, marginTop: 8}}>Care team has been alerted.</div></div></div></Panel>
        <div style={{marginTop: 26, fontSize: 22, fontWeight: 750, color: C.foregroundMuted, opacity: staffLabel}}>STAFF RESPONSES</div>
        <Panel style={{padding: 24, marginTop: 12, opacity: responseCard, translate: `0 ${responseY}px`}}><div style={{display: "flex", gap: 15}}>{svgIcon(PATH_STATUS, C.success, 30)}<div><div style={{fontSize: 26, fontWeight: 760, lineHeight: 1.25}}>A caregiver is responding.</div><div style={{fontSize: 20, color: C.foregroundMuted, marginTop: 8}}>Maggie is not alone.</div></div></div></Panel>
      </div>
    </Device></div>
    <AbsoluteFill style={{background: C.deckNavy, opacity: toNavy, pointerEvents: "none"}} />
  </Background>;
};

// One-second closer matching the deck's title slide: M-notched shield with a
// medical cross, MERIDIAN in caps, the deck's subtitle. Deliberately brief --
// stage time belongs to the product, and this frame only needs to match the
// slide already on screen beside it.
const DECK_BLUE = "#69A8E0";
const DECK_TEXT_BLUE = "#6B96EE";
const EndCard = () => {
  const f = useCurrentFrame();
  const o = ramp(f, [0, 9], [0, 1]);
  // The family beat's own 836-842 fade to this exact navy is still running
  // underneath for the first two frames of the end card. The plate only takes
  // over on the frame after that beat unmounts (842), which keeps the fade one
  // continuous linear ramp instead of stacking two of them.
  const plate = ramp(f, [1, 2], [0, 1]);
  return <AbsoluteFill style={{justifyContent: "center", alignItems: "center", display: "flex"}}>
    <AbsoluteFill style={{background: C.deckNavy, opacity: plate}} />
    {/* position:relative, or the absolutely-positioned plate above paints over
        this in-flow block and the closer renders as an empty navy field. */}
    <div style={{textAlign: "center", opacity: o, position: "relative"}}>
      <svg width={120} height={120} viewBox="0 0 1024 1024" style={{display: "block", margin: "0 auto 26px"}} aria-label="Meridian">
        <path d="M242 250 L420 196 L512 320 L604 196 L782 250 L782 540 C782 694 668 800 512 858 C356 800 242 694 242 540 Z"
              fill="none" stroke={DECK_BLUE} strokeWidth={52} strokeLinejoin="round" strokeLinecap="round" />
        <path d="M462 400 H562 V470 H632 V570 H562 V640 H462 V570 H392 V470 H462 Z" fill={DECK_BLUE} />
      </svg>
      <div style={{fontSize: 66, fontWeight: 800, letterSpacing: 8, color: DECK_TEXT_BLUE}}>MERIDIAN</div>
      <div style={{fontSize: 40, fontWeight: 500, marginTop: 22, color: "#93A8C4", letterSpacing: -0.5}}>The Care Intelligence Layer for Senior Living</div>
    </div>
  </AbsoluteFill>;
};

// End card is one second flat -- stage time belongs to the product beats,
// which each gained time when it shrank.
// Score: Pixabay Content License (AKTASOK, "Hopeful Ambient Background") --
// free for commercial use, no attribution required, downloaded to
// public/music.mp3. The envelope follows the story, not the clock: present
// under the night footage, pulled back for the fall so the track never feels
// cheerful over a person on the floor, rising through the app beats as the
// story resolves, gone by the end card.
const musicVolume = (f: number) =>
  interpolate(f, [0, 30, 80, 130, 200, 800, 862], [0, 0.3, 0.18, 0.18, 0.4, 0.4, 0], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp",
  });

export const MeridianDemo = () => <AbsoluteFill style={{background: C.dark}}>
  <Audio src={staticFile("music.mp3")} volume={musicVolume} />
  <Sequence durationInFrames={T.fallEnd} style={{zIndex: 7}}><FallAndSkeleton /></Sequence>
  <Sequence from={T.pipeFrom} durationInFrames={T.pipeDur} style={{zIndex: 6}}><PipelineBeat /></Sequence>
  <Sequence from={T.careFrom} durationInFrames={T.careDur} style={{zIndex: 5}}><CareScreen /></Sequence>
  <Sequence from={T.hubFrom} durationInFrames={T.hubDur} style={{zIndex: 4}}><HubHelpScreen /></Sequence>
  <Sequence from={T.visitorFrom} durationInFrames={T.visitorDur} style={{zIndex: 3}}><HubVisitorScreen /></Sequence>
  <Sequence from={T.familyFrom} durationInFrames={T.familyDur} style={{zIndex: 2}}><FamilyScreen /></Sequence>
  <Sequence from={T.endFrom} durationInFrames={T.endDur} style={{zIndex: 10}}><EndCard /></Sequence>
  <BrandMark />
</AbsoluteFill>;
