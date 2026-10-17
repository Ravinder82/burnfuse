# BurnFuse — launch reel (16:9)

The product launch cut. 24 seconds, beat-locked to a real licensed track
("Can't Get You Off My Mind" — Michael Ramir C., Mixkit; locked to exactly
150.000 BPM), built in Remotion from the site's assets and design language.

## Deliverable

| | |
|---|---|
| File | `marketing/renders/launch.mp4` |
| Canvas | 1920 × 1080 (16:9) |
| Frame rate | 30 fps |
| Duration | 720 frames — 24.000 s |
| Video | H.264, CRF 16, preset medium, yuv420p |
| Audio | AAC 320 kbps, 48 kHz stereo |
| Loudness | −16.0 LUFS integrated, peak −4.2 dBFS (sound-pass spec; measured with `ebur128` on the exported MP4) |
| Poster | `marketing/renders/launch-poster.jpg` (frame at 5.6 s — the trip slam) |

## Music grid — a real track locked to 150.000 BPM

The soundtrack is a licensed track (see `marketing/sound/LICENSES.md`),
stretched a measured −0.04 % (`atempo`) to exactly 150.000 BPM so every beat
lands on an integer frame:

- 1 beat = 0.4 s = **12 frames**; 1 bar = **48 frames**; 15 bars = 720 frames.
- The track's halftime kick grid lands every 0.8 s — on every bar line; both
  scene drops (trip, brand) land on its strongest hits.
- Sections spliced from the track (all points on the measured kick grid,
  film frame 0 = kick #27): **A** `22.022 s → 38.022 s` covers film 0–16 s;
  **B** `74.822 s → 82.822 s` covers 16–24 s; seam at 16.0 s with a 10 ms
  equal-power crossfade.
- SFX (ready-made, Freesound CC0 — one per cut or big move): whooshes at
  1.6 / 6.4 / 11.2 / 16.0 s, boom on the trip (4.8 s) and brand (20.8 s)
  drops, stamp at 5.6 s, UI ticks on the chain pops (7.13–8.47 s), soft
  impact on the card slam (14.53 s), flash tick at 19.2 s. Exact map in
  `sound/assemble.py`.
- Measured cue ledger: every cut sits on a strong kick within ±1 frame (the
  track's own groove); the seam kick lands at ±0 ms.

## Scene map

| Bars | Frames | Time | Scene | What happens |
|---|---|---|---|---|
| B1 | 0–48 | 0.0–1.6 | **Hook** (ink) | “An agent is burning / while you’re asleep.” word-slam on beats; menu-bar pill pops with a live-burning rate; hot glow breathes |
| B2–B3 | 48–144 | 1.6–4.8 | **Climb** (paper) | The rate counter accelerates $2.45 → $41.20/hr through green → amber → red; meter fills; states chips step; dark blip out |
| B4 | 144–192 | 4.8–6.4 | **Trip** (hot) | White flash, red slam “Tripped.” with decaying shake; the receipt stamp: `Fri 11:47 PM · $16.40/hr · cap $5.00/hr` |
| B5–B7 | 192–336 | 6.4–11.2 | **Flow** (paper) | “Know within a minute — not in the morning.”; the chain pops a pill per beat: menu bar red → notification → Slack / Discord → the key switches off\* (\*where the provider allows it) |
| B8–B10 | 336–480 | 11.2–16.0 | **Product** (paper) | The launch still wipes in; camera pushes 2.0× into the live-rate window; hard cut to “Thirty providers. No dead end.” |
| B11–B13 | 480–624 | 16.0–20.8 | **States** (calm / warm / hot) | Three full-bleed panels, one bar each: Settled. $2.45/hr → Climbing. $9.80/hr → Tripped. $16.40/hr, white flash + shake on red |
| B14–B15 | 624–720 | 20.8–24.0 | **Brand** (ink) | Icon springs in with echo plates, wordmark slams on the next beat, the fuse underline draws green→amber→hot, `git clone …` types itself, chips: macOS 14+ · MIT · no account · no telemetry |

## Design system

- **Type** — Clash Display 500/600/700 (display), Satoshi 400/500/700 (body),
  system mono for data (clocks, rates, caps). Fonts served from `public/fonts`
  (Fontshare TTFs), loaded via `@remotion/fonts`.
- **Colour** — paper `#f2f2f2` · ink `#111111` · calm `#57DB94` (+deep
  `#157a47`) · warm `#FCCB47` (+deep `#8a5c00`) · hot `#FA5426` (+deep
  `#b32a0a`). States read green → amber → red everywhere: the number, the
  meter, the panels, the underline.
- **Motion** — slams (spring overshoot from 1.12–1.2×, ~14 frames), 2–3 frame
  flash cuts at section boundaries, deterministic decaying shakes (no RNG),
  clip-path wipes with the site's `cubic-bezier(0.77, 0, 0.175, 1)`,
  accelerating counters and running clocks.
- **Claims** — every line is from README/MARKETING: “tells you inside a
  minute”, “where the provider allows it, the trip offers to switch the key
  off — with a second press”, macOS 14+, MIT, no account, no telemetry,
  thirty providers. `$2.45/$9.80/$16.40` and the `$5.00/hr` cap are the same
  illustrative demo values the website uses.

## Assets

| Asset | Source | Used in |
|---|---|---|
| `public/img/launch.png` | `website/assets/launch-16x9.png` (3200×1800) | Product scene |
| `public/img/providers.png` | `website/assets/providers-16x9.png` (3200×1800) | Product scene |
| `public/img/icon.png` | `website/assets/icon_512.png` | Brand scene |
| `public/fonts/*.ttf` | Fontshare (Clash Display, Satoshi) | everything |
| `public/sound/launch-score.m4a` | `sound/assemble.py` (numpy + ffmpeg) from `marketing/sound/{music,sfx}` | soundtrack |

## Build

```bash
cd marketing/videos/launch
bash ../../sound/fetch.sh                     # music + SFX sources (raw audio is gitignored)
~/.local/share/app-launch-kit/venv/bin/python sound/assemble.py   # mix → QC'd sound/launch-score.m4a
npx remotion render Launch out/launch.mp4 \
  --crf=16 --x264-preset=medium --audio-bitrate=320k
```

`assemble.py` prints the loudness / peak / duration QC and exits non-zero on a
miss (−16.0 LUFS / peak ≤ −4 dBFS / 24.000 s). For an audio-only change,
render nothing — remux:

```bash
ffmpeg -y -i out/launch.mp4 -i sound/launch-score.m4a \
  -map 0:v -map 1:a -c copy -movflags +faststart out/launch.mp4
```

Studio preview: `npx remotion studio`.
