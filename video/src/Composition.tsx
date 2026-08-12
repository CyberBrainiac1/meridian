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
  C,
  CareDevice,
  clamp,
  CLIP_START,
  DarkCaption,
  EndCard,
  FamilyDevice,
  FullVideo,
  HubFrame,
  HubHelpPanel,
  HubVisitorPanel,
  PipelineDiagram,
  ramp,
  StoryLine,
  Vignette,
} from "./shared";

// Every token, easing helper, inline SVG path, design-system primitive and app
// screen this file draws lives in ./shared, which the 2 minute explainer
// (Explainer.tsx) imports from too. What stays here is what belongs to the 29
// second reel alone: its cut map, its copy, and its music envelope.

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

// Beat 1 -- frames 0-155. It no longer dips out: the pipeline beat that follows
// is the same near-black surface, so the cut at 155 is invisible and the only
// luminance handoff in the dark half of the reel is at 268-275.
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
    <Vignette />
    <DarkCaption opacity={1} y={captionY} privacy={caption} bridge={bridge} />
  </AbsoluteFill>;
};

// Beat 2 -- frames 155-275 (local 0-120). The connective tissue: how a person
// on the floor becomes a phone buzzing in a caregiver's pocket, which the reel
// previously asked the viewer to infer.
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
  return <AbsoluteFill style={{opacity: plate}}>
    <AbsoluteFill style={{background: C.dark}} />
    <AbsoluteFill style={{opacity: content}}>
    {/* startFrom lands on clip frame 213 -- beat 1's last frame plus one, and
        inside the clip's 80 held frames. playbackRate .5 walks 120 comp frames
        over 60 clip frames so the request never runs past the 291-frame clip
        while staying on the held floor pose. */}
    <AbsoluteFill style={{opacity: skeleton, mixBlendMode: "screen"}}><FullVideo src="skeleton.mp4" startFrom={CLIP_START + T.fallEnd} scale={zoom} playbackRate={0.5} /></AbsoluteFill>
    <Vignette />
    <PipelineDiagram local={local} />
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
  return <Background opacity={beat}><div style={{position: "absolute", left: 205, top: 150, width: 790}}>
    <AppName>MeridianCare</AppName>
    <AudienceLine>For caregivers working the night shift</AudienceLine>
    <div style={{fontSize: 44, letterSpacing: -1.5, fontWeight: 780, marginTop: 26}}>Care, in sync.</div>
    <StoryLine>The instant Maggie falls, her care team knows.</StoryLine>
  </div><CareDevice local={local} style={{position: "absolute", right: 270, top: 55}} /></Background>;
};

// Beat 4 -- frames 430-545 (local 0-115). Mounted five frames early so the
// cross-dissolve out of MeridianCare has something to dissolve to.
const HubHelpScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.hubOffset;
  const bgOpacity = ramp(raw, [115, 125], [1, 0]);
  const contentOpacity = ramp(raw, [0, 10], [0, 1]);
  // The panel leaves to the left as the visitor card arrives from the right.
  const panelX = clamp(local, [110, 120], [0, -40]);
  return <HubFrame title="Help is on the way." sub="And Maggie sees it too, every step of it, right from her own room." bgOpacity={bgOpacity} contentOpacity={contentOpacity} panelX={panelX}>
    <HubHelpPanel local={local} />
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
  return <HubFrame title="Your voice matters." sub="Not just falls. When someone she does not know turns up, it is her call." bgOpacity={bgOpacity} contentOpacity={contentOpacity} panelX={panelX}>
    <HubVisitorPanel local={local} />
  </HubFrame>;
};

// Beat 6 -- frames 675-840 (local 0-165). Carries the 6f fade to deck navy
// that hands the last thirty frames to the end card.
const FamilyScreen = () => {
  const raw = useCurrentFrame();
  const local = raw - T.familyOffset;
  const contentOpacity = ramp(raw, [0, 10], [0, 1]);
  const toNavy = ramp(raw, [166, 172], [0, 1]);
  return <Background>
    <div style={{position: "absolute", left: 200, top: 158, width: 790, opacity: contentOpacity}}>
      <AppName>MeridianFamily</AppName>
      <AudienceLine>For worried families</AudienceLine>
      <div style={{fontSize: 44, lineHeight: 1.08, letterSpacing: -1.5, fontWeight: 780, marginTop: 26}}>Stay informed. Stay close.</div>
      <StoryLine>And her family sees the same story, including how it ends.</StoryLine>
    </div>
    <FamilyDevice local={local} style={{position: "absolute", right: 280, top: 55, opacity: contentOpacity}} />
    <AbsoluteFill style={{background: C.deckNavy, opacity: toNavy, pointerEvents: "none"}} />
  </Background>;
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
  <BrandMark darkEnd={T.darkEnd} fade={[0, 18, 826, 840]} />
</AbsoluteFill>;
