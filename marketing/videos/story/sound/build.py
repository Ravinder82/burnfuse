"""
BurnFuse story — 34.4s launch score.

Dark room tone, a machine that starts ticking, and the moment it trips.
Timeline matches marketing/videos/story/index.html exactly (30 fps, 34.4 s).

    python3 sound/build.py          # writes sound/score.m4a
"""

import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "..", "tools"))
from score_lib import (  # noqa: E402
    SR,
    bell,
    drone,
    make_buffer,
    _mix,
    noise,
    swell,
    thump,
    tick,
    whoosh,
)

HERE = os.path.dirname(os.path.abspath(__file__))
TOTAL = 34.4

rng = np.random.default_rng(7)
buf = make_buffer(TOTAL)

# ---------------------------------------------------------------- room tone
drone_buf = drone(TOTAL, strength=0.15)
t = np.arange(len(drone_buf)) / SR
duck = np.ones_like(t)
def ramp(t0, t1, a, b):
    m = (t >= t0) & (t <= t1)
    duck[m] *= np.interp(t[m], [t0, t1], [a, b])
ramp(12.9, 13.3, 1.0, 0.62)   # smash cut: the room goes quiet
ramp(18.6, 19.4, 0.62, 1.12)  # the reveal blooms
ramp(24.1, 25.0, 1.12, 0.95)  # settle into the feature beat
ramp(33.3, 34.2, 0.95, 0.0)   # fade with the picture
buf[:, 0] += drone_buf * duck * 0.52
buf[:, 1] += drone_buf * duck * 0.48

# ---------------------------------------------------------------- S1
_mix(buf, 0.62, thump(58, 0.6, 0.85), gain=0.5)
for i, tt in enumerate([1.50, 1.80, 2.10, 2.40]):
    _mix(buf, tt, tick(rng), gain=0.30 - i * 0.03, pan=-0.3)
_mix(buf, 2.60, bell(880, 0.5, 0.5), gain=0.12, pan=0.2)
_mix(buf, 4.55, whoosh(rng, dur=1.1, lo=100, hi=1600, updown="up"), gain=0.30)

# ---------------------------------------------------------------- S2
_mix(buf, 5.05, whoosh(rng, dur=0.7, lo=200, hi=5000, updown="down"), gain=0.5)
_mix(buf, 5.72, whoosh(rng, dur=3.4, lo=300, hi=2600, updown="up"), gain=0.16)  # the line draws
tick_times = [5.90, 6.40, 6.90, 7.40, 7.92, 8.30, 8.63, 8.96, 9.30, 9.63, 9.95]
for i, tt in enumerate(tick_times):
    g = 0.22 + 0.016 * i
    _mix(buf, tt, tick(rng), gain=g * 0.9, pan=(-0.25 if i % 2 else 0.25))
_mix(buf, 8.37, bell(659, 0.9, 0.5), gain=0.2)
# the trip
_mix(buf, 10.05, thump(45, 1.1, 1.0, click=0.7), gain=0.85)
_mix(buf, 10.06, bell(1318, 0.6, 0.5), gain=0.22, pan=0.28)
_mix(buf, 10.07, noise(0.02, rng) * 0.5, gain=0.4, pan=0.28)
for tt in [10.9, 11.9, 12.9]:
    _mix(buf, tt, tick(rng), gain=0.3, pan=0.2)

# ---------------------------------------------------------------- S3
_mix(buf, 13.03, noise(0.05, rng), gain=0.3)
for tt, pan in [(13.42, -0.4), (13.52, -0.3), (13.62, -0.3), (13.72, -0.4), (14.20, -0.3)]:
    _mix(buf, tt, tick(rng), gain=0.16, pan=pan)
_mix(buf, 14.55, thump(88, 0.5, 0.6, click=0.3), gain=0.5)
_mix(buf, 14.56, bell(523, 0.9, 0.45), gain=0.2, pan=0.35)
_mix(buf, 18.80, whoosh(rng, dur=1.2, lo=180, hi=3800, updown="up"), gain=0.35)
_mix(buf, 18.85, swell([220, 330, 440], dur=1.5, attack=0.65, strength=0.55), gain=0.5)

# ---------------------------------------------------------------- S4
_mix(buf, 19.50, whoosh(rng, dur=0.6, lo=2500, hi=7000, updown="swell"), gain=0.1)
_mix(buf, 20.00, bell(1320, 0.7, 0.5), gain=0.3)
_mix(buf, 20.02, noise(0.015, rng), gain=0.22)
_mix(buf, 20.15, thump(65, 0.7, 0.85), gain=0.55)
_mix(buf, 20.55, whoosh(rng, dur=0.55, lo=150, hi=2200, updown="down"), gain=0.35)
for i, tt in enumerate([21.10, 21.18, 21.26, 21.34]):
    _mix(buf, tt, tick(rng), gain=0.12, pan=0.3 - i * 0.2)

# ---------------------------------------------------------------- S5
_mix(buf, 24.30, whoosh(rng, dur=0.5, lo=140, hi=3000, updown="up"), gain=0.4)
for tt, f, pan in [(24.72, 440, -0.3), (24.86, 554, 0.0), (25.00, 659, 0.3)]:
    _mix(buf, tt, bell(f, 0.5, 0.35), gain=0.16, pan=pan)
for i, tt in enumerate([25.50, 25.62, 25.74, 25.86]):
    _mix(buf, tt, tick(rng), gain=0.08, pan=-0.2 + i * 0.13)
_mix(buf, 26.50, whoosh(rng, dur=0.6, lo=120, hi=1500, updown="down"), gain=0.3)
_mix(buf, 26.90, thump(70, 0.35, 0.4, click=0.2), gain=0.35)
_mix(buf, 27.60, thump(70, 0.35, 0.4, click=0.2), gain=0.28)

# ---------------------------------------------------------------- S6
_mix(buf, 29.80, whoosh(rng, dur=0.6, lo=180, hi=3600, updown="down"), gain=0.4)
_mix(buf, 30.10, thump(72, 0.5, 0.6), gain=0.5)
_mix(buf, 30.24, thump(60, 0.6, 0.7), gain=0.55)
for tt in [30.62, 30.95]:
    _mix(buf, tt, tick(rng), gain=0.22, pan=-0.2)
for i, tt in enumerate([31.35, 31.44, 31.53]):
    _mix(buf, tt, tick(rng), gain=0.13, pan=0.25 - i * 0.25)
_mix(buf, 31.60, swell([220, 277.2, 330, 440], dur=2.6, attack=0.9, strength=0.7), gain=0.6)

# ---------------------------------------------------------------- loudness + encode
import json, re  # noqa: E402

m4a_path = os.path.join(HERE, "score.m4a")

# two-pass loudness: measure the raw mix as float32, straight through a pipe
TARGET = -17.5  # a room-tone score with big hits; the player clamps louder masters anyway
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
