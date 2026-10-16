import React from "react";
import { Composition } from "remotion";
import { Launch } from "./launch";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="Launch"
      component={Launch}
      durationInFrames={720}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
