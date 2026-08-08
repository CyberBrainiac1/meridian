import React from "react";
import {
  AbsoluteFill,
  Easing,
  interpolate,
  OffthreadVideo,
  Sequence,
  staticFile,
  useCurrentFrame,
} from "remotion";

const C = {
  primary: "#0369A1", primaryAlt: "#0891B2", success: "#047857", warning: "#92400E",
  destructive: "#991B1B", foreground: "#0C4A6E", muted: "#E7EFF5", border: "#E0F2FE",
  background: "#F0F9FF", surface: "#FFFFFF", foregroundMuted: "#2F5D77", dark: "#05060A", mint: "#22FFC2",
};
const ease = Easing.bezier(0.16, 1, 0.3, 1);
const clamp = (value: number, input: number[], output: number[]) => interpolate(value, input, output, {extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: ease});
const icon = (symbol: string, color = C.primary) => <span style={{color, fontSize: 34, lineHeight: 1}}>{symbol}</span>;

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

const Panel = ({children, style}: {children: React.ReactNode; style?: React.CSSProperties}) => <div style={{background: C.surface, border: `1px solid ${C.border}`, borderRadius: 26, boxShadow: "0 18px 45px rgba(12,74,110,.11)", ...style}}>{children}</div>;
const Pill = ({children, color = C.primary}: {children: React.ReactNode; color?: string}) => <span style={{background: `${color}18`, color, borderRadius: 99, padding: "10px 16px", fontWeight: 750, fontSize: 20}}>{children}</span>;

const Device = ({children, label}: {children: React.ReactNode; label: string}) => <div aria-label={label} style={{width: 560, height: 970, padding: 15, background: "#102833", borderRadius: 64, boxShadow: "0 40px 90px rgba(0,0,0,.28)", border: "3px solid #31505d"}}>
  <div style={{height: "100%", overflow: "hidden", borderRadius: 49, background: C.background, position: "relative"}}>
    <div style={{position: "absolute", zIndex: 4, top: 14, left: "50%", marginLeft: -62, width: 124, height: 29, borderRadius: 99, background: "#102833"}} />
    {children}
  </div>
</div>;

const Background = ({children}: {children: React.ReactNode}) => <AbsoluteFill style={{background: `radial-gradient(circle at 18% 18%, #dff5ff 0, transparent 32%), radial-gradient(circle at 84% 82%, #d9fbef 0, transparent 30%), ${C.background}`, color: C.foreground, overflow: "hidden"}}>{children}</AbsoluteFill>;

const FullVideo = ({src, opacity = 1, scale = 1, filter}: {src: string; opacity?: number; scale?: number; filter?: string}) => <OffthreadVideo src={staticFile(src)} startFrom={0} style={{width: "100%", height: "100%", objectFit: "cover", opacity, scale, filter}} />;

const FallAndSkeleton = () => {
  const f = useCurrentFrame();
  const dissolve = clamp(f, [120, 188], [0, 1]);
  const caption = clamp(f, [188, 210, 252, 270], [0, 1, 1, 0]);
  return <AbsoluteFill style={{background: C.dark}}>
    <FullVideo src="fall.mp4" scale={clamp(f, [0, 270], [1.02, 1.12])} filter="brightness(.56) saturate(.72) contrast(1.08)" />
    <AbsoluteFill style={{opacity: dissolve}}><FullVideo src="skeleton.mp4" scale={clamp(f, [120, 270], [1.01, 1.08])} /></AbsoluteFill>
    <AbsoluteFill style={{background: "radial-gradient(circle, transparent 44%, rgba(0,0,0,.32))"}} />
    <div style={{position: "absolute", left: 120, bottom: 110, opacity: caption, color: "white", fontSize: 56, fontWeight: 760, letterSpacing: -1.5, padding: "22px 30px", borderLeft: `5px solid ${C.mint}`, background: "rgba(5,6,10,.72)", borderRadius: "0 16px 16px 0"}}>No video ever leaves the building.</div>
  </AbsoluteFill>;
};

const CareScreen = () => {
  const f = useCurrentFrame();
  const local = f;
  const acknowledged = local >= 58;
  const responding = local >= 92;
  const alertY = clamp(local, [0, 16], [-80, 0]);
  const ripple = clamp(local, [45, 68], [0, 92]);
  const screenY = clamp(local, [86, 104], [0, -145]);
  return <Background><div style={{position: "absolute", left: 255, top: 177, width: 560, opacity: clamp(local,[0,18],[0,1]), translate: "0 0"}}>
    <div style={{fontSize: 34, color: C.foregroundMuted, fontWeight: 650}}>MeridianCare</div><div style={{fontSize: 73, letterSpacing: -3, fontWeight: 780, marginTop: 14}}>Care, in sync.</div>
    <div style={{marginTop: 30, fontSize: 31, color: C.foregroundMuted, lineHeight: 1.4}}>One clear alert. One clear response.</div>
  </div><div style={{position: "absolute", right: 270, top: 55}}><Device label="MeridianCare caregiver alerts">
    <div style={{padding: "72px 28px 102px", height: "100%", translate: `0 ${screenY}px`}}>
      <h1 style={{fontSize: 42, margin: "4px 0 25px", letterSpacing: -1.2}}>Alerts</h1>
      <div style={{position: "relative", translate: `0 ${alertY}px`}}>
        <Panel style={{padding: 22, borderLeft: `7px solid ${C.destructive}`}}><div style={{display: "flex", justifyContent: "space-between", alignItems: "center"}}><Pill color={C.destructive}>Emergency</Pill>{alertIcon(C.destructive, 26)}</div>
          <div style={{fontSize: 30, lineHeight: 1.22, fontWeight: 760, marginTop: 18}}>Maggie may need help.</div>
          <div style={{fontSize: 22, marginTop: 12, color: C.foregroundMuted}}>Fall detected</div>
          {!acknowledged && <button style={{marginTop: 22, border: 0, width: "100%", padding: "17px", borderRadius: 17, color: "white", fontWeight: 800, fontSize: 24, background: C.primary, position: "relative", overflow: "hidden"}}>Acknowledge<span style={{position:"absolute", left:"50%", top:"50%", marginLeft:-ripple/2, marginTop:-ripple/2, width:ripple, height:ripple, borderRadius:"50%", border:"3px solid rgba(255,255,255,.7)"}} /></button>}
          {acknowledged && <div style={{marginTop: 22}}><Pill color={responding ? C.success : C.warning}>{responding ? "Responding" : "Acknowledged"}</Pill>{!responding && <button style={{marginTop: 18, border: 0, width: "100%", padding: "17px", borderRadius: 17, color: "white", fontWeight: 800, fontSize: 24, background: C.primary}}>Mark responding</button>}</div>}
        </Panel>
      </div>
      {responding && <Panel style={{padding: 22, marginTop: 20, opacity: clamp(local,[98,112],[0,1])}}><div style={{fontSize: 21, fontWeight: 750, color:C.foregroundMuted}}>RESPONSE</div><div style={{fontSize: 28, fontWeight: 740, marginTop: 8}}>Care team is responding.</div></Panel>}
    </div>
    <div style={{position:"absolute", bottom:0, left:0, right:0, height:88, display:"flex", justifyContent:"space-around", alignItems:"center", background:"rgba(255,255,255,.95)", borderTop:`1px solid ${C.border}`, fontSize:16, fontWeight:700, color:C.foregroundMuted}}>{([["Alerts", PATH_STATUS, true], ["Handoff", "M4 5h16v3H4Zm0 5.5h16v3H4Zm0 5.5h11v3H4Z", false], ["Residents", PATH_VISITOR, false], ["Settings", "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Zm9.4 4a9.4 9.4 0 0 0-.15-1.6l2.05-1.55-2-3.46-2.4 1a9.5 9.5 0 0 0-2.77-1.6L15.8 2h-4l-.33 2.79a9.5 9.5 0 0 0-2.77 1.6l-2.4-1-2 3.46L6.35 10.4a9.5 9.5 0 0 0 0 3.2L4.3 15.15l2 3.46 2.4-1a9.5 9.5 0 0 0 2.77 1.6L11.8 22h4l.33-2.79a9.5 9.5 0 0 0 2.77-1.6l2.4 1 2-3.46-2.05-1.55c.1-.52.15-1.06.15-1.6Z", false]] as [string, string, boolean][]).map(([label, path, active]) => <span key={label} style={{display: "flex", flexDirection: "column", alignItems: "center", gap: 5, color: active ? C.primary : C.foregroundMuted}}>{svgIcon(path, active ? C.primary : C.foregroundMuted, 21)}{label}</span>)}</div>
  </Device></div></Background>;
};

const HubScreen = ({visitor = false}: {visitor?: boolean}) => {
  const f = useCurrentFrame(); const local = f; const reveal = clamp(local,[0,18],[0,1]); const answer = clamp(local,[78,103],[0,1]);
  return <Background><div style={{position:"absolute", left:155, top:160, width:580}}><div style={{fontSize:32, fontWeight:720, color:C.primaryAlt}}>MeridianHub</div><div style={{fontSize:71, fontWeight:790, lineHeight:1.05, letterSpacing:-3, marginTop:18}}>{visitor ? "Your voice matters." : "Help is on the way."}</div><div style={{fontSize:30, color:C.foregroundMuted, lineHeight:1.38, marginTop:28}}>{visitor ? "A calm choice for an unexpected visitor." : "The resident sees every step clearly."}</div></div>
  <div style={{position:"absolute", right:215, top:100, width:770, minHeight:850, padding:52, borderRadius:42, background:C.surface, boxShadow:"0 30px 80px rgba(12,74,110,.18)", opacity:reveal}}>
    <div style={{fontSize:20, color:C.primary, fontWeight:760, letterSpacing:1.2}}>MERIDIANHUB</div><h1 style={{fontSize:48, letterSpacing:-1.6, margin:"16px 0 8px"}}>Hello, Maggie</h1><p style={{fontSize:24, lineHeight:1.35, color:C.foregroundMuted, margin:0}}>Choose what you need. Your care team is here to help.</p>
    {!visitor ? <><Panel style={{padding:30, marginTop:32, border:`2px solid #b6efd8`, background:"#f3fdf8"}}><div style={{display:"flex",alignItems:"center",gap:9,fontWeight:800, color:C.success, fontSize:20, letterSpacing:1}}>{svgIcon(PATH_STATUS,C.success,22)}<span>HELP STATUS</span></div><h2 style={{fontSize:34, lineHeight:1.15, margin:"14px 0 22px"}}>Help is coming. A caregiver is on the way.</h2>{["Your request was sent", "A caregiver has seen it", "A caregiver is on the way"].map((s)=><div key={s} style={{display:"flex", gap:15, marginTop:15, fontSize:23, color:C.foreground}}>{icon("●",C.success)}<span>{s}</span></div>)}</Panel><div style={{marginTop:26, borderRadius:20, background:"#ffe9e5", padding:22, fontSize:25, fontWeight:760, color:C.destructive, display:"flex", alignItems:"center", gap:11}}>{alertIcon(C.destructive,27)}<span>Emergency help</span></div></> : <><Panel style={{padding:30, marginTop:32, border:`2px solid #bae6fd`}}><div style={{display:"flex",alignItems:"center",gap:9,fontWeight:800, color:C.primary, fontSize:20, letterSpacing:1}}>{svgIcon(PATH_VISITOR,C.primary,22)}<span>VISITOR CHECK</span></div><h2 style={{fontSize:37, lineHeight:1.1, margin:"14px 0"}}>Is this person expected?</h2><p style={{fontSize:24, lineHeight:1.35, color:C.foregroundMuted}}>Someone we do not recognise was seen at the entrance.</p><div style={{display:"flex", gap:16, marginTop:27}}><div style={{flex:1, borderRadius:18, padding:"19px 16px", background:C.success, color:"white", fontWeight:790, fontSize:21}}>● Yes, expected</div><div style={{flex:1, borderRadius:18, padding:"19px 16px", background:C.destructive, color:"white", fontWeight:790, fontSize:21, display:"flex", alignItems:"center", justifyContent:"center", gap:9}}>{alertIcon("#ffffff",22)}<span>No, get help</span></div></div></Panel><div style={{marginTop:28, opacity:answer, borderRadius:18, padding:22, background:"#edfdf5", fontWeight:740, fontSize:25, color:C.success}}>✓ Thank you. The care team has been told to come and check.</div></>}
  </div></Background>;
};

const FamilyScreen = () => {const f=useCurrentFrame();const local=f;const notification=clamp(local,[8,26],[0,1]);const resolved=clamp(local,[82,105],[0,1]);return <Background><div style={{position:"absolute",left:250,top:195,width:540}}><div style={{fontSize:34,color:C.primaryAlt,fontWeight:720}}>MeridianFamily</div><div style={{fontSize:72,lineHeight:1.03,letterSpacing:-3,fontWeight:790,marginTop:18}}>Stay informed.<br/>Stay close.</div><div style={{fontSize:30,color:C.foregroundMuted,lineHeight:1.4,marginTop:30}}>Updates arrive in the family app—not as a text message.</div></div><div style={{position:"absolute",right:280,top:55}}><Device label="MeridianFamily updates"><div style={{padding:"75px 28px 42px"}}><h1 style={{fontSize:42,margin:"4px 0 22px"}}>Updates</h1><Panel style={{padding:24,opacity:notification,borderLeft:`7px solid ${C.warning}`}}><div style={{display:"flex",gap:15}}>{icon("◉",C.warning)}<div><div style={{fontSize:26,fontWeight:760,lineHeight:1.25}}>Maggie may need help.</div><div style={{fontSize:20,color:C.foregroundMuted,marginTop:8}}>Care team has been alerted.</div></div></div></Panel><div style={{marginTop:26,fontSize:22,fontWeight:750,color:C.foregroundMuted}}>STAFF RESPONSES</div><Panel style={{padding:24,marginTop:12,opacity:resolved}}><div style={{display:"flex",gap:15}}>{icon("✓",C.success)}<div><div style={{fontSize:26,fontWeight:760,lineHeight:1.25}}>A caregiver is responding.</div><div style={{fontSize:20,color:C.foregroundMuted,marginTop:8}}>Maggie is not alone.</div></div></div></Panel></div></Device></div></Background>};

const EndCard = () => {const f=useCurrentFrame();const local=f;const o=clamp(local,[0,25],[0,1]);return <AbsoluteFill style={{background:`radial-gradient(circle at center, #12536b, ${C.dark} 70%)`,color:"white",justifyContent:"center",alignItems:"center",display:"flex"}}><div style={{textAlign:"center",opacity:o,scale:clamp(local,[0,40],[.94,1])}}><svg width={116} height={116} viewBox="0 0 1024 1024" style={{display:"block",margin:"0 auto 34px"}} aria-label="Meridian"><path d="M512 168 L800 268 L800 536 C800 700 676 812 512 872 C348 812 224 700 224 536 L224 268 Z" fill="none" stroke={C.mint} strokeWidth={46} strokeLinejoin="round" /><path d="M512 356 L676 490 L676 660 L560 660 L560 566 L464 566 L464 660 L348 660 L348 490 Z" fill={C.mint} /></svg><div style={{fontSize:76,fontWeight:790,letterSpacing:-3}}>Meridian</div><div style={{fontSize:49,fontWeight:650,marginTop:34,letterSpacing:-1.5}}>Faster help. Less uncertainty. More dignity.</div></div></AbsoluteFill>};

export const MeridianDemo = () => <AbsoluteFill><Sequence durationInFrames={270}><FallAndSkeleton /></Sequence><Sequence from={270} durationInFrames={120}><CareScreen /></Sequence><Sequence from={390} durationInFrames={150}><HubScreen /></Sequence><Sequence from={540} durationInFrames={120}><HubScreen visitor /></Sequence><Sequence from={660} durationInFrames={150}><FamilyScreen /></Sequence><Sequence from={810} durationInFrames={90}><EndCard /></Sequence></AbsoluteFill>;
