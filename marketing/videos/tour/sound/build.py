"""
BurnFuse tour — 21.2s launch score (light editorial cut).

Airy, warm, spec-sheet quiet: soft pads, small precise ticks as rows land,
a faint lift when the window opens. No dread — this is the tour, not the
confession. Timeline matches marketing/videos/tour/index.html (30 fps, 21.2 s).

    python3 sound/build.py          # writes sound/score.m4a
"""

import json
import os
import re
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "..", "tools"))
from score_lib import (  # noqa: E402
    SR,
    _mix,
    bandpass_fft,
    bell,
    make_buffer,
    noise,
    swell,
    thump,
    tick,
    whoosh,
)

HERE = os.path.dirname(os.path.abspath(__file__))
TOTAL = 21.2

rng = np.random.default_rng(11)
buf = make_buffer(TOTAL)


def air_pad(duration):
    """A bright, breathing pad in G — morning-light, not room-tone."""
    n = int(duration * SR)
    t = np.arange(n) / SR
    lfo = 0.74 + 0.26 * np.sin(2 * np.pi * 0.06 * t + 1.0)
    sig = (
        0.90 * np.sin(2 * np.pi * 98.00 * t)
        + 0.50 * np.sin(2 * np.pi * 147.00 * t + 0.3)
        + 0.34 * np.sin(2 * np.pi * 196.00 * t + 1.1)
        + 0.18 * np.sin(2 * np.pi * 392.40 * t + 0.7)
        + 0.12 * np.sin(2 * np.pi * 587.00 * t)
    )
    return sig * lfo * 0.16


# ---------------------------------------------------------------- bed
pad = air_pad(TOTAL)
t = np.arange(len(pad)) / SR
duck = np.ones_like(t)


def ramp(t0, t1, a, b):
    m = (t >= t0) & (t <= t1)
    duck[m] *= np.interp(t[m], [t0, t1], [a, b])


ramp(2.38, 2.62, 1.0, 0.78)    # push up: breath in
ramp(2.62, 2.95, 0.78, 1.0)
ramp(7.40, 7.62, 1.0, 0.78)    # push left
ramp(7.62, 8.00, 0.78, 1.02)
ramp(12.00, 12.25, 1.02, 0.80)  # zoom through
ramp(12.25, 12.70, 0.80, 1.05)
ramp(15.85, 16.05, 1.05, 0.90)  # blur crossfade: settle
ramp(16.05, 16.50, 0.90, 1.00)
ramp(18.58, 18.75, 1.00, 0.85)  # finale push
ramp(18.75, 19.20, 0.85, 1.10)
buf[:, 0] += pad * duck * 0.42
buf[:, 1] += pad * duck * 0.40

# a whisper of air, high band
air = bandpass_fft(noise(TOTAL, rng), 2600, 9000)
air *= np.linspace(0.0, 1.0, len(air)) ** 0.4
buf[:, 0] += air * 0.014 * duck
buf[:, 1] += air * 0.013 * duck

# ---------------------------------------------------------------- S1
_mix(buf, 0.26, thump(72, 0.5, 0.55), gain=0.30)
_mix(buf, 0.48, bell(880, 0.7, 0.5), gain=0.13, pan=0.15)
for i, tt in enumerate([0.34, 0.42, 0.50, 0.58]):        # grid lines draw
    _mix(buf, tt, tick(rng), gain=0.10, pan=-0.3 + i * 0.2)
for i, tt in enumerate([0.44, 0.54]):
    _mix(buf, tt, tick(rng), gain=0.09, pan=0.25 - i * 0.4)
for i, tt in enumerate([0.97, 1.11, 1.25]):              # states land
    _mix(buf, tt, tick(rng), gain=0.12, pan=-0.25 + i * 0.25)
_mix(buf, 1.12, bell(1174.66, 0.5, 0.4), gain=0.07, pan=0.2)
_mix(buf, 1.38, bell(659.25, 0.8, 0.4), gain=0.08, pan=-0.15)
_mix(buf, 2.30, whoosh(rng, dur=0.5, lo=200, hi=3200, updown="up"), gain=0.20)

# ---------------------------------------------------------------- S2
_mix(buf, 2.66, whoosh(rng, dur=0.55, lo=350, hi=5200, updown="down"), gain=0.28)
for i, tt in enumerate([2.87, 3.07, 3.27]):              # rows arrive
    _mix(buf, tt, tick(rng), gain=0.13 + i * 0.01, pan=-0.2 + i * 0.2)
_mix(buf, 3.10, bell(659.25, 0.9, 0.5), gain=0.14, pan=0.22)
for i, tt in enumerate([3.22, 3.38, 3.54]):              # words
    _mix(buf, tt, thump(90, 0.28, 0.5, click=0.12), gain=0.15, pan=-0.15 + i * 0.15)
_mix(buf, 3.42, bell(987.77, 0.7, 0.45), gain=0.08, pan=-0.2)
_mix(buf, 3.72, bell(783.99, 1.0, 0.5), gain=0.15, pan=0.25)   # glow: amber
_mix(buf, 4.52, tick(rng), gain=0.08, pan=0.3)
_mix(buf, 6.12, tick(rng), gain=0.08, pan=0.3)
_mix(buf, 7.28, whoosh(rng, dur=0.5, lo=180, hi=2800, updown="up"), gain=0.20)

# ---------------------------------------------------------------- S3
_mix(buf, 7.66, whoosh(rng, dur=0.6, lo=400, hi=6000, updown="down"), gain=0.26)
_mix(buf, 7.92, bell(523.25, 0.9, 0.5), gain=0.15, pan=-0.18)
_mix(buf, 8.28, noise(0.05, rng), gain=0.10, pan=0.1)
for i, tt in enumerate([8.57, 8.68, 8.79]):              # chips read themselves
    _mix(buf, tt, tick(rng), gain=0.11, pan=-0.15 + i * 0.15)
_mix(buf, 8.18, whoosh(rng, dur=0.9, lo=250, hi=2600, updown="swell"), gain=0.12)
for i, tt in enumerate([9.12, 9.37, 9.62]):              # callouts
    _mix(buf, tt, tick(rng), gain=0.11, pan=0.2 + i * 0.08)
_mix(buf, 9.40, swell([392.0, 493.88, 587.33], dur=2.4, attack=1.2, strength=0.5), gain=0.30)
_mix(buf, 11.98, whoosh(rng, dur=0.45, lo=160, hi=3400, updown="up"), gain=0.24)

# ---------------------------------------------------------------- S4
_mix(buf, 12.28, whoosh(rng, dur=0.55, lo=300, hi=4200, updown="down"), gain=0.28)
_mix(buf, 12.48, thump(76, 0.45, 0.6), gain=0.36)
_mix(buf, 12.64, bell(698.46, 0.8, 0.5), gain=0.13, pan=0.2)
_mix(buf, 12.94, noise(0.04, rng), gain=0.08, pan=0.15)
for i, tt in enumerate([13.22, 13.35, 13.48, 13.61]):    # the chain
    _mix(buf, tt, tick(rng), gain=0.12, pan=-0.25 + i * 0.17)
_mix(buf, 13.35, swell([220.0, 261.63, 329.63], dur=2.2, attack=1.0, strength=0.42), gain=0.26)
_mix(buf, 15.92, whoosh(rng, dur=0.5, lo=300, hi=3600, updown="up"), gain=0.16)

# ---------------------------------------------------------------- S5
_mix(buf, 16.07, noise(0.06, rng), gain=0.10, pan=-0.1)
_mix(buf, 16.28, thump(72, 0.5, 0.5), gain=0.28)
_mix(buf, 16.32, bell(587.33, 0.9, 0.5), gain=0.14, pan=-0.2)
_mix(buf, 16.54, tick(rng), gain=0.11, pan=0.25)
for i, tt in enumerate([16.92, 17.01, 17.10, 17.19]):    # chips
    _mix(buf, tt, tick(rng), gain=0.09, pan=-0.2 + i * 0.13)
_mix(buf, 17.62, swell([293.66, 369.99, 440.0], dur=2.0, attack=0.9, strength=0.5), gain=0.28)

# ---------------------------------------------------------------- S6
_mix(buf, 18.58, whoosh(rng, dur=0.5, lo=220, hi=3400, updown="up"), gain=0.24)
_mix(buf, 18.76, thump(84, 0.5, 0.55), gain=0.32)
_mix(buf, 18.93, bell(1318.51, 0.5, 0.45), gain=0.13, pan=0.2)   # icon pop
_mix(buf, 19.08, bell(987.77, 0.9, 0.5), gain=0.14, pan=-0.15)   # wordmark
_mix(buf, 19.33, bell(659.25, 0.7, 0.4), gain=0.09, pan=0.15)
_mix(buf, 19.44, tick(rng), gain=0.09, pan=-0.2)
for tt in [19.64, 19.70, 19.75, 19.81, 19.86, 19.92, 19.97]:    # line 1 types
    _mix(buf, tt, tick(rng), gain=0.065, pan=0.15)
for tt in [20.04, 20.10, 20.16, 20.22, 20.28, 20.34, 20.40]:    # line 2 types
    _mix(buf, tt, tick(rng), gain=0.065, pan=-0.15)
for i, tt in enumerate([20.34, 20.43, 20.52]):
    _mix(buf, tt, tick(rng), gain=0.07, pan=-0.2 + i * 0.2)
_mix(buf, 20.46, swell([329.63, 415.30, 493.88, 659.25], dur=2.4, attack=0.8, strength=0.62), gain=0.44)

# ---------------------------------------------------------------- global fade
fade_in = np.clip(t / 0.5, 0, 1) ** 1.4
fade_out = np.clip((21.12 - t) / 0.6, 0, 1) ** 1.2
env = np.minimum(fade_in, fade_out)
buf *= env[:, None]

# ---------------------------------------------------------------- loudness + encode
m4a_path = os.path.join(HERE, "score.m4a")

# two-pass loudness: measure the raw mix as float32, straight through a pipe
TARGET = -16.0  # the light cut sits just under the platform norm
raw = buf.astype(np.float32).tobytes()
probe = subprocess.run(
    [
        "ffmpeg", "-hide_banner", "-nostats",
        "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "pipe:0",
        "-af", f"loudnorm=I={TARGET}:TP=-1.5:print_format=json", "-f", "null", "-",
    ],
    input=raw,
    capture_output=True,
)
m = re.search(r"\{[\s\S]*\}", probe.stderr.decode("utf-8", "replace"))
gain = 0.0
if m:
    data = json.loads(m.group(0))
    gain = TARGET - float(data["input_i"])
    print(f"measured {data['input_i']} LUFS, applying {gain:+.2f} dB")
else:
    print("warning: loudnorm probe failed, encoding at unity gain")

# the gain leaves the hits above any true-peak ceiling, and ffmpeg's limiter
# lets short clicks past its attack — a per-sample tanh clip holds the
# ceiling deterministically: -3.6 dBFS samples land the decoded m4a near
# -2 dBTP, under the player's clamp
buf *= 10 ** (gain / 20.0)
ceiling = 10 ** (-3.6 / 20.0)
knee = 0.7 * ceiling
mag = np.abs(buf)
over = mag > knee
buf[over] = np.sign(buf[over]) * (
    knee + (ceiling - knee) * np.tanh((mag[over] - knee) / (ceiling - knee))
)

# second pass: encode, then read the m4a back and print what actually landed
subprocess.run(
    [
        "ffmpeg", "-v", "error", "-y",
        "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "pipe:0",
        "-c:a", "aac", "-b:a", "192k", m4a_path,
    ],
    input=buf.astype(np.float32).tobytes(),
    check=True,
)
check = subprocess.run(
    [
        "ffmpeg", "-hide_banner", "-nostats", "-i", m4a_path,
        "-af", "loudnorm=print_format=json", "-f", "null", "-",
    ],
    capture_output=True,
    text=True,
)
m2 = re.search(r"\{[\s\S]*\}", check.stderr)
if m2:
    done = json.loads(m2.group(0))
    print(f"wrote {m4a_path} — {done['input_i']} LUFS, TP {done['input_tp']} dBTP")
else:
    print(f"wrote {m4a_path}")
