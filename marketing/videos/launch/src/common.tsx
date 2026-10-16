/**
 * BurnFuse launch reel — shared kit.
 * Tokens from marketing/design.md; fonts from public/fonts (Fontshare).
 */
import React from "react";
import { delayRender, continueRender, staticFile, spring, interpolate } from "remotion";
import { loadFont } from "@remotion/fonts";

// ---------------------------------------------------------------- fonts
export const DISPLAY = "Clash Display";
export const BODY = "Satoshi";
export const MONO = 'ui-monospace, "SF Mono", Menlo, monospace';

const fontHandle = delayRender("Loading launch-reel fonts");
Promise.all([
  loadFont({ family: DISPLAY, url: staticFile("fonts/ClashDisplay-Medium.ttf"), weight: "500" }),
  loadFont({ family: DISPLAY, url: staticFile("fonts/ClashDisplay-Semibold.ttf"), weight: "600" }),
  loadFont({ family: DISPLAY, url: staticFile("fonts/ClashDisplay-Bold.ttf"), weight: "700" }),
  loadFont({ family: BODY, url: staticFile("fonts/Satoshi-Regular.ttf"), weight: "400" }),
  loadFont({ family: BODY, url: staticFile("fonts/Satoshi-Medium.ttf"), weight: "500" }),
  loadFont({ family: BODY, url: staticFile("fonts/Satoshi-Bold.ttf"), weight: "700" }),
]).then(() => continueRender(fontHandle));

// ---------------------------------------------------------------- tokens
export const C = {
  paper: "#f2f2f2",
  ink: "#111111",
  inkSoft: "#6a6969",
  white: "#ffffff",
  calm: "#57DB94",
  warm: "#FCCB47",
  hot: "#FA5426",
  calmDeep: "#157a47",
  warmDeep: "#8a5c00",
  hotDeep: "#b32a0a",
  line: "rgba(17,17,17,0.14)",
  dot: "#57DB94",
};

export const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** Snappy scale slam: overshoot from 1.12x, settles by ~14 frames. */
export const slam = (frame: number, fps: number, at: number, dist = 0.14) => {
  const s = spring({
    frame: frame - at,
    fps,
    config: { damping: 14, stiffness: 190, mass: 0.6 },
    durationInFrames: 16,
  });
  return 1 + dist * (1 - s);
};

/** Rise from below, eased out. Returns translateY px. */
export const rise = (frame: number, at: number, dist = 44, dur = 14) =>
  interpolate(frame, [at, at + dur], [dist, 0], {
    ...clamp,
    easing: (x) => 1 - Math.pow(1 - x, 3),
  });

/** Fade in fast, hold. */
export const appear = (frame: number, at: number, dur = 6) =>
  interpolate(frame, [at, at + dur], [0, 1], clamp);

/** Counter with accelerating feel. */
export const count = (frame: number, from: number, to: number, t0: number, t1: number, out = 2) =>
  interpolate(frame, [t0, t1], [from, to], { ...clamp, easing: (x) => x * x })
    .toFixed(out);

// ---------------------------------------------------------------- pieces
export const Kicker: React.FC<{
  children: React.ReactNode;
  color?: string;
  size?: number;
  style?: React.CSSProperties;
}> = ({ children, color = C.inkSoft, size = 20, style }) => (
  <div
    style={{
      fontFamily: MONO,
      fontSize: size,
      letterSpacing: "0.22em",
      textTransform: "uppercase",
      color,
      ...style,
    }}
  >
    {children}
  </div>
);

/** A white/colored hit frame — 2–3 frames of flash on a cut. */
export const Flash: React.FC<{ frame: number; at: number; color?: string; dur?: number }> = ({
  frame,
  at,
  color = "#ffffff",
  dur = 3,
}) => {
  const f = frame - at;
  const o = f < 0 || f > dur ? 0 : interpolate(f, [0, dur], [0.92, 0]);
  return <div style={{ position: "absolute", inset: 0, background: color, opacity: o }} />;
};

/** Deterministic decaying shake — no Math.random, so every render is identical. */
export const Shake: React.FC<{
  frame: number;
  at: number;
  amp?: number;
  dur?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ frame, at, amp = 8, dur = 12, children, style }) => {
  const f = frame - at;
  const k = f >= 0 && f < dur ? amp * (1 - f / dur) : 0;
  const dx = k * Math.sin(f * 2.9);
  const dy = k * Math.cos(f * 3.7);
  return (
    <div style={{ transform: `translate(${dx}px, ${dy}px)`, ...style }}>{children}</div>
  );
};

/** The brand's echo plates: offset outlines stepping up-left. */
export const EchoPlates: React.FC<{
  color?: string;
  step?: number;
  radius?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ color = "rgba(17,17,17,0.16)", step = 18, radius = 24, children, style }) => (
  <div style={{ position: "relative", ...style }}>
    <div
      style={{
        position: "absolute",
        inset: 0,
        transform: `translate(-${step * 2}px, -${step * 2}px)`,
        border: `1px solid ${color}`,
        borderRadius: radius,
      }}
    />
    <div
      style={{
        position: "absolute",
        inset: 0,
        transform: `translate(-${step}px, -${step}px)`,
        border: `1px solid ${color}`,
        borderRadius: radius,
      }}
    />
    <div style={{ position: "relative" }}>{children}</div>
  </div>
);

/** The dark menu-bar pill: clock · dot · rate. */
export const MenuBar: React.FC<{
  clock: string;
  rate: string;
  dot: string;
  style?: React.CSSProperties;
}> = ({ clock, rate, dot, style }) => (
  <div
    style={{
      display: "inline-flex",
      alignItems: "center",
      gap: 20,
      background: "#1b1b1b",
      borderRadius: 999,
      padding: "16px 30px",
      color: "#f6f6f6",
      boxShadow: "0 18px 50px rgba(17,17,17,0.28)",
      ...style,
    }}
  >
    <span style={{ fontFamily: MONO, fontSize: 21, opacity: 0.7 }}>{clock}</span>
    <span style={{ width: 1, height: 24, background: "rgba(255,255,255,0.16)" }} />
    <span
      style={{
        width: 11,
        height: 11,
        borderRadius: 999,
        background: dot,
        boxShadow: `0 0 16px ${dot}`,
      }}
    />
    <span style={{ fontFamily: MONO, fontSize: 21 }}>{rate}</span>
  </div>
);

/** Thin cap meter, site-style. */
export const Meter: React.FC<{ pct: number; color: string; width?: number; track?: string }> = ({
  pct,
  color,
  width = 640,
  track = "rgba(17,17,17,0.12)",
}) => (
  <div style={{ width, height: 8, borderRadius: 4, background: track, overflow: "hidden" }}>
    <div
      style={{
        width: `${Math.max(0, Math.min(100, pct))}%`,
        height: "100%",
        borderRadius: 4,
        background: color,
      }}
    />
  </div>
);
