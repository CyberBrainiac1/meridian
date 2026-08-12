import "./index.css";
import { MeridianDemo } from "./Composition";
import { MeridianExplainer } from "./Explainer";
import { Composition } from "remotion";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* The 29 second reel, which plays beside the deck. */}
      <Composition
        id="MeridianDemo"
        component={MeridianDemo}
        durationInFrames={870}
        fps={30}
        width={1920}
        height={1080}
      />
      {/* The 2 minute standalone explainer, which plays alone and therefore
          carries its own evidence. */}
      <Composition
        id="MeridianExplainer"
        component={MeridianExplainer}
        durationInFrames={3600}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
