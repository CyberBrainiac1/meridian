import "./index.css";
import { MeridianDemo } from "./Composition";
import { Composition } from "remotion";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="MeridianDemo"
      component={MeridianDemo}
      durationInFrames={870}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
