#!/usr/bin/env python3
"""
Assemble the BurnFuse launch soundtrack from licensed sources.

Music: Mixkit "Can't Get You Off My Mind" (Michael Ramir C.), locked to
exactly 150.000 BPM — beat = 12 frames @ 30 fps, kick grid every 0.8 s
(kick n at 0.422 + n*0.8 s in the locked master; film frame 0 = kick #27).
SFX: ready-made Freesound CC0 files, one per cut or big move (sound-pass §4).

Section map (seam sits on the shared kick grid; both sections have a kick at
the splice point):
  A  22.022 s .. 38.022 s  ->  film  0.0 .. 16.0  hook/climb/trip/flow/product
  B  74.822 s .. 82.822 s  ->  film 16.0 .. 24.0  states/brand
  seam at film 16.0 s: 10 ms equal-power crossfade.

Mix target (sound-pass §5): ~-16 LUFS integrated, true peak <= -4 dBFS,
measured on the exported m4a with ebur128; the final gain comes from that
measurement (loudness clamped so the peak constraint always wins).

Writes: sound/launch-score.m4a, public/sound/launch-score.m4a
        ../sound/launch-mix.wav (window-level master, gitignored)
"""
import re, shutil, subprocess, sys
from pathlib import Path
import numpy as np, soundfile as sf
from scipy.signal import resample_poly

FPS, FRAMES, SR = 30, 720, 48000
SAMPLES = FRAMES * (SR // FPS)          # frame k starts at sample k*1600, exactly

HERE = Path(__file__).resolve().parent          # marketing/videos/launch/sound
LAUNCH = HERE.parent                            # marketing/videos/launch
MKT = HERE.parents[2]                           # marketing
MUSIC = MKT / "sound/music/cant-get-you-off-my-mind-150-bpm.wav"
SFX = MKT / "sound/sfx"
MIX_WAV = MKT / "sound/launch-mix.wav"

A_START, A_LEN = 22.022, 16.0
B_START, B_LEN = 74.822, 8.0
XFADE = 0.010                            # seam crossfade, s
IN_FADE, OUT_FADE = 0.003, 5 / FPS       # anti-click fades, s

TARGET_LUFS, MAX_TP_DB = -16.0, -4.0
SOFT_CEIL_DB = -1.0     # tanh soft ceiling at unity: keeps transients from
                        # forcing a peak-constrained gain (crest control)

# film frame -> (sfx file, peak target dBFS, max length s)
CUES = [
    (48,  "whoosh-light-701104.mp3", -7.5, 2.0),   # into climb
    (144, "boom-802075.mp3",         -3.0, 2.6),   # trip slam — the drop
    (168, "stamp-470710.mp3",       -13.0, 0.9),   # receipt stamp
    (192, "whoosh-light-701104.mp3", -7.5, 2.0),   # into flow
    (214, "tick-a-528561.mp3",      -19.0, None),  # chain pops, one per beat
    (226, "tick-b-546974.mp3",      -19.0, None),
    (238, "tick-a-528561.mp3",      -19.0, None),
    (250, "tick-b-546974.mp3",      -19.0, None),
    (336, "whoosh-deep-558826.mp3",  -7.0, 2.2),   # into product
    (436, "impact-soft-728515.mp3", -10.5, 1.3),   # "thirty providers" slam
    (480, "whoosh-deep-558826.mp3",  -7.0, 2.2),   # into states (music seam)
    (576, "flash-406614.mp3",       -15.5, 0.7),   # tripped white flash
    (624, "boom-802075.mp3",         -3.0, 2.8),   # brand — final drop
]


def load(path: Path) -> np.ndarray:
    y, sr = sf.read(str(path), always_2d=True, dtype="float32")
    if y.shape[1] == 1:
        y = np.repeat(y, 2, axis=1)
    if sr != SR:                                    # SFX previews are 44.1 kHz
        y = resample_poly(y, SR, sr, axis=0).astype("float32")
    return y


def peak_db(x: np.ndarray) -> float:
    p = float(np.abs(x).max()) or 1e-12
    return 20 * np.log10(p)


def place(buf: np.ndarray, clip: np.ndarray, at: int, peak_target: float, max_len):
    if max_len is not None:
        clip = clip[: int(max_len * SR)]
    clip = clip.copy()
    n = min(len(clip), int(0.015 * SR))                 # 15 ms click-free tail
    if n > 1:
        clip[-n:] *= np.linspace(1.0, 0.0, n)[:, None]
    clip *= 10 ** ((peak_target - peak_db(clip)) / 20)  # normalise to target
    end = min(at + len(clip), len(buf))
    buf[at:end] += clip[: end - at]


def build() -> np.ndarray:
    music = load(MUSIC)
    buf = np.zeros((SAMPLES, 2), dtype="float32")

    # --- sections, seam crossfade -------------------------------------------
    a0 = round(A_START * SR)
    a1 = a0 + round(A_LEN * SR)
    b0 = round(B_START * SR)
    b1 = b0 + round(B_LEN * SR)
    seg_a, seg_b = music[a0:a1], music[b0:b1]
    seam = round(A_LEN * SR)
    xf = round(XFADE * SR)

    ramp = np.linspace(0.0, 1.0, xf)
    buf[: seam - xf] += seg_a[: seam - xf]                      # A up to the crossfade
    buf[seam - xf: seam] = (                                    # equal-power seam
        seg_a[seam - xf: seam] * np.cos(ramp * np.pi / 2)[:, None]
        + seg_b[:xf] * np.sin(ramp * np.pi / 2)[:, None])
    buf[seam: seam + len(seg_b) - xf] += seg_b[xf:]             # B, starting 10 ms early

    # --- anti-click fades ----------------------------------------------------
    n = round(IN_FADE * SR)
    buf[:n] *= np.linspace(0.0, 1.0, n)[:, None]
    n = round(OUT_FADE * SR)
    buf[-n:] *= np.linspace(1.0, 0.0, n)[:, None]

    # --- SFX -----------------------------------------------------------------
    for frame, fname, target, max_len in CUES:
        place(buf, load(SFX / fname), frame * (SR // FPS), target, max_len)
    return buf


def measure(path: Path):
    p = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
         "-filter_complex", "ebur128=peak=true", "-f", "null", "-"],
        capture_output=True, text=True)
    i = [float(m) for m in re.findall(r"\bI:\s*(-?\d+\.\d+)\s*LUFS", p.stderr)]
    tp = [float(m) for m in re.findall(r"Peak:\s*(-?\d+\.\d+)\s*dBFS", p.stderr)]
    if not i or not tp:
        raise SystemExit("could not parse ebur128 output:\n" + p.stderr[-2000:])
    return i[-1], tp[-1]


def main():
    print(f"sections: A {A_START:.3f} s +{A_LEN} s | B {B_START:.3f} s +{B_LEN} s | "
          f"seam xfade {XFADE*1000:.0f} ms | cues {len(CUES)}")

    mix = build()
    ceil = 10 ** (SOFT_CEIL_DB / 20)
    mix = np.tanh(mix / ceil) * ceil          # soft ceiling before measurement
    tmp = MKT / "sound/.launch-mix-unity.wav"
    sf.write(str(tmp), mix, SR, subtype="FLOAT")

    i0, tp0 = measure(tmp)
    gain = min(TARGET_LUFS - i0, MAX_TP_DB - tp0)
    print(f"unity: I {i0:+.1f} LUFS, TP {tp0:+.1f} dBFS -> gain {gain:+.2f} dB "
          f"({'peak' if MAX_TP_DB - tp0 < TARGET_LUFS - i0 else 'loudness'}constrained)")

    mix *= 10 ** (gain / 20)
    sf.write(str(MIX_WAV), mix, SR, subtype="FLOAT")

    out = LAUNCH / "sound/launch-score.m4a"
    subprocess.run(
        ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(MIX_WAV),
         "-c:a", "aac", "-b:a", "320k", "-ar", str(SR), "-ac", "2",
         "-movflags", "+faststart", str(out)], check=True)

    i1, tp1 = measure(out)
    dur = float(subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(out)],
        capture_output=True, text=True).stdout)
    shutil.copy2(out, LAUNCH / "public/sound/launch-score.m4a")
    tmp.unlink()

    print(f"final: I {i1:+.1f} LUFS (target {TARGET_LUFS}), TP {tp1:+.1f} dBFS "
          f"(max {MAX_TP_DB}), duration {dur:.3f} s")
    ok = abs(i1 - TARGET_LUFS) <= 1.0 and tp1 <= MAX_TP_DB + 0.05 and abs(dur - 24.0) < 0.01
    print("mix QC: " + ("PASS" if ok else "CHECK — see numbers above"))
    print(f"wrote {out.relative_to(MKT.parent)} (+ public/sound) and "
          f"{MIX_WAV.relative_to(MKT.parent)}")
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
