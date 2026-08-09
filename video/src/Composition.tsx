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

// ---------------------------------------------------------------------------
// Cut map (870 frames @ 30fps). Sequences overlap by the length of their
// transition so nothing ever unmounts onto an empty frame. Stacking is set
// with an explicit zIndex per Sequence, descending with time, so the OUTGOING
// beat always sits above the incoming one: the outgoing beat fades its own
// background out and reveals the next beat, which is already opaque
// underneath. That is what keeps every dissolve free of a flash frame.
//
//   Fall        0-169   (beat 0-165,   7f luminance dip 163-170)
//   Care      165-349   (beat 165-345, 10f cross-dissolve 340-350)
//   Hub help  340-499   (beat 345-495, in-device slide swap 490-500)
//   Hub visit 490-664   (beat 495-660, 10f cross-dissolve 655-665)
//   Family    655-841   (beat 660-840, 6f fade to deck navy 836-842)
//   End card  840-869
// ---------------------------------------------------------------------------
const T = {
  fallEnd: 170,
  careFrom: 165, careDur: 185,
  hubFrom: 340, hubDur: 160, hubOffset: 5,
  visitorFrom: 490, visitorDur: 175, visitorOffset: 5,
  familyFrom: 655, familyDur: 187, familyOffset: 5,
  endFrom: 840, endDur: 30,
};

// Persistent brand bug, top right. Sits above every beat so the reel is
// attributable on any frame someone screenshots. Tint flips with the beat
// underneath it: mint over the dark pose footage, brand blue over the light
// app screens. Hidden only on the end card, which already carries the mark
// full size.
const BrandMark = () => {
  const f = useCurrentFrame();
  const onDark = f < T.fallEnd;
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
const Ripple = ({size, opacity}: {size: number; opacity: number}) => <span style={{position: "absolute", left: "50%", top: "50%", marginLeft: -size / 2, marginTop: -size / 2, width: size, height: size, borderRadius: "50%", border: "3px solid rgba(255,255,255,.7)", opacity, pointerEvents: "none"}} />;
// The app name outranks the tagline: it is the thing the audience must retain.
const AppName = ({children}: {children: React.ReactNode}) => <div style={{fontSize: 58, fontWeight: 880, color: C.appName, letterSpacing: -1.4}}>{children}</div>;
// Who this screen belongs to, as part of the header lockup itself -- a
// first-time viewer reads "MeridianFamily / FOR WORRIED FAMILIES" as one
// unit. (Was a small pill; user direction: make it header-scale.)
const AudienceLine = ({children}: {children: React.ReactNode}) => <div style={{marginTop: 8, fontSize: 30, fontWeight: 800, color: C.primary, letterSpacing: 1.6, textTransform: "uppercase"}}>{children}</div>;
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

const FullVideo = ({src, startFrom, scale = 1, filter}: {src: string; startFrom: number; scale?: number; filter?: string}) => <OffthreadVideo src={staticFile(src)} startFrom={startFrom} style={{width: "100%", height: "100%", objectFit: "cover", scale, filter}} />;

// Beat 1 -- frames 0-165, plus five frames of luminance dip into beat 2.
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
  // 12f fade up from black, then the 7f dip that hands over to MeridianCare.
  const beat = ramp(f, [0, 12, 163, 170], [0, 1, 1, 0]);
  return <AbsoluteFill style={{background: C.dark, opacity: beat}}>
    <FullVideo src="fall.mp4" startFrom={CLIP_START} scale={zoom} filter={`brightness(${videoBrightness}) saturate(.72) contrast(1.08)`} />
    {/* screen blend drops the skeleton render's black background to fully
        transparent, so the strokes composite straight onto her. */}
    <AbsoluteFill style={{opacity: skeleton, mixBlendMode: "screen"}}><FullVideo src="skeleton.mp4" startFrom={CLIP_START} scale={zoom} /></AbsoluteFill>
    <AbsoluteFill style={{background: "radial-gradient(circle, transparent 44%, rgba(0,0,0,.32))"}} />
    <div style={{position: "absolute", left: 120, bottom: 110, opacity: caption, translate: `0 ${captionY}px`, color: "white", fontSize: 56, fontWeight: 760, letterSpacing: -1.5, padding: "22px 30px", borderLeft: `5px solid ${C.mint}`, background: "rgba(5,6,10,.72)", borderRadius: "0 16px 16px 0"}}>No video ever leaves the building.</div>
    {/* The bridge into the app beats: video stays, the alert travels. Without
        this line a first-time viewer has no idea why phone screens follow. */}
    <div style={{position: "absolute", left: 125, bottom: 44, opacity: bridge, color: C.mint, fontSize: 37, fontWeight: 700, letterSpacing: -0.5, padding: "6px 30px"}}>Only the alert does — here is where it goes.</div>
  </AbsoluteFill>;
};

// Beat 2 -- frames 165-345 (local 0-180), plus five frames of cross-dissolve.
// This is the only beat whose background fades IN as well as out: it arrives
// out of the luminance dip, so the light surface has to rise from black.
const CareScreen = () => {
  const local = useCurrentFrame();
  const beat = ramp(local, [0, 14, 175, 185], [0, 1, 1, 0]);
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
  return <Background opacity={beat}><div style={{position: "absolute", left: 255, top: 177, width: 560}}>
    <AppName>MeridianCare</AppName>
    <AudienceLine>For night-shift caregivers</AudienceLine>
    <div style={{fontSize: 54, letterSpacing: -2, fontWeight: 760, marginTop: 26}}>Care, in sync.</div>
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

// Shared Hub chrome. Beats 3 and 4 are the same physical device on stage, so
// they share the frame and only the card inside it changes -- which is exactly
// what the 490-500 swap has to sell.
const HubFrame = ({title, sub, bgOpacity, contentOpacity, panelX, children}: {title: string; sub: string; bgOpacity: number; contentOpacity: number; panelX: number; children: React.ReactNode}) => (
  <Background opacity={bgOpacity}>
    <div style={{position: "absolute", left: 155, top: 160, width: 580, opacity: contentOpacity}}>
      <AppName>MeridianHub</AppName>
      <AudienceLine>For residents like Maggie</AudienceLine>
      <div style={{fontSize: 54, fontWeight: 760, lineHeight: 1.08, letterSpacing: -2, marginTop: 26}}>{title}</div>
      <div style={{fontSize: 30, color: C.foregroundMuted, lineHeight: 1.38, marginTop: 28}}>{sub}</div>
    </div>
    <div style={{position: "absolute", right: 215, top: 100, width: 770, minHeight: 850, padding: 52, borderRadius: 42, background: C.surface, boxShadow: "0 30px 80px rgba(12,74,110,.18)", opacity: contentOpacity, translate: `${panelX}px 0`}}>
      <div style={{fontSize: 20, color: C.primary, fontWeight: 760, letterSpacing: 1.2}}>MERIDIANHUB</div>
      <h1 style={{fontSize: 48, letterSpacing: -1.6, margin: "16px 0 8px"}}>Hello, Maggie</h1>
      <p style={{fontSize: 24, lineHeight: 1.35, color: C.foregroundMuted, margin: 0}}>Choose what you need. Your care team is here to help.</p>
      {children}
    </div>
  </Background>
);

// Beat 3 -- frames 345-495 (local 0-150). Mounted five frames early so the
// cross-dissolve out of MeridianCare has something to dissolve to.
const HUB_ROWS = ["Your request was sent", "A caregiver has seen it", "A caregiver is on the way"];
const HubHelpScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.hubOffset;
  const bgOpacity = ramp(raw, [150, 160], [1, 0]);
  const contentOpacity = ramp(raw, [0, 10], [0, 1]);
  // The panel leaves to the left as the visitor card arrives from the right.
  const panelX = clamp(local, [145, 155], [0, -40]);
  const panelScale = clamp(local, [10, 26], [0.97, 1]);
  const panelIn = ramp(local, [10, 26], [0, 1]);
  const emergency = ramp(local, [80, 95], [0, 1]);
  return <HubFrame title="Help is on the way." sub="And Maggie sees it too — every step, from her own room." bgOpacity={bgOpacity} contentOpacity={contentOpacity} panelX={panelX}>
    <Panel style={{padding: 30, marginTop: 32, border: "2px solid #b6efd8", background: "#f3fdf8", opacity: panelIn, scale: panelScale}}>
      <div style={{display: "flex", alignItems: "center", gap: 9, fontWeight: 800, color: C.success, fontSize: 20, letterSpacing: 1}}>{svgIcon(PATH_STATUS, C.success, 22)}<span>HELP STATUS</span></div>
      <h2 style={{fontSize: 34, lineHeight: 1.15, margin: "14px 0 22px"}}>Help is coming. A caregiver is on the way.</h2>
      {HUB_ROWS.map((row, i) => {
        // Rows stagger 14f apart: the dot pops, then its label catches up.
        const start = 26 + i * 14;
        const dot = clamp(local, [start, start + 6, start + 12], [0, 1.15, 1]);
        const label = ramp(local, [start + 4, start + 14], [0, 1]);
        return <div key={row} style={{display: "flex", alignItems: "center", gap: 15, marginTop: 15, fontSize: 23, color: C.foreground}}>
          <span style={{width: 18, height: 18, borderRadius: "50%", background: C.success, flexShrink: 0, scale: dot}} />
          <span style={{opacity: label}}>{row}</span>
        </div>;
      })}
    </Panel>
    <div style={{marginTop: 26, borderRadius: 20, background: "#ffe9e5", padding: 22, fontSize: 25, fontWeight: 760, color: C.destructive, display: "flex", alignItems: "center", gap: 11, opacity: emergency}}>{alertIcon(C.destructive, 27)}<span>Emergency help</span></div>
  </HubFrame>;
};

// Beat 4 -- frames 495-660 (local 0-165). Mounted at 490 underneath beat 3 so
// the in-device swap is a real slide, not a cut.
const HubVisitorScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.visitorOffset;
  const bgOpacity = ramp(raw, [165, 175], [1, 0]);
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

// Beat 5 -- frames 660-840 (local 0-180). Carries the 6f fade to deck navy
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
  const toNavy = ramp(raw, [181, 187], [0, 1]);
  return <Background>
    <div style={{position: "absolute", left: 250, top: 195, width: 540, opacity: contentOpacity}}>
      <AppName>MeridianFamily</AppName>
      <AudienceLine>For worried families</AudienceLine>
      <div style={{fontSize: 54, lineHeight: 1.08, letterSpacing: -2, fontWeight: 760, marginTop: 26}}>Stay informed.<br />Stay close.</div>
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
  <Sequence durationInFrames={T.fallEnd} style={{zIndex: 6}}><FallAndSkeleton /></Sequence>
  <Sequence from={T.careFrom} durationInFrames={T.careDur} style={{zIndex: 5}}><CareScreen /></Sequence>
  <Sequence from={T.hubFrom} durationInFrames={T.hubDur} style={{zIndex: 4}}><HubHelpScreen /></Sequence>
  <Sequence from={T.visitorFrom} durationInFrames={T.visitorDur} style={{zIndex: 3}}><HubVisitorScreen /></Sequence>
  <Sequence from={T.familyFrom} durationInFrames={T.familyDur} style={{zIndex: 2}}><FamilyScreen /></Sequence>
  <Sequence from={T.endFrom} durationInFrames={T.endDur} style={{zIndex: 10}}><EndCard /></Sequence>
  <BrandMark />
</AbsoluteFill>;
