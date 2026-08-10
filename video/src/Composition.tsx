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
  // Severity BASE tokens, distinct from the *Strong text variants above. The
  // design system's Badge tints its pill with the base colour at 1f alpha and
  // draws the label in the Strong variant -- that pairing is the accessibility
  // audit baked into tokens/colors.css, so both halves are needed to port it.
  destructiveBase: "#DC2626", warningBase: "#B45309", successBase: "#059669",
  // The kiosk/mobile page surface (--color-background-mobile). Cards are white
  // ON this, which is why the Hub panel is no longer white-on-white.
  backgroundMobile: "#ECFEFF",
  // --border-soft. --color-border (#E0F2FE) is nearly invisible as a 2-3px
  // stroke on a #F0F9FF field, and the reminders card leans on its row strokes.
  borderStrong: "#7DD3FC",
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
//
// Every app-screen glyph below is the real Lucide path, copied out of
// lucide-react, because Lucide is what the design system mandates on web and
// what hub-surface.tsx / the Hub + Care + Family kits actually import. The
// mockups' own Unicode stand-ins are deliberately NOT ported: the Family kit
// draws its daily-summary icon as U+2600 and its visitor rows as U+1F6AA /
// U+1F6B6, which are exactly the emoji the design system's "no emoji as icons
// anywhere" rule bans and exactly the class of glyph that broke once here.
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

// --- Lucide, verbatim ------------------------------------------------------
// hub-surface.tsx imports: HeartHandshake, PhoneCall, BellRing, ShieldCheck,
// UserRoundCheck, CheckCircle2 (lucide's circle-check-big), AlertTriangle
// (triangle-alert), Clock, Pill, Utensils, Footprints, Check. The Care and
// Family tab bars use the nav set (bell-ring / clipboard-list / users /
// settings and sun / door-open / bell / lock-keyhole).
const L_HEART_HANDSHAKE = <path d="M19.414 14.414C21 12.828 22 11.5 22 9.5a5.5 5.5 0 0 0-9.591-3.676.6.6 0 0 1-.818.001A5.5 5.5 0 0 0 2 9.5c0 2.3 1.5 4 3 5.5l5.535 5.362a2 2 0 0 0 2.879.052 2.12 2.12 0 0 0-.004-3 2.124 2.124 0 1 0 3-3 2.124 2.124 0 0 0 3.004 0 2 2 0 0 0 0-2.828l-1.881-1.882a2.41 2.41 0 0 0-3.409 0l-1.71 1.71a2 2 0 0 1-2.828 0 2 2 0 0 1 0-2.828l2.823-2.762" />;
const L_PHONE_CALL = <><path d="M13 2a9 9 0 0 1 9 9" /><path d="M13 6a5 5 0 0 1 5 5" /><path d="M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 6.392 6.384" /></>;
const L_BELL_RING = <><path d="M10.268 21a2 2 0 0 0 3.464 0" /><path d="M22 8c0-2.3-.8-4.3-2-6" /><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326" /><path d="M4 2C2.8 3.7 2 5.7 2 8" /></>;
const L_BELL = <><path d="M10.268 21a2 2 0 0 0 3.464 0" /><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326" /></>;
const L_SHIELD_CHECK = <><path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z" /><path d="m9 12 2 2 4-4" /></>;
const L_USER_ROUND_CHECK = <><path d="M2 21a8 8 0 0 1 13.292-6" /><circle cx="10" cy="8" r="5" /><path d="m16 19 2 2 4-4" /></>;
const L_CHECK_CIRCLE = <><path d="M21.801 10A10 10 0 1 1 17 3.335" /><path d="m9 11 3 3L22 4" /></>;
const L_TRIANGLE_ALERT = <><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3" /><path d="M12 9v4" /><path d="M12 17h.01" /></>;
const L_CLOCK = <><circle cx="12" cy="12" r="10" /><path d="M12 6v6l4 2" /></>;
const L_PILL = <><path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z" /><path d="m8.5 8.5 7 7" /></>;
const L_UTENSILS = <><path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2" /><path d="M7 2v20" /><path d="M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7" /></>;
const L_FOOTPRINTS = <><path d="M4 16v-2.38C4 11.5 2.97 10.5 3 8c.03-2.72 1.49-6 4.5-6C9.37 2 10 3.8 10 5.5c0 3.11-2 5.66-2 8.68V16a2 2 0 1 1-4 0Z" /><path d="M20 20v-2.38c0-2.12 1.03-3.12 1-5.62-.03-2.72-1.49-6-4.5-6C14.63 6 14 7.8 14 9.5c0 3.11 2 5.66 2 8.68V20a2 2 0 1 0 4 0Z" /><path d="M16 17h4" /><path d="M4 13h4" /></>;
const L_CHECK = <path d="M20 6 9 17l-5-5" />;
const L_CLIPBOARD_LIST = <><rect width="8" height="4" x="8" y="2" rx="1" ry="1" /><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" /><path d="M12 11h4" /><path d="M12 16h4" /><path d="M8 11h.01" /><path d="M8 16h.01" /></>;
const L_USERS = <><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><path d="M16 3.128a4 4 0 0 1 0 7.744" /><path d="M22 21v-2a4 4 0 0 0-3-3.87" /><circle cx="9" cy="7" r="4" /></>;
const L_SETTINGS = <><path d="M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915" /><circle cx="12" cy="12" r="3" /></>;
const L_SUN = <><circle cx="12" cy="12" r="4" /><path d="M12 2v2" /><path d="M12 20v2" /><path d="m4.93 4.93 1.41 1.41" /><path d="m17.66 17.66 1.41 1.41" /><path d="M2 12h2" /><path d="M20 12h2" /><path d="m6.34 17.66-1.41 1.41" /><path d="m19.07 4.93-1.41 1.41" /></>;
const L_DOOR_OPEN = <><path d="M11 20H2" /><path d="M11 4.562v16.157a1 1 0 0 0 1.242.97L19 20V5.562a2 2 0 0 0-1.515-1.94l-4-1A2 2 0 0 0 11 4.561z" /><path d="M11 4H8a2 2 0 0 0-2 2v14" /><path d="M14 12h.01" /><path d="M22 20h-3" /></>;
const L_LOCK = <><circle cx="12" cy="16" r="1" /><rect x="3" y="10" width="18" height="12" rx="2" /><path d="M7 10V7a5 5 0 0 1 10 0v3" /></>;
const L_ACTIVITY = <path d="M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2" />;

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

// components/display/Card.jsx, variant "card": white surface, 1px border,
// --shadow-soft (a soft double shadow, never a hard drop shadow). Radius is
// passed per surface because the design system varies it deliberately -- Care
// 12 (tighter, clinical), Family 20 (warmer), web 16.
const SHADOW_SOFT = "0 1px 2px rgba(12,74,110,.04), 0 8px 24px rgba(12,74,110,.08)";
const Card = ({children, style}: {children: React.ReactNode; style?: React.CSSProperties}) => <div style={{background: C.surface, border: `1px solid ${C.border}`, borderRadius: 20, boxShadow: SHADOW_SOFT, ...style}}>{children}</div>;
// components/display/Badge.jsx. TONES pairs a base-colour tint at 1f alpha
// with the *Strong* text variant; LABELS are the fixed severity strings the
// design system forbids inventing synonyms for.
const BADGE = {
  critical: {tint: C.destructiveBase, text: C.destructive, label: "Emergency"},
  warning: {tint: C.warningBase, text: C.warning, label: "Needs attention"},
  success: {tint: C.successBase, text: C.success, label: "Resolved"},
  info: {tint: C.primary, text: C.primary, label: "Info"},
};
const Badge = ({tone, children, size = 22}: {tone: keyof typeof BADGE; children?: React.ReactNode; size?: number}) => {
  const t = BADGE[tone];
  return <span style={{display: "inline-flex", alignItems: "center", gap: 6, fontSize: size, fontWeight: 600,
                       padding: "7px 15px", borderRadius: 999, background: `${t.tint}1f`, color: t.text, whiteSpace: "nowrap"}}>{children ?? t.label}</span>;
};
// The iOS tab bar shared by the Care and Family kits: absolute, flush bottom,
// 1px top border, white, flex-1 items, minHeight 44 for the touch target.
// `badge` draws Care's unread dot on Alerts -- a plain dot, never a count,
// because a count would put a digit on screen.
type Tab = {key: string; label: string; glyph: React.ReactNode; badge?: boolean};
const TabBar = ({tabs, active, activeColor}: {tabs: Tab[]; active: string; activeColor?: (key: string) => string}) => (
  <div style={{position: "absolute", left: 0, right: 0, bottom: 0, display: "flex", background: C.surface,
               borderTop: `1px solid ${C.border}`, paddingBottom: 14, zIndex: 3}}>
    {tabs.map((t) => {
      const color = activeColor ? activeColor(t.key) : (t.key === active ? C.primary : C.foregroundMuted);
      return <div key={t.key} style={{flex: 1, minHeight: 44, padding: "13px 0 4px", display: "flex", flexDirection: "column",
                                     alignItems: "center", gap: 7, color, fontSize: 17, fontWeight: 600}}>
        <span style={{position: "relative", display: "block"}}>
          {svgGlyph(t.glyph, color, 27, 2)}
          {t.badge && <span style={{position: "absolute", top: -3, right: -6, width: 13, height: 13, borderRadius: "50%",
                                    background: C.destructiveBase, border: `2px solid ${C.surface}`}} />}
        </span>
        <span>{t.label}</span>
      </div>;
    })}
  </div>
);
// The kiosk's primary action button: 128px min-height, 18px radius, label row
// with a 44px glyph, then the .action-note sub-line. Scaled to the panel.
const ActionButton = ({label, note, glyph, bg, color, border, style, children}: {label: string; note: string; glyph: React.ReactNode; bg: string; color: string; border?: string; style?: React.CSSProperties; children?: React.ReactNode}) => (
  <div style={{minHeight: 104, borderRadius: 18, padding: 22, background: bg, color, border: border ?? "none",
               display: "flex", flexDirection: "column", gap: 8, justifyContent: "center", position: "relative", overflow: "hidden", ...style}}>
    <span style={{display: "flex", alignItems: "center", gap: 16, fontSize: 30, fontWeight: 800, letterSpacing: -0.6}}>
      {svgGlyph(glyph, color, 38, 2.25)}{label}
    </span>
    <span style={{fontSize: 20, fontWeight: 600, lineHeight: 1.3, color: color === "#ffffff" ? "rgba(255,255,255,.92)" : C.foregroundMuted}}>{note}</span>
    {children}
  </div>
);
// Tap affordance: a ring that expands out of the button centre and fades as it
// reaches full size. Without the fade the ring is still sitting on the button
// a second later, which reads as a rendering artefact rather than a press.
// color: the ring is white on the coloured buttons, but a reminder row is
// white-on-white, so that one presses in the success green instead.
// Bails out at size 0 rather than rendering: a zero-width circle still paints
// its 3px border, which left a stray 6px dot sitting on every button that had
// not been pressed yet.
const Ripple = ({size, opacity, color = "rgba(255,255,255,.7)"}: {size: number; opacity: number; color?: string}) => size <= 0 ? null : <span style={{position: "absolute", left: "50%", top: "50%", marginLeft: -size / 2, marginTop: -size / 2, width: size, height: size, borderRadius: "50%", border: `3px solid ${color}`, opacity, pointerEvents: "none"}} />;
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
    <div style={{opacity: bridge, marginTop: 16, marginLeft: 5, color: C.mint, fontSize: 37, fontWeight: 700, letterSpacing: -0.5, padding: "0 30px"}}>Only the alert does. Here is where it goes.</div>
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
  {at: 8, label: "CAMERA", sub: "Always watching, right inside the building", glyph: GLYPH_CAMERA},
  // "17-point" stays numeric. The no-digits rule targets METRICS a judge would
  // ask us to source -- latency, room counts, ARR. This is a product
  // descriptor, it is the deck's own slide-6 wording, and "Seventeen-point"
  // reads as an affectation.
  {at: 32, label: "POSE READ ON SITE", sub: "A skeleton of 17 points, read right here in the room", glyph: GLYPH_CPU},
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
// The Care kit's tab bar. The bundled kit ships three tabs; the mockup adds
// Settings and the unread marker on Alerts, so this is the four-tab bar.
const CARE_TABS: Tab[] = [
  {key: "alerts", label: "Alerts", glyph: L_BELL_RING, badge: true},
  {key: "handoff", label: "Handoff", glyph: L_CLIPBOARD_LIST},
  {key: "residents", label: "Residents", glyph: L_USERS},
  {key: "settings", label: "Settings", glyph: L_SETTINGS},
];
// IncidentRow from the Care kit: a Badge and a relative time on one row, then
// the resident-first summary at 17/500, then the status label -- separated by a
// 1px rule, not boxed in a card. The kit's own times ("2m ago", "14m ago") are
// digits, so they carry the same information in words.
const IncidentRow = ({tone, when, copy, status, statusColor, children, style}: {tone: keyof typeof BADGE; when: string; copy: string; status: string; statusColor?: string; children?: React.ReactNode; style?: React.CSSProperties}) => (
  <div style={{padding: "20px 4px", borderBottom: `1px solid ${C.border}`, ...style}}>
    <div style={{display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 11}}>
      <Badge tone={tone} />
      <span style={{fontSize: 21, color: C.foregroundMuted}}>{when}</span>
    </div>
    <div style={{fontWeight: 500, fontSize: 29, lineHeight: 1.24}}>{copy}</div>
    <div style={{fontSize: 21, color: statusColor ?? C.foregroundMuted, fontWeight: statusColor ? 700 : 400, marginTop: 5}}>{status}</div>
    {children}
  </div>
);
const CareScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.careOffset;
  // In from 271 (the frame the pipeline's plate starts clearing) to 285; out on
  // the 425-435 cross-dissolve into MeridianHub.
  const beat = ramp(raw, [3, 17, 157, 167], [0, 1, 1, 0]);
  const phoneY = clamp(local, [0, 14], [24, 0]);
  const listIn = ramp(local, [0, 14], [0, 1]);
  // The urgent-alert modal is how a critical alert actually reaches a phone:
  // full screen, before the list. One arrival pop (0.92 -> 1.02 -> 1) per the
  // motion guideline's "exactly one scale/pop-in, then hold steady", never a
  // repeating pulse.
  const modalIn = ramp(local, [8, 20], [0, 1]);
  const modalScale = clamp(local, [8, 16, 22], [0.92, 1.02, 1]);
  const ackRipple = clamp(local, [46, 60], [0, 300]);
  const ackRippleFade = ramp(local, [50, 60], [1, 0]);
  const modalOut = ramp(local, [58, 70], [1, 0]);
  const modalY = clamp(local, [58, 70], [0, 60]);
  // Actions shifted inside the beat (allowed) to buy the modal its screen time.
  // Last action now finishes at local 136, well before the beat's 155.
  const acknowledged = local >= 62;
  const respRipple = clamp(local, [92, 108], [0, 300]);
  const respRippleFade = ramp(local, [100, 108], [1, 0]);
  const responding = local >= 108;
  const responsePanel = ramp(local, [114, 136], [0, 1]);
  const responseY = clamp(local, [114, 136], [22, 0]);
  return <Background opacity={beat}><div style={{position: "absolute", left: 205, top: 150, width: 790}}>
    <AppName>MeridianCare</AppName>
    <AudienceLine>For caregivers working the night shift</AudienceLine>
    <div style={{fontSize: 44, letterSpacing: -1.5, fontWeight: 780, marginTop: 26}}>Care, in sync.</div>
    <StoryLine>The instant Maggie falls, her care team knows.</StoryLine>
  </div><div style={{position: "absolute", right: 270, top: 55, translate: `0 ${phoneY}px`}}><Device label="MeridianCare caregiver alerts">
    <div style={{padding: "70px 24px 0", height: "100%", opacity: listIn}}>
      <h1 style={{fontFamily: "inherit", fontWeight: 600, fontSize: 40, letterSpacing: -1.1, margin: "6px 0 16px"}}>Alerts</h1>
      <IncidentRow tone="critical" when="Just now" copy="Maggie may need help in Room 101."
                   status={responding ? "Responding" : acknowledged ? "Acknowledged" : "Open"}
                   statusColor={responding ? C.success : acknowledged ? C.warning : undefined}>
        {acknowledged && !responding && (
          // NEXT_ACTIONS.Acknowledged leads with "Mark responding". The kit puts
          // that button on the incident-detail screen; the beat has no room for a
          // push transition, so it sits on the row it belongs to.
          <div style={{marginTop: 16, padding: "16px", borderRadius: 10, background: C.primary, color: "white",
                       fontWeight: 700, fontSize: 24, textAlign: "center", position: "relative", overflow: "hidden"}}>
            Mark responding<Ripple size={respRipple} opacity={respRippleFade} />
          </div>
        )}
      </IncidentRow>
      {/* The kit's second open incident. "Long lie" is a real detector; its own
          copy ("still for 20 minutes in Room 4") carries digits and a second
          room number, so the duration is stated in words and the room dropped. */}
      <IncidentRow tone="warning" when="Earlier tonight" copy="Walter has been still for an unusually long time." status="Acknowledged" />
      {responding && (
        <Card style={{borderRadius: 12, padding: 22, marginTop: 22, opacity: responsePanel, translate: `0 ${responseY}px`}}>
          <div style={{fontSize: 20, fontWeight: 600, color: C.foregroundMuted, letterSpacing: 1.1}}>RESPONSE</div>
          <div style={{fontSize: 27, fontWeight: 600, marginTop: 8, display: "flex", alignItems: "center", gap: 12}}>
            {svgGlyph(L_CHECK_CIRCLE, C.success, 28, 2.2)}<span>Care team is responding.</span>
          </div>
        </Card>
      )}
    </div>
    <TabBar tabs={CARE_TABS} active="alerts" />
    {local < 72 && (
      <div style={{position: "absolute", inset: 0, zIndex: 6, background: C.destructive, color: "white",
                   display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center",
                   padding: "0 44px", textAlign: "center", opacity: modalIn * modalOut,
                   scale: modalScale, translate: `0 ${modalY}px`}}>
        {svgGlyph(L_TRIANGLE_ALERT, "#ffffff", 94, 2)}
        <div style={{marginTop: 30, fontSize: 22, fontWeight: 800, letterSpacing: 3.4, color: "rgba(255,255,255,.82)"}}>URGENT ALERT</div>
        <div style={{marginTop: 14, fontSize: 62, fontWeight: 800, letterSpacing: -1.8, lineHeight: 1}}>Emergency</div>
        <div style={{marginTop: 16, fontSize: 38, fontWeight: 600, color: "rgba(255,255,255,.92)"}}>Room 101</div>
        <div style={{marginTop: 46, width: "100%", padding: "20px", borderRadius: 10, background: "#ffffff",
                     color: C.destructive, fontWeight: 800, fontSize: 27, position: "relative", overflow: "hidden"}}>
          Acknowledge<Ripple size={ackRipple} opacity={ackRippleFade} color="rgba(153,27,27,.55)" />
        </div>
        <div style={{marginTop: 16, width: "100%", padding: "18px", borderRadius: 10,
                     border: "2px solid rgba(255,255,255,.75)", fontWeight: 700, fontSize: 25}}>View alert</div>
      </div>
    )}
  </Device></div></Background>;
};

// Shared Hub chrome. Beats 4 and 5 are the same physical device on stage, so
// they share the frame and only the card inside it changes -- which is exactly
// what the 540-550 swap has to sell. The panel geometry is deliberately shared:
// the help beat now carries the reminders checklist as well, so the header and
// paddings are tighter than they were and the card starts just under the brand
// mark, which is what buys that card its room.
// The kiosk page surface is --color-background-mobile, not white: its cards are
// white ON that, which the previous white-on-white panel could not show. Header
// is the kit's own lockup -- an .eyebrow reading "MeridianHub · Room <id>", the
// .title, then the .subhead.
const HubFrame = ({title, sub, bgOpacity, contentOpacity, panelX, children}: {title: string; sub: string; bgOpacity: number; contentOpacity: number; panelX: number; children: React.ReactNode}) => (
  <Background opacity={bgOpacity}>
    <div style={{position: "absolute", left: 140, top: 142, width: 740, opacity: contentOpacity}}>
      <AppName>MeridianHub</AppName>
      <AudienceLine>For residents like Maggie</AudienceLine>
      <div style={{fontSize: 44, fontWeight: 780, lineHeight: 1.08, letterSpacing: -1.5, marginTop: 26}}>{title}</div>
      <div style={{fontSize: 30, color: C.foregroundMuted, lineHeight: 1.38, marginTop: 28}}>{sub}</div>
    </div>
    <div style={{position: "absolute", right: 215, top: 92, width: 770, minHeight: 972, padding: 36, borderRadius: 42, background: C.backgroundMobile, boxShadow: "0 30px 80px rgba(12,74,110,.18)", opacity: contentOpacity, translate: `${panelX}px 0`}}>
      <div style={{fontSize: 20, color: C.foregroundMuted, fontWeight: 700, margin: "0 0 9px"}}>MeridianHub &middot; Room 101</div>
      <h1 style={{fontSize: 50, fontWeight: 800, letterSpacing: -1.6, lineHeight: 1.08, margin: 0}}>Hello, Maggie</h1>
      <p style={{fontSize: 22, lineHeight: 1.35, color: C.foregroundMuted, margin: "14px 0 0"}}>Choose what you need. Your care team is here to help.</p>
      {children}
    </div>
  </Background>
);

// Beat 4 -- frames 430-545 (local 0-115). Mounted five frames early so the
// cross-dissolve out of MeridianCare has something to dissolve to.
const HUB_STEPS = ["Your request was sent", "A caregiver has seen it", "A caregiver is on the way"];
// The shipped Today's reminders checklist (b14a18b), verbatim. A reminder the
// resident can tick is a PROMPT, not an observation, which is why it is allowed
// here while the family-facing "she ate breakfast" row still is not: nothing in
// the system observes a meal. The shipped card also shows a "n of n done" count
// and a clock time per row; both are digits, so both are dropped -- the
// progress bar carries the same information without a number.
// Four rows, sorted by scheduled time as TodaysReminders does: the morning dose
// (already taken), lunch, the walk, then the evening dose. Icons are the shipped
// Lucide set -- Pill / Utensils / Footprints.
const HUB_REMINDERS: [string, React.ReactNode][] = [
  ["Take your medication", L_PILL],
  ["Time for lunch", L_UTENSILS],
  ["Afternoon walk", L_FOOTPRINTS],
  ["Take your medication", L_PILL],
];
const HubHelpScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.hubOffset;
  const bgOpacity = ramp(raw, [115, 125], [1, 0]);
  const contentOpacity = ramp(raw, [0, 10], [0, 1]);
  // The panel leaves to the left as the visitor card arrives from the right.
  const panelX = clamp(local, [110, 120], [0, -40]);
  // Phase A: the three-way choice. Phase B: what the kiosk does once one is
  // pressed -- the grid collapses to the live status card, exactly as
  // hub-surface.tsx does, which is also what frees the vertical room the
  // reminders card needs. The swap is a HARD CUT, deliberately: the two stacks
  // are mutually exclusive mounts, so an opacity ramp on either side cannot
  // cross-fade anything -- the grid unmounts at once and the card would fade up
  // from zero, leaving the panel visually empty for most of a second around
  // absolute frame 470 (measured: card ink fell from 182k to 15k). A real
  // kiosk repaints instantly too. Only a small scale pop marks the arrival.
  const requested = local >= 40;
  const askRipple = clamp(local, [24, 40], [0, 620]);
  const askRippleFade = ramp(local, [30, 40], [1, 0]);
  const statusScale = clamp(local, [40, 50], [0.97, 1]);
  const etaIn = ramp(local, [62, 74], [0, 1]);
  const remindersIn = ramp(local, [56, 70], [0, 1]);
  const remindersY = clamp(local, [56, 70], [14, 0]);
  // Maggie ticks the lunch row off herself. Row-wide flash rather than an
  // expanding ring: the row is short and clips a circle into a lens.
  const tapFlash = ramp(local, [84, 90, 100], [0, 1, 0]);
  const ticked = local >= 92;
  // Two of four rows done once lunch is ticked (the morning dose is already
  // taken), so the bar runs to half. Wordless, so it carries no digit.
  const progress = ramp(local, [92, 104], [25, 50]);
  return <HubFrame title="Help is on the way." sub="And Maggie sees it too, every step of it, right from her own room." bgOpacity={bgOpacity} contentOpacity={contentOpacity} panelX={panelX}>
    {!requested && (
      <div style={{display: "grid", gap: 20, marginTop: 26}}>
        <ActionButton label="Request assistance" note="Ask a caregiver to come to your room." glyph={L_HEART_HANDSHAKE} bg={C.primary} color="#ffffff">
          <Ripple size={askRipple} opacity={askRippleFade} />
        </ActionButton>
        <ActionButton label="Call family" note="Ask your family contact to call you." glyph={L_PHONE_CALL} bg={C.surface} color={C.foreground} border={`4px solid ${C.primary}`} />
        <ActionButton label="Emergency help" note="Send an urgent alert to the care team now." glyph={L_BELL_RING} bg={C.destructive} color="#ffffff" />
      </div>
    )}
    {requested && <>
      {/* .status-card: a 12px coloured left border rather than a full keyline --
          the design system keeps this older kiosk-specific pattern precisely
          because of its stakes. Position and a check mark carry the step
          progress, never colour alone. */}
      <div style={{marginTop: 20, padding: 22, background: C.surface, border: `3px solid ${C.border}`, borderRadius: 20,
                   borderLeft: `12px solid ${C.primary}`, boxShadow: "0 4px 18px rgba(12,74,110,.12)",
                   scale: statusScale}}>
        <div style={{display: "flex", alignItems: "center", gap: 10, color: C.foregroundMuted, fontWeight: 700, fontSize: 20, margin: "0 0 7px"}}>
          {svgGlyph(L_SHIELD_CHECK, C.foregroundMuted, 24, 2)}<span>Help status</span>
        </div>
        <h2 style={{fontSize: 30, lineHeight: 1.15, margin: 0, fontWeight: 700}}>Help is coming. A caregiver is on the way.</h2>
        <div style={{display: "grid", gap: 8, margin: "15px 0 0"}}>
          {HUB_STEPS.map((step, i) => {
            const start = 42 + i * 6;
            const rowIn = ramp(local, [start, start + 10], [0, 1]);
            const done = local >= start + 6;
            const tint = done ? C.success : C.foregroundMuted;
            return <div key={step} style={{display: "flex", alignItems: "center", gap: 12, fontSize: 20, fontWeight: 700, color: tint, opacity: rowIn}}>
              {svgGlyph(done ? L_CHECK_CIRCLE : L_CLOCK, tint, 26, 2)}<span>{step}</span>
            </div>;
          })}
        </div>
        {/* .eta. The shipped surface really does derive this from recent
            acknowledgement times and label its confidence, so the block is
            honest -- but its figure is a digit, so the derived estimate is
            stated in words and the sub-line keeps naming what it rests on. */}
        <div style={{marginTop: 16, padding: 14, background: C.border, borderRadius: 12, fontWeight: 800, fontSize: 21, opacity: etaIn}}>
          Someone should reach you shortly.
          <span style={{display: "block", color: C.foregroundMuted, fontWeight: 600, fontSize: 18, lineHeight: 1.35, marginTop: 6}}>
            Based on this facility&rsquo;s recent staff acknowledgement times.
          </span>
        </div>
      </div>
      <div style={{marginTop: 16, padding: 22, background: C.surface, border: `3px solid ${C.border}`, borderRadius: 20,
                   boxShadow: "0 4px 18px rgba(12,74,110,.12)", opacity: remindersIn, translate: `0 ${remindersY}px`}}>
        {/* .reminders-head also carries a "{done} of {total} done" count. That is
            a digit, and the progress bar states the same thing wordlessly. */}
        <div style={{fontSize: 28, fontWeight: 700, letterSpacing: -0.6}}>Today&rsquo;s reminders</div>
        <div style={{fontSize: 19, color: C.foregroundMuted, marginTop: 5}}>Tap a reminder when you&rsquo;ve done it.</div>
        <div style={{marginTop: 12, height: 13, borderRadius: 999, background: C.background, border: `2px solid ${C.borderStrong}`, overflow: "hidden"}}>
          <div style={{height: "100%", borderRadius: 999, background: C.success, width: `${progress}%`}} />
        </div>
        <div style={{display: "grid", gap: 8, marginTop: 13}}>
          {HUB_REMINDERS.map(([label, glyph], i) => {
            const start = 60 + i * 4;
            const rowIn = ramp(local, [start, start + 9], [0, 1]);
            // Row 0 is the morning dose, already taken. Row 1 is lunch, which
            // Maggie ticks on screen. `nextId` is the first not-done row, so
            // the UP NEXT tag starts on lunch and moves to the walk.
            const done = i === 0 || (i === 1 && ticked);
            const next = ticked ? i === 2 : i === 1;
            return <div key={`${label}${i}`} style={{display: "flex", alignItems: "center", gap: 15, minHeight: 48, padding: "7px 13px", borderRadius: 16,
                                           border: next ? `4px solid ${C.primary}` : `3px solid ${C.borderStrong}`,
                                           background: done ? C.background : C.surface, opacity: rowIn, position: "relative", overflow: "hidden"}}>
              <span style={{width: 38, height: 38, borderRadius: 12, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center", background: done ? C.success : C.border}}>{svgGlyph(glyph, done ? "#ffffff" : C.primary, 22, 2)}</span>
              <span style={{flex: 1, minWidth: 0, display: "flex", alignItems: "center", gap: 10}}>
                <span style={{fontSize: 19, fontWeight: 700, color: done ? C.foregroundMuted : C.foreground, textDecoration: done ? "line-through" : "none"}}>{label}</span>
                {next && <span style={{flex: "none", fontSize: 14, fontWeight: 800, color: "#ffffff", background: C.primary, padding: "3px 10px", borderRadius: 999, textTransform: "uppercase", letterSpacing: 0.6}}>Up next</span>}
              </span>
              <span style={{width: 28, height: 28, borderRadius: "50%", flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center", border: `3px solid ${done ? C.success : C.borderStrong}`, background: done ? C.success : "transparent"}}>{done && svgGlyph(L_CHECK, "#ffffff", 15, 3)}</span>
              {i === 1 && <div style={{position: "absolute", inset: 0, background: C.success, opacity: tapFlash * 0.16, pointerEvents: "none"}} />}
            </div>;
          })}
        </div>
      </div>
    </>}
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
  return <HubFrame title="Your voice matters." sub="Not just falls. When someone she does not know turns up, it is her call." bgOpacity={bgOpacity} contentOpacity={contentOpacity} panelX={panelX}>
    {/* .visitor-card: a 5px full primary keyline, not a left border -- the kiosk
        reserves the left-border pattern for live help status. */}
    <div style={{marginTop: 30, padding: 28, background: C.surface, border: `5px solid ${C.primary}`, borderRadius: 20}}>
      <div style={{display: "flex", alignItems: "center", gap: 10, color: C.foregroundMuted, fontWeight: 700, fontSize: 21, margin: "0 0 9px"}}>
        {svgGlyph(L_USER_ROUND_CHECK, C.foregroundMuted, 25, 2)}<span>Visitor check</span>
      </div>
      <h2 style={{fontSize: 42, lineHeight: 1.1, margin: 0, fontWeight: 700}}>Is this person expected?</h2>
      {/* The kit's own detail line, minus its "Detected at 2:15pm." sentence. */}
      <p style={{fontSize: 24, lineHeight: 1.4, color: C.foregroundMuted, margin: "18px 0"}}>An unfamiliar visitor was detected at your assigned entry camera.</p>
      <div style={{display: "grid", gridTemplateColumns: "1fr 1fr", gap: 18, opacity: buttonIn, translate: `0 ${buttonY}px`}}>
        <div style={{minHeight: 88, borderRadius: 16, background: C.success, color: "white", fontWeight: 800, fontSize: 24, display: "flex", alignItems: "center", justifyContent: "center", gap: 12, position: "relative", overflow: "hidden", filter: `brightness(${brighten})`}}>{svgGlyph(L_CHECK_CIRCLE, "#ffffff", 30, 2.25)}<span>Yes, expected</span><Ripple size={ripple} opacity={rippleFade} /></div>
        <div style={{minHeight: 88, borderRadius: 16, background: C.destructive, color: "white", fontWeight: 800, fontSize: 24, display: "flex", alignItems: "center", justifyContent: "center", gap: 12}}>{svgGlyph(L_BELL_RING, "#ffffff", 30, 2.25)}<span>No, get help</span></div>
      </div>
    </div>
    {/* .notice.success. The confirmation is the one the shipped surface actually
        returns for an "expected" answer. The comp previously showed the *denied*
        branch's copy here -- promising a caregiver would come and check after
        Maggie said the visitor was expected, which is not what the code does. */}
    <div style={{marginTop: 24, padding: 22, borderRadius: 14, background: C.surface, border: `4px solid ${C.success}`,
                 fontWeight: 800, fontSize: 26, lineHeight: 1.35, color: C.success, display: "flex", alignItems: "center", gap: 14, opacity: answer}}>
      {svgGlyph(L_CHECK_CIRCLE, C.success, 32, 2.2)}<span>Thank you. Your answer was saved.</span>
    </div>
  </HubFrame>;
};

// Beat 6 -- frames 675-840 (local 0-165). Carries the 6f fade to deck navy
// that hands the last thirty frames to the end card.
const FAMILY_TABS: Tab[] = [
  {key: "today", label: "Today", glyph: L_SUN},
  {key: "visitors", label: "Visitors", glyph: L_DOOR_OPEN},
  {key: "updates", label: "Updates", glyph: L_BELL},
  {key: "privacy", label: "Privacy", glyph: L_LOCK},
];
// A section rule from the Updates screen: 12/600 uppercase, muted.
const FamilySection = ({children, style}: {children: React.ReactNode; style?: React.CSSProperties}) => (
  <div style={{fontSize: 20, fontWeight: 600, color: C.foregroundMuted, textTransform: "uppercase", letterSpacing: 1, ...style}}>{children}</div>
);
const FamilyScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.familyOffset;
  const contentOpacity = ramp(raw, [0, 10], [0, 1]);
  const phoneY = clamp(local, [0, 12], [24, 0]);
  // Beat 6 shows both of the Family kit's load-bearing tabs, because the
  // mandated content corrections land on both: Today first -- the calm daily
  // baseline -- then a real tab change to Updates, where the alert and the
  // staff response arrive. The tab bar does the transition, as it does in the app.
  const todayIn = ramp(local, [8, 22], [0, 1]);
  const todayOut = ramp(local, [58, 64], [1, 0]);
  const onUpdates = local >= 62;
  const updatesIn = ramp(local, [64, 74], [0, 1]);
  const notification = ramp(local, [78, 94], [0, 1]);
  const notificationY = clamp(local, [78, 94], [-70, 0]);
  const responseCard = ramp(local, [100, 118], [0, 1]);
  const responseY = clamp(local, [100, 118], [24, 0]);
  // Resolution stated in colour, not in a new line of copy: the amber ring on
  // the original alert cools to the green of the response.
  const resolved = interpolateColors(ramp(local, [126, 150], [0, 1]), [0, 1], [C.warning, C.success]);
  const toNavy = ramp(raw, [166, 172], [0, 1]);
  // The active tint crosses over with the tab change rather than snapping.
  const tabShift = ramp(local, [62, 70], [0, 1]);
  const tabTint = (key: string) => {
    if (key === "today") return interpolateColors(tabShift, [0, 1], [C.primary, C.foregroundMuted]);
    if (key === "updates") return interpolateColors(tabShift, [0, 1], [C.foregroundMuted, C.primary]);
    return C.foregroundMuted;
  };
  return <Background>
    <div style={{position: "absolute", left: 200, top: 158, width: 790, opacity: contentOpacity}}>
      <AppName>MeridianFamily</AppName>
      <AudienceLine>For worried families</AudienceLine>
      <div style={{fontSize: 44, lineHeight: 1.08, letterSpacing: -1.5, fontWeight: 780, marginTop: 26}}>Stay informed. Stay close.</div>
      <StoryLine>And her family sees the same story, including how it ends.</StoryLine>
    </div>
    <div style={{position: "absolute", right: 280, top: 55, opacity: contentOpacity, translate: `0 ${phoneY}px`}}><Device label="MeridianFamily daily summary and updates">
      {!onUpdates && (
        <div style={{padding: "70px 26px 0", opacity: todayIn * todayOut}}>
          <h1 style={{fontWeight: 600, fontSize: 40, letterSpacing: -1.1, margin: "6px 0 20px"}}>Today</h1>
          {/* DailySummary's success-tinted card. Its headline was "Maggie had a
              good day" -- a wellbeing judgement pose cannot make -- and its
              detail line claimed she "ate all three meals", which nothing in
              the system observes. Both are replaced by the rollup category and
              the shipped room-attributed sentence. */}
          <div style={{background: "rgba(5,150,105,.06)", border: "1px solid rgba(5,150,105,.2)", borderRadius: 20, padding: 24}}>
            <div style={{display: "flex", gap: 14, alignItems: "center"}}>
              <span style={{width: 52, height: 52, borderRadius: 15, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center", background: `${C.successBase}1f`}}>
                {svgGlyph(L_ACTIVITY, C.success, 30, 2.1)}
              </span>
              <div>
                <div style={{fontWeight: 600, fontSize: 28, letterSpacing: -0.5}}>Usual room movement</div>
                <div style={{fontSize: 20, color: C.foregroundMuted, marginTop: 3}}>Today</div>
              </div>
            </div>
            <div style={{fontSize: 23, lineHeight: 1.4, color: C.foregroundMuted, marginTop: 16}}>
              The movement we saw in Maggie&rsquo;s room followed its usual rhythm today.
            </div>
            <div style={{height: 1, background: C.border, margin: "18px 0"}} />
            <div style={{display: "flex", flexDirection: "column", gap: 12}}>
              {["A new visitor came to the main entrance.", "Overnight movement followed its usual rhythm too."].map((line, i) => {
                const rowIn = ramp(local, [26 + i * 8, 38 + i * 8], [0, 1]);
                return <div key={line} style={{display: "flex", gap: 12, alignItems: "flex-start", fontSize: 21, lineHeight: 1.35, color: C.foregroundMuted, opacity: rowIn}}>
                  {/* The kit draws these bullets as U+25CF. A span is a shape, not a glyph. */}
                  <span style={{width: 10, height: 10, borderRadius: "50%", background: C.primary, flexShrink: 0, marginTop: 9}} />
                  <span>{line}</span>
                </div>;
              })}
            </div>
          </div>
        </div>
      )}
      {onUpdates && (
        <div style={{padding: "70px 26px 0", opacity: updatesIn}}>
          <h1 style={{fontWeight: 600, fontSize: 40, letterSpacing: -1.1, margin: "6px 0 20px"}}>Updates</h1>
          <FamilySection style={{marginBottom: 11}}>Staff responses</FamilySection>
          {/* Both staff cards keep their space reserved from the tab change, so
              neither arrival reflows the sections under it. */}
          <Card style={{borderRadius: 20, padding: 22, borderLeft: `7px solid ${resolved}`, opacity: notification, translate: `0 ${notificationY}px`}}>
            <div style={{display: "flex", gap: 14}}>{svgGlyph(L_TRIANGLE_ALERT, C.warning, 29, 2.2)}<div>
              <div style={{fontSize: 25, fontWeight: 600, lineHeight: 1.28}}>Maggie may need help in Room 101.</div>
              <div style={{fontSize: 20, color: C.foregroundMuted, marginTop: 7}}>Care team has been alerted.</div>
            </div></div>
          </Card>
          {/* The kit's staff-response line ended "staff responded in 90 seconds."
              No such figure is verified end to end, so it says what is actually
              known: someone came, and stayed. */}
          <Card style={{borderRadius: 20, padding: 22, marginTop: 12, opacity: responseCard, translate: `0 ${responseY}px`}}>
            <div style={{display: "flex", gap: 14}}>{svgGlyph(L_CHECK_CIRCLE, C.success, 29, 2.2)}<div>
              <div style={{fontSize: 25, fontWeight: 600, lineHeight: 1.28}}>Maggie needed help in Room 101. Someone came, and stayed with her.</div>
              <div style={{fontSize: 20, color: C.foregroundMuted, marginTop: 7}}>Maggie is not alone.</div>
            </div></div>
          </Card>
          <FamilySection style={{margin: "20px 0 11px"}}>Visitors</FamilySection>
          <Card style={{borderRadius: 20, padding: 22}}>
            <div style={{display: "flex", gap: 14, alignItems: "center"}}>{svgGlyph(L_DOOR_OPEN, C.primary, 27, 2.1)}
              <div style={{fontSize: 22, lineHeight: 1.3}}>New visitor detected at Main Entrance.</div>
            </div>
          </Card>
        </div>
      )}
      <TabBar tabs={FAMILY_TABS} active={onUpdates ? "updates" : "today"} activeColor={tabTint} />
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
