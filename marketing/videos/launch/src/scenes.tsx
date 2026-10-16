/**
 * BurnFuse launch reel — the seven scenes.
 * Frame map (30 fps, 720 total, beat = 12 f, bar = 48 f):
 *   S1 hook     0–48    dark, kinetic
 *   S2 climb   48–144   paper, the meter runs
 *   S3 trip   144–192   hot, red slam
 *   S4 flow   192–336   paper, told in a minute
 *   S5 product 336–480  paper, one window + thirty providers
 *   S6 states 480–624   three full-bleed panels
 *   S7 brand  624–720   ink, endcard
 */
import React from "react";
import { AbsoluteFill, Easing, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { C, clamp, count, DISPLAY, BODY, MONO, Flash, Kicker, MenuBar, Meter, Shake, slam, rise, appear } from "./common";

// ================================================================ S1 · hook
export const Hook: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const one = slam(frame, fps, 4);
  const two = slam(frame, fps, 12);
  const pill = spring({ frame: frame - 24, fps, config: { damping: 200 }, durationInFrames: 22 });
  const burn = (2.45 + frame * 0.31).toFixed(2);
  const glow = 0.5 + 0.5 * Math.sin(frame * 0.5);

  return (
    <AbsoluteFill style={{ background: "#0c0c0c", overflow: "hidden" }}>
      {/* a quiet hot glow behind the type, breathing */}
      <div
        style={{
          position: "absolute",
          width: 1400,
          height: 900,
          left: "50%",
          top: "54%",
          transform: "translate(-50%,-50%)",
          background: `radial-gradient(closest-side, rgba(250,84,38,${0.16 + glow * 0.05}), rgba(250,84,38,0))`,
        }}
      />
      <div style={{ position: "absolute", left: 96, top: 76, display: "flex", gap: 28, alignItems: "center" }}>
        <Kicker color="rgba(242,242,242,0.55)">BurnFuse — launch 1.0</Kicker>
      </div>

      <div style={{ position: "absolute", left: 96, top: 250 }}>
        <div style={{ transform: `scale(${one})`, transformOrigin: "left top" }}>
          <div
            style={{
              fontFamily: DISPLAY,
              fontWeight: 700,
              fontSize: 122,
              letterSpacing: "-0.04em",
              lineHeight: 0.98,
              color: C.paper,
            }}
          >
            An agent is burning
          </div>
        </div>
        <div style={{ transform: `scale(${two})`, transformOrigin: "left top", marginTop: 6 }}>
          <div
            style={{
              fontFamily: DISPLAY,
              fontWeight: 700,
              fontSize: 122,
              letterSpacing: "-0.04em",
              lineHeight: 0.98,
              color: C.hot,
            }}
          >
            while you&rsquo;re asleep.
          </div>
        </div>
      </div>

      {frame >= 24 && (
        <div
          style={{
            position: "absolute",
            left: 96,
            top: 620,
            transform: `translateY(${rise(frame - 24, 0, 26)}px)`,
            opacity: pill,
          }}
        >
          <MenuBar clock="Fri 11:47 PM" rate={`$${burn}/hr`} dot={C.hot} />
        </div>
      )}
      {frame >= 31 && (
        <div style={{ position: "absolute", left: 96, top: 720, opacity: appear(frame - 31, 0, 10) }}>
          <Kicker size={19} color="rgba(242,242,242,0.42)">
            every minute — until something notices
          </Kicker>
        </div>
      )}
      <Flash frame={frame} at={46} color="#f2f2f2" dur={2} />
    </AbsoluteFill>
  );
};

// ================================================================ S2 · climb
export const Climb: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const value = interpolate(frame, [10, 84], [2.45, 41.2], {
    ...clamp,
    easing: Easing.in(Easing.quad),
  });
  const phase = value < 5.2 ? 0 : value < 16 ? 1 : 2;
  const color = [C.calm, C.warm, C.hot][phase];
  const deep = [C.calmDeep, C.warmDeep, C.hotDeep][phase];
  const settle = slam(frame, fps, 2);
  const word = ["settled", "climbing", "tripped"][phase];
  const chips = ["settled", "climbing", "tripped"];

  return (
    <AbsoluteFill style={{ background: C.paper, overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 96, top: 76, display: "flex", width: 1728, justifyContent: "space-between" }}>
        <Kicker>reads the cost — every minute</Kicker>
        <Kicker>{`reading ${String(1 + Math.floor(frame / 8)).padStart(2, "0")}`}</Kicker>
      </div>

      <div style={{ position: "absolute", left: 0, right: 0, top: 300, textAlign: "center" }}>
        <div style={{ transform: `scale(${settle})` }}>
          <span
            style={{
              fontFamily: DISPLAY,
              fontWeight: 700,
              fontSize: 300,
              letterSpacing: "-0.05em",
              lineHeight: 0.9,
              color: deep,
              fontVariantNumeric: "tabular-nums",
            }}
          >
            ${value.toFixed(2)}
          </span>
          <span
            style={{
              fontFamily: DISPLAY,
              fontWeight: 600,
              fontSize: 96,
              letterSpacing: "-0.03em",
              color: deep,
              opacity: 0.55,
              marginLeft: 10,
            }}
          >
            /hr
          </span>
        </div>
      </div>

      <div style={{ position: "absolute", left: "50%", top: 690, transform: "translateX(-50%)", display: "flex", flexDirection: "column", alignItems: "center", gap: 26 }}>
        <Meter pct={(value / 41.2) * 100} color={color} width={900} />
        <div style={{ display: "flex", gap: 18 }}>
          {chips.map((chip, i) => (
            <div
              key={chip}
              style={{
                fontFamily: MONO,
                fontSize: 21,
                padding: "12px 26px",
                borderRadius: 999,
                background: i === phase ? [C.calm, C.warm, C.hot][i] : "transparent",
                color: i === phase ? C.ink : C.inkSoft,
                border: `1px solid ${i === phase ? "transparent" : C.line}`,
                transition: "none",
              }}
            >
              {chip}
            </div>
          ))}
        </div>
      </div>

      <div style={{ position: "absolute", left: 96, bottom: 90, opacity: appear(frame, 84, 8) }}>
        <Kicker>
          cap $5.00/hr — <span style={{ color: C.hotDeep, fontWeight: 700 }}>{word}</span>
        </Kicker>
      </div>
      <Flash frame={frame} at={94} color="#111111" dur={2} />
    </AbsoluteFill>
  );
};

// ================================================================ S3 · trip
export const Trip: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const word = slam(frame, fps, 2, 0.2);
  const stamp = spring({ frame: frame - 16, fps, config: { damping: 18, stiffness: 210 } });
  return (
    <AbsoluteFill style={{ background: C.hot, overflow: "hidden" }}>
      <Shake frame={frame} at={2} amp={10} dur={14} style={{ position: "absolute", inset: 0 }}>
        <div style={{ position: "absolute", left: 0, right: 0, top: 330, textAlign: "center" }}>
          <div style={{ transform: `scale(${word})` }}>
            <span
              style={{
                fontFamily: DISPLAY,
                fontWeight: 700,
                fontSize: 240,
                letterSpacing: "-0.05em",
                color: C.paper,
              }}
            >
              Tripped.
            </span>
          </div>
        </div>
      </Shake>
      <div style={{ position: "absolute", left: 0, right: 0, top: 660, display: "flex", justifyContent: "center", opacity: stamp }}>
        <div
          style={{
            transform: `scale(${0.9 + 0.1 * stamp})`,
            background: C.ink,
            borderRadius: 999,
            padding: "18px 34px",
            fontFamily: MONO,
            fontSize: 24,
            color: C.paper,
            display: "flex",
            gap: 22,
            alignItems: "center",
          }}
        >
          <span>Fri 11:47 PM</span>
          <span style={{ opacity: 0.4 }}>·</span>
          <span>$16.40/hr</span>
          <span style={{ opacity: 0.4 }}>·</span>
          <span>cap $5.00/hr</span>
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 790, textAlign: "center", opacity: appear(frame, 26, 10) }}>
        <span style={{ fontFamily: BODY, fontWeight: 500, fontSize: 34, color: "rgba(17,17,17,0.78)" }}>
          the fuse went — and it told you in the same minute
        </span>
      </div>
      <Flash frame={frame} at={0} color="#ffffff" dur={3} />
    </AbsoluteFill>
  );
};

// ================================================================ S4 · flow
const steps = [
  { label: "menu bar red", at: 26 },
  { label: "notification", at: 38 },
  { label: "Slack / Discord", at: 50 },
  { label: "the key switches off", at: 62 },
];

export const Flow: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const head = slam(frame, fps, 2);
  const head2 = slam(frame, fps, 10);
  return (
    <AbsoluteFill style={{ background: C.paper, overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 96, top: 96 }}>
        <Kicker>what a trip does</Kicker>
      </div>
      <div style={{ position: "absolute", left: 96, top: 168 }}>
        <div style={{ transform: `scale(${head})`, transformOrigin: "left top" }}>
          <span style={{ fontFamily: DISPLAY, fontWeight: 700, fontSize: 108, letterSpacing: "-0.04em", color: C.ink, lineHeight: 1 }}>
            Know within a minute —
          </span>
        </div>
        <div style={{ transform: `scale(${head2})`, transformOrigin: "left top", marginTop: 4 }}>
          <span style={{ fontFamily: DISPLAY, fontWeight: 700, fontSize: 108, letterSpacing: "-0.04em", color: C.hot, lineHeight: 1 }}>
            not in the morning.
          </span>
        </div>
      </div>

      <div style={{ position: "absolute", left: 96, top: 560, display: "flex", alignItems: "center", gap: 22 }}>
        {steps.map((s, i) => {
          const on = frame >= s.at - 4;
          const sc = on ? slam(frame, fps, s.at - 4, 0.1) : 1;
          const op = on ? 1 : 0;
          return (
            <React.Fragment key={s.label}>
              <div
                style={{
                  opacity: op,
                  transform: `scale(${sc})`,
                  border: `1px solid ${i === 0 ? C.hot : C.ink}`,
                  background: i === 0 ? C.hot : C.white,
                  color: i === 0 ? C.paper : C.ink,
                  borderRadius: 999,
                  padding: "20px 38px",
                  fontFamily: BODY,
                  fontWeight: 700,
                  fontSize: 30,
                  whiteSpace: "nowrap",
                }}
              >
                {s.label}
              </div>
              {i < steps.length - 1 && (
                <div
                  style={{
                    opacity: frame >= s.at + 8 ? 1 : 0.12,
                    fontFamily: BODY,
                    fontSize: 34,
                    color: C.inkSoft,
                    transform: `translateX(${frame >= s.at + 8 ? 0 : -6}px)`,
                  }}
                >
                  →
                </div>
              )}
            </React.Fragment>
          );
        })}
      </div>

      <div style={{ position: "absolute", left: 96, top: 720, opacity: appear(frame, 80, 10) }}>
        <Kicker size={19}>
          *where the provider allows it, the trip offers to switch the key off — with a second press
        </Kicker>
      </div>
      <div style={{ position: "absolute", right: 96, top: 96, opacity: appear(frame, 16, 12) }}>
        <MenuBar clock="Fri 11:47 PM" rate="$16.40/hr" dot={C.hot} />
      </div>
      <Flash frame={frame} at={140} color="#f2f2f2" dur={2} />
    </AbsoluteFill>
  );
};

// ================================================================ S5 · product
export const Product: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // A: the launch still wipes in · B: push into the graph · C: providers
  const showA = frame < 52;
  const showB = frame >= 52 && frame < 100;
  const showC = frame >= 100;

  const wipe = interpolate(frame, [4, 20], [100, 0], {
    ...clamp,
    easing: Easing.bezier(0.77, 0, 0.175, 1),
  });
  const push = interpolate(frame, [54, 98], [1, 2.02], { ...clamp, easing: Easing.inOut(Easing.quad) });
  const card = slam(frame, fps, 100, 0.08);
  const cSlide = rise(frame - 100, 0, 40, 14);

  return (
    <AbsoluteFill style={{ background: C.paper, overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 96, top: 96, display: "flex", width: 1728, justifyContent: "space-between" }}>
        <Kicker>the product</Kicker>
        <Kicker>one number — read itself, every minute</Kicker>
      </div>

      {showA && (
        <div style={{ position: "absolute", left: "50%", top: 190, transform: "translateX(-50%)" }}>
          <div
            style={{
              width: 1620,
              borderRadius: 24,
              overflow: "hidden",
              clipPath: `inset(${wipe / 2}% 0% ${wipe / 2}% 0%)`,
              boxShadow: "0 40px 120px rgba(17,17,17,0.22)",
            }}
          >
            <Img src={staticFile("img/launch.png")} style={{ width: "100%", display: "block" }} />
          </div>
        </div>
      )}

      {showB && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            transform: `scale(${push})`,
            transformOrigin: "100% 45%",
          }}
        >
          <Img
            src={staticFile("img/launch.png")}
            style={{ position: "absolute", left: "50%", top: 190, transform: "translateX(-50%)", width: 1620, borderRadius: 24, display: "block" }}
          />
        </div>
      )}

      {showC && (
        <div style={{ position: "absolute", left: "50%", top: 240, transform: `translateX(-50%) translateY(${cSlide}px) scale(${card})` }}>
          <div style={{ width: 1600, borderRadius: 24, overflow: "hidden", boxShadow: "0 40px 120px rgba(17,17,17,0.22)" }}>
            <Img src={staticFile("img/providers.png")} style={{ width: "100%", display: "block" }} />
          </div>
        </div>
      )}

      <div style={{ position: "absolute", left: 96, bottom: 84, display: "flex", gap: 60, alignItems: "center" }}>
        <div style={{ opacity: showA ? appear(frame, 30, 12) : 0 }}>
          <Kicker size={19}>one window — every key, in plain English</Kicker>
        </div>
      </div>
      <Flash frame={frame} at={100} color="#ffffff" dur={3} />
    </AbsoluteFill>
  );
};

// ================================================================ S6 · states
const panels = [
  { word: "Settled.", rate: "$2.45/hr", bg: C.calm, fg: C.ink, pct: 49, deep: C.calmDeep },
  { word: "Climbing.", rate: "$9.80/hr", bg: C.warm, fg: C.ink, pct: 100, deep: C.warmDeep },
  { word: "Tripped.", rate: "$16.40/hr", bg: C.hot, fg: C.paper, pct: 100, deep: C.hotDeep },
];

export const States: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const seg = Math.min(2, Math.floor(frame / 48));
  const local = frame % 48;
  const p = panels[seg];
  const word = slam(local, fps, 2, 0.16);
  const rate = spring({ frame: local - 10, fps, config: { damping: 200 }, durationInFrames: 14 });
  return (
    <AbsoluteFill style={{ background: p.bg, overflow: "hidden" }}>
      <Shake frame={frame} at={96} amp={9} dur={10} style={{ position: "absolute", inset: 0 }}>
        <div style={{ position: "absolute", left: 96, top: 90, display: "flex", width: 1728, justifyContent: "space-between" }}>
          <Kicker color={p.fg === C.ink ? C.inkSoft : "rgba(242,242,242,0.7)"}>
            the block changes colour
          </Kicker>
          <Kicker color={p.fg === C.ink ? C.inkSoft : "rgba(242,242,242,0.7)"}>
            {`${p.pct}% of your $5.00/hr cap`}
          </Kicker>
        </div>

        <div style={{ position: "absolute", left: 0, right: 0, top: 340, textAlign: "center" }}>
          <div style={{ transform: `scale(${word})` }}>
            <span style={{ fontFamily: DISPLAY, fontWeight: 700, fontSize: 230, letterSpacing: "-0.05em", color: p.fg }}>
              {p.word}
            </span>
          </div>
        </div>

        <div style={{ position: "absolute", left: 0, right: 0, top: 700, display: "flex", flexDirection: "column", alignItems: "center", gap: 26, opacity: rate }}>
          <span style={{ fontFamily: MONO, fontSize: 44, color: p.fg }}>{p.rate}</span>
          <Meter
            pct={p.pct}
            color={p.fg === C.ink ? "#111111" : "#f2f2f2"}
            width={900}
            track={p.fg === C.ink ? "rgba(17,17,17,0.18)" : "rgba(242,242,242,0.28)"}
          />
        </div>
      </Shake>

      {/* panel index dots — a beat marker the eye can follow */}
      <div style={{ position: "absolute", left: 96, bottom: 84, display: "flex", gap: 14 }}>
        {panels.map((pp, i) => (
          <div
            key={pp.word}
            style={{
              width: i === seg ? 46 : 14,
              height: 14,
              borderRadius: 99,
              background: p.fg === C.ink ? C.ink : C.paper,
              opacity: i === seg ? 1 : 0.35,
            }}
          />
        ))}
      </div>
      {seg === 2 && <Flash frame={frame} at={96} color="#ffffff" dur={3} />}
    </AbsoluteFill>
  );
};

// ================================================================ S7 · brand
export const Brand: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const icon = spring({ frame: frame - 2, fps, config: { damping: 13, stiffness: 150, mass: 0.9 } });
  const word = slam(frame, fps, 14, 0.12);
  const wordOn = frame >= 13 ? 1 : 0;
  const draw = interpolate(frame, [26, 46], [0, 100], { ...clamp, easing: Easing.out(Easing.cubic) });
  const sub = appear(frame, 34, 10);
  const urlChars = Math.floor(interpolate(frame, [52, 74], [0, 38], clamp));
  const url = "git clone github.com/Ravinder82/burnfuse";
  const caret = frame % 30 < 16;
  return (
    <AbsoluteFill style={{ background: C.ink, overflow: "hidden" }}>
      <div style={{ position: "absolute", left: "50%", top: 128, transform: `translateX(-50%) scale(${0.7 + icon * 0.3})`, opacity: icon }}>
        <div style={{ position: "relative", width: 168, height: 168 }}>
          <div style={{ position: "absolute", inset: -22, border: "1px solid rgba(242,242,242,0.16)", borderRadius: 42 }} />
          <div style={{ position: "absolute", inset: -44, border: "1px solid rgba(242,242,242,0.08)", borderRadius: 56 }} />
          <Img src={staticFile("img/icon.png")} style={{ width: 168, height: 168, borderRadius: 38, display: "block" }} />
        </div>
      </div>

      <div style={{ position: "absolute", left: 0, right: 0, top: 356, textAlign: "center" }}>
        <div style={{ transform: `scale(${word})`, opacity: wordOn }}>
          <span style={{ fontFamily: DISPLAY, fontWeight: 700, fontSize: 168, letterSpacing: "-0.05em", color: C.paper }}>
            BurnFuse
          </span>
        </div>
        {/* the fuse: a gradient line drawing beneath the wordmark */}
        <div style={{ position: "relative", width: 560, height: 6, margin: "30px auto 0", background: "rgba(242,242,242,0.14)", borderRadius: 3, overflow: "hidden" }}>
          <div
            style={{
              width: `${draw}%`,
              height: "100%",
              background: `linear-gradient(90deg, ${C.calm}, ${C.warm}, ${C.hot})`,
            }}
          />
        </div>
      </div>

      <div style={{ position: "absolute", left: 0, right: 0, top: 620, textAlign: "center", opacity: sub }}>
        <span style={{ fontFamily: BODY, fontWeight: 500, fontSize: 38, color: "rgba(242,242,242,0.82)" }}>
          A cost guard for AI agents. Free, open source — macOS 14+.
        </span>
      </div>

      <div style={{ position: "absolute", left: 0, right: 0, top: 730, textAlign: "center" }}>
        <span style={{ fontFamily: MONO, fontSize: 28, color: "rgba(242,242,242,0.6)" }}>
          {url.slice(0, urlChars)}
          <span style={{ opacity: caret ? 1 : 0, color: C.calm }}>▌</span>
        </span>
      </div>

      <div style={{ position: "absolute", left: 0, right: 0, bottom: 84, textAlign: "center", opacity: appear(frame, 60, 12) }}>
        <Kicker size={19} color="rgba(242,242,242,0.44)">
          no account · no telemetry · MIT · thirty providers
        </Kicker>
      </div>
    </AbsoluteFill>
  );
};
