/**
 * BurnFuse launch reel — root composition.
 * 1920×1080 · 30 fps · 720 frames (24.0 s) · score at 150 BPM (beat = 12 f).
 */
import React from "react";
import { AbsoluteFill, Audio, Sequence, staticFile, useCurrentFrame } from "remotion";
import { Hook, Climb, Trip, Flow, Product, States, Brand } from "./scenes";

export const Launch: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ background: "#0c0c0c" }}>
      <Audio src={staticFile("sound/launch-score.m4a")} />

      <Sequence from={0} durationInFrames={48} premountFor={30}>
        <Hook />
      </Sequence>
      <Sequence from={48} durationInFrames={96} premountFor={30}>
        <Climb />
      </Sequence>
      <Sequence from={144} durationInFrames={48} premountFor={30}>
        <Trip />
      </Sequence>
      <Sequence from={192} durationInFrames={144} premountFor={30}>
        <Flow />
      </Sequence>
      <Sequence from={336} durationInFrames={144} premountFor={30}>
        <Product />
      </Sequence>
      <Sequence from={480} durationInFrames={144} premountFor={30}>
        <States />
      </Sequence>
      <Sequence from={624} durationInFrames={96} premountFor={30}>
        <Brand />
      </Sequence>

      {/* persistent corner watermark — not on the endcard */}
      {frame < 640 && (
        <div
          style={{
            position: "absolute",
            right: 40,
            bottom: 34,
            fontFamily: "ui-monospace, \"SF Mono\", Menlo, monospace",
            fontSize: 17,
            letterSpacing: "0.18em",
            color: "rgba(17,17,17,0.42)",
            mixBlendMode: "difference",
            textTransform: "uppercase",
          }}
        >
          burnfuse
        </div>
      )}
    </AbsoluteFill>
  );
};
