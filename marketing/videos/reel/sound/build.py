"""
BurnFuse reel — 18.2s vertical launch score.

The story compressed for a phone: a fast climb, a hard trip, then the proof.
Timeline matches marketing/videos/reel/index.html (30 fps, 18.2 s).

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
    bell,
    drone,
    make_buffer,
    noise,
    swell,
    thump,
    tick,
    whoosh,
)

HERE = os.path.dirname(os.path.abspath(__file__))
TOTAL = 18.2

rng = np.random.default_rng(13)
buf = make_buffer(TOTAL)

# ---------------------------------------------------------------- room tone
drone_buf = drone(TOTAL, strength=0.18)
t = np.arange(len(drone_buf)) / SR
duck = np.ones_like(t)


def ramp(t0, t1, a, b):
    m = (t >= t0) & (t <= t1)
    duck[m] *= np.interp(t[m], [t0, t1], [a, b])


ramp(2.35, 2.55, 1.0, 0.75)
ramp(2.55, 2.90, 0.75, 1.02)
ramp(7.20, 7.45, 1.02, 0.78)
ramp(7.45, 7.85, 0.78, 1.05)
ramp(10.30, 10.55, 1.05, 0.82)
ramp(10.55, 11.00, 0.82, 1.02)
ramp(13.40, 13.62, 1.02, 0.85)
ramp(13.62, 14.10, 0.85, 1.05)
ramp(15.95, 16.20, 1.05, 0.82)
ramp(16.20, 16.70, 0.82, 1.12)
buf[:, 0] += drone_buf * duck * 0.54
buf[:, 1] += drone_buf * duck * 0.50

# ---------------------------------------------------------------- S1 hook
_mix(buf, 0.30, thump(60, 0.6, 0.8), gain=0.45)
for i, tt in enumerate([0.48, 0.60]):
    _mix(buf, tt, tick(rng), gain=0.16, pan=-0.25 + i * 0.5)
_mix(buf, 0.72, bell(880, 0.6, 0.5), gain=0.12, pan=0.2)
_mix(buf, 1.36, tick(rng), gain=0.20, pan=0.25)          # the seed line
_mix(buf, 1.60, bell(1174.66, 0.5, 0.4), gain=0.08, pan=0.1)
_mix(buf, 2.28, whoosh(rng, dur=0.5, lo=160, hi=3200, updown="up"), gain=0.28)

# ---------------------------------------------------------------- S2 climb
_mix(buf, 2.62, whoosh(rng, dur=0.6, lo=300, hi=4800, updown="down"), gain=0.34)
_mix(buf, 2.90, tick(rng), gain=0.14, pan=-0.2)
_mix(buf, 3.20, whoosh(rng, dur=3.2, lo=260, hi=2400, updown="up"), gain=0.15)   # the torque winds
climb = [3.45, 3.80, 4.12, 4.42, 4.70, 4.95, 5.18, 5.38, 5.56, 5.72, 5.86, 5.99]
for i, tt in enumerate(climb):                            # accelerating meter
    _mix(buf, tt, tick(rng), gain=0.11 + 0.016 * i, pan=(-0.2 if i % 2 else 0.2))
_mix(buf, 5.28, bell(659.25, 0.8, 0.5), gain=0.16, pan=0.22)   # crosses the cap
_mix(buf, 5.30, noise(0.03, rng), gain=0.18, pan=0.22)
# the trip
_mix(buf, 6.68, thump(42, 1.2, 1.0, click=0.75), gain=0.92)
_mix(buf, 6.69, bell(1318.51, 0.6, 0.5), gain=0.22, pan=0.28)
_mix(buf, 6.70, noise(0.02, rng) * 0.5, gain=0.4, pan=0.28)
for tt in [6.95, 7.10]:
    _mix(buf, tt, tick(rng), gain=0.26, pan=0.2)
_mix(buf, 7.22, noise(0.05, rng), gain=0.3)

# ---------------------------------------------------------------- S3 states
_mix(buf, 7.45, whoosh(rng, dur=0.6, lo=380, hi=5600, updown="down"), gain=0.30)
_mix(buf, 7.72, bell(523.25, 0.9, 0.5), gain=0.16, pan=-0.18)
for i, tt in enumerate([7.98, 8.18, 8.38]):               # the three rows
    _mix(buf, tt, thump(88, 0.3, 0.5, click=0.2), gain=0.20, pan=-0.2 + i * 0.2)
    _mix(buf, tt + 0.02, tick(rng), gain=0.13, pan=0.15)
_mix(buf, 8.62, bell(783.99, 1.0, 0.5), gain=0.18, pan=0.25)   # trip glow
_mix(buf, 8.85, swell([220.0, 261.63, 329.63], dur=2.2, attack=1.0, strength=0.45), gain=0.30)
_mix(buf, 9.30, tick(rng), gain=0.09, pan=0.3)
_mix(buf, 10.32, whoosh(rng, dur=0.45, lo=180, hi=3200, updown="up"), gain=0.28)

# ---------------------------------------------------------------- S4 tells you
_mix(buf, 10.55, whoosh(rng, dur=0.6, lo=300, hi=4400, updown="down"), gain=0.30)
_mix(buf, 10.78, thump(76, 0.45, 0.6), gain=0.38)
_mix(buf, 10.92, bell(698.46, 0.8, 0.5), gain=0.14, pan=0.2)
_mix(buf, 10.88, noise(0.05, rng), gain=0.10)
for i, tt in enumerate([11.52, 11.67, 11.82, 11.97]):     # the chain
    _mix(buf, tt, tick(rng), gain=0.15, pan=-0.25 + i * 0.17)
_mix(buf, 12.10, thump(70, 0.4, 0.5, click=0.2), gain=0.24)
_mix(buf, 13.45, whoosh(rng, dur=0.55, lo=240, hi=3800, updown="up"), gain=0.22)

# ---------------------------------------------------------------- S5 proof
_mix(buf, 13.66, noise(0.05, rng), gain=0.10)
_mix(buf, 13.88, bell(587.33, 0.9, 0.5), gain=0.15, pan=-0.15)
for i, tt in enumerate([14.08, 14.36, 14.64]):            # the three cards
    _mix(buf, tt, thump(84, 0.3, 0.5, click=0.18), gain=0.22, pan=-0.15 + i * 0.15)
    _mix(buf, tt + 0.03, tick(rng), gain=0.12, pan=0.2)
_mix(buf, 15.10, swell([293.66, 369.99, 440.0], dur=1.8, attack=0.8, strength=0.5), gain=0.26)

# ---------------------------------------------------------------- S6 CTA
_mix(buf, 16.02, whoosh(rng, dur=0.5, lo=200, hi=3400, updown="up"), gain=0.28)
_mix(buf, 16.22, whoosh(rng, dur=0.55, lo=300, hi=4400, updown="down"), gain=0.28)
_mix(buf, 16.38, thump(72, 0.5, 0.6), gain=0.40)
_mix(buf, 16.42, bell(1318.51, 0.5, 0.45), gain=0.14, pan=0.2)
_mix(buf, 16.58, bell(987.77, 0.9, 0.5), gain=0.15, pan=-0.15)
_mix(buf, 16.95, tick(rng), gain=0.12, pan=-0.2)
for tt in [17.10, 17.17, 17.24, 17.31, 17.38, 17.45]:     # the URL types
    _mix(buf, tt, tick(rng), gain=0.08, pan=0.15)
for i, tt in enumerate([17.32, 17.42, 17.52]):
    _mix(buf, tt, tick(rng), gain=0.09, pan=-0.2 + i * 0.2)
_mix(buf, 17.25, swell([329.63, 415.30, 493.88, 659.25], dur=2.2, attack=0.7, strength=0.65), gain=0.48)

# ---------------------------------------------------------------- global fade
fade_in = np.clip(t / 0.45, 0, 1) ** 1.4
fade_out = np.clip((18.14 - t) / 0.5, 0, 1) ** 1.2
env = np.minimum(fade_in, fade_out)
buf *= env[:, None]

# ---------------------------------------------------------------- loudness + encode
m4a_path = os.path.join(HERE, "score.m4a")

# two-pass loudness: measure the raw mix as float32, straight through a pipe
TARGET = -16.0  # the phone cut rides a touch over the story
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
