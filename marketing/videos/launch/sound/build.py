"""
BurnFuse launch reel — 24.0s / 16:9 launch score.

Grid: 150 BPM → beat 0.4 s → 12 frames @ 30 fps → bar 48 frames.
720 frames = 60 beats = 15 bars. Scene map (bars):

    B1        hook        0.0 – 1.6    cold open, dark
    B2–B3     climb       1.6 – 4.8    the meter runs, accelerating
    B4        trip        4.8 – 6.4    red slam
    B5–B7     flow        6.4 – 11.2   told in the same minute
    B8–B10    product     11.2 – 16.0  one window / paste a key
    B11–B13   states      16.0 – 20.8  settled → climbing → tripped
    B14–B15   brand       20.8 – 24.0  endcard

    python3 sound/build.py    # writes sound/launch-score.m4a and copies it to
                             # public/sound/launch-score.m4a (what Remotion plays)
"""

import json
import os
import re
import shutil
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "..", "tools"))
from score_lib import (  # noqa: E402
    SR,
    _mix,
    bandpass_fft,
    bell,
    drone,
    env_adsr,
    make_buffer,
    noise,
    sine,
    swell,
    thump,
    tick,
    whoosh,
)

HERE = os.path.dirname(os.path.abspath(__file__))
TOTAL = 24.0
BEAT = 0.4  # 150 BPM
rng = np.random.default_rng(7)

buf = make_buffer(TOTAL)

# ---------------------------------------------------------------- room tone
n = int(TOTAL * SR)
t = np.arange(n) / SR
room = drone(TOTAL, strength=0.09)
# a slow brightness lift toward the endcard
room_env = np.clip(0.6 + t / TOTAL, 0, 1.0)
buf[:, 0] += room * room_env * 0.9
buf[:, 1] += room * room_env * 0.85


def beats(t0, t1, step=BEAT):
    return np.arange(t0, t1 - 1e-6, step)


# ---------------------------------------------------------------- B1 hook
_mix(buf, 0.00, thump(48, 0.9, 0.9, click=0.7), gain=0.85)
_mix(buf, 0.10, bell(220.0, 1.4, 0.5), gain=0.14, pan=-0.1)
for i, tt in enumerate([0.30, 0.55, 0.75, 0.95, 1.10, 1.25, 1.38, 1.48]):
    _mix(buf, tt, tick(rng), gain=0.10 + 0.03 * i, pan=(-0.25 if i % 2 else 0.25))
_mix(buf, 1.00, bell(659.25, 0.6, 0.5), gain=0.12, pan=0.2)
_mix(buf, 1.30, whoosh(rng, dur=0.5, lo=200, hi=3600, updown="up"), gain=0.22)

# riser into the climb
_mix(buf, 1.20, whoosh(rng, dur=0.8, lo=180, hi=4800, updown="up"), gain=0.26)

# ---------------------------------------------------------------- B2–B3 climb
bar0 = 1.6
for b in beats(bar0, 4.8):
    _mix(buf, b, thump(58, 0.42, 0.85, click=0.35), gain=0.6)
for bar in range(2, 4):  # snares on beats 2 & 4
    for off in (0.4, 1.2):
        x = bandpass_fft(noise(0.09, rng), 500, 5200)
        _mix(buf, bar0 + (bar - 2) * 1.6 + off, x * env_adsr(len(x), attack=0.001, decay=0.05, release=0.03), gain=0.30, pan=0.08)
# accelerating meter runs (eighth → sixteenth, tightening step)
run_t = 1.9
step = 0.2
gain_r = 0.10
while run_t < 4.62:
    _mix(buf, run_t, tick(rng), gain=gain_r, pan=(-0.2 if int(run_t * 100) % 2 else 0.2))
    run_t += step
    gain_r += 0.022
    step *= 0.93
_mix(buf, 4.20, whoosh(rng, dur=0.7, lo=220, hi=5200, updown="up"), gain=0.30)

# ---------------------------------------------------------------- B4 trip
_mix(buf, 4.80, thump(42, 1.3, 1.0, click=0.9), gain=1.05)
_mix(buf, 4.81, noise(0.03, rng) * 0.7, gain=0.5)
_mix(buf, 4.82, bell(1318.51, 0.9, 0.5), gain=0.24, pan=0.25)
_mix(buf, 4.84, whoosh(rng, dur=0.7, lo=300, hi=5000, updown="down"), gain=0.34)
# sub drop: 110 → 38 Hz over 0.55 s
sd = 0.55
tn = np.arange(int(sd * SR)) / SR
freqs = 110 * np.exp(np.log(38 / 110) * tn / sd)
phase = 2 * np.pi * np.cumsum(freqs) / SR
_mix(buf, 4.95, np.sin(phase) * env_adsr(len(tn), attack=0.004, decay=0.28, release=0.24), gain=0.42)
for i, tt in enumerate(np.arange(5.15, 6.35, 0.12)):  # tense roll
    _mix(buf, tt, tick(rng), gain=0.14 + 0.02 * i, pan=0.25 - i * 0.05)
_mix(buf, 6.10, whoosh(rng, dur=0.5, lo=200, hi=4200, updown="down"), gain=0.24)

# ---------------------------------------------------------------- B5–B7 flow
bar0 = 6.4
for b in beats(bar0, 11.2):
    _mix(buf, b, thump(56, 0.4, 0.8, click=0.3), gain=0.58)
for bar in range(5, 8):
    for off in (0.4, 1.2):
        x = bandpass_fft(noise(0.08, rng), 600, 5600)
        _mix(buf, bar0 + (bar - 5) * 1.6 + off, x * env_adsr(len(x), attack=0.001, decay=0.045, release=0.03), gain=0.26, pan=0.06)
    for hb in [bar0 + (bar - 5) * 1.6 + 0.2, bar0 + (bar - 5) * 1.6 + 0.6, bar0 + (bar - 5) * 1.6 + 1.0, bar0 + (bar - 5) * 1.6 + 1.4]:
        _mix(buf, hb, tick(rng), gain=0.15, pan=(-0.3 if int(hb * 100) % 4 < 2 else 0.3))
# chain pops on the bar line + beats
for i, tt in enumerate([6.40, 6.80, 7.20, 7.60, 8.00]):
    _mix(buf, tt, thump(76 + 6 * i, 0.35, 0.55, click=0.25), gain=0.3, pan=-0.2 + 0.1 * i)
    _mix(buf, tt + 0.02, bell(523.25 * (1 + 0.25 * i), 0.5, 0.45), gain=0.10, pan=0.2)
# bass pulse each bar + arps
for bar in range(5, 8):
    root = [110.0, 87.31, 98.0][bar - 5]
    _mix(buf, bar0 + (bar - 5) * 1.6, sine(root, 0.5) * env_adsr(int(0.5 * SR), attack=0.005, decay=0.3, release=0.15), gain=0.30)
for i, tt in enumerate([8.8, 9.2, 9.6, 10.0, 10.4, 10.8]):
    _mix(buf, tt, bell([659.25, 587.33, 783.99, 659.25, 880.0, 659.25][i], 0.45, 0.5), gain=0.09, pan=(-0.22 if i % 2 else 0.22))
_mix(buf, 10.70, whoosh(rng, dur=0.55, lo=240, hi=4200, updown="up"), gain=0.24)

# ---------------------------------------------------------------- B8–B10 product
bar0 = 11.2
for b in beats(bar0, 16.0):
    _mix(buf, b, thump(56, 0.4, 0.8, click=0.3), gain=0.55)
for bar in range(8, 11):
    for off in (0.4, 1.2):
        x = bandpass_fft(noise(0.08, rng), 600, 5600)
        _mix(buf, bar0 + (bar - 8) * 1.6 + off, x * env_adsr(len(x), attack=0.001, decay=0.045, release=0.03), gain=0.24, pan=0.06)
    for hb in [bar0 + (bar - 8) * 1.6 + 0.2, bar0 + (bar - 8) * 1.6 + 0.6, bar0 + (bar - 8) * 1.6 + 1.0, bar0 + (bar - 8) * 1.6 + 1.4]:
        _mix(buf, hb, tick(rng), gain=0.13, pan=(0.3 if int(hb * 100) % 4 < 2 else -0.3))
for bar, root in zip(range(8, 11), [110.0, 130.81, 98.0]):
    _mix(buf, bar0 + (bar - 8) * 1.6, sine(root, 0.5) * env_adsr(int(0.5 * SR), attack=0.005, decay=0.3, release=0.15), gain=0.28)
# product slams + chord blooms
_mix(buf, 11.20, thump(70, 0.5, 0.6, click=0.3), gain=0.4)
_mix(buf, 11.24, bell(659.25, 0.8, 0.5), gain=0.16, pan=0.2)
_mix(buf, 12.80, bell(587.33, 0.9, 0.5), gain=0.15, pan=-0.18)
_mix(buf, 14.40, swell([261.63, 329.63, 392.0], dur=1.4, attack=0.35, strength=0.45), gain=0.30)
for i, tt in enumerate([12.0, 12.4, 13.2, 13.6, 14.0, 14.8, 15.2, 15.6]):
    _mix(buf, tt, tick(rng), gain=0.10, pan=(-0.25 if i % 2 else 0.25))
_mix(buf, 15.55, whoosh(rng, dur=0.55, lo=260, hi=4800, updown="up"), gain=0.26)

# ---------------------------------------------------------------- B11–B13 states
bar0 = 16.0
for bar in range(11, 14):
    ts = bar0 + (bar - 11) * 1.6
    for b in beats(ts, ts + 1.6):
        _mix(buf, b, thump(60, 0.38, 0.85, click=0.4), gain=0.62)
    for hb in [ts + 0.2, ts + 0.6, ts + 1.0, ts + 1.4]:
        _mix(buf, hb, tick(rng), gain=0.16, pan=(0.28 if int(hb * 100) % 4 < 2 else -0.28))
    for off in (0.4, 1.2):
        x = bandpass_fft(noise(0.08, rng), 700, 6000)
        _mix(buf, ts + off, x * env_adsr(len(x), attack=0.001, decay=0.04, release=0.03), gain=0.28, pan=0.05)
# state bells rising + dense stutters inside each bar
state_bells = [(16.0, 523.25, 0.16), (17.6, 698.46, 0.18), (19.2, 880.0, 0.22)]
for tt, f, g in state_bells:
    _mix(buf, tt, bell(f, 0.7, 0.5), gain=g, pan=0.18)
for bar in range(11, 14):
    ts = bar0 + (bar - 11) * 1.6
    for i, st in enumerate(np.arange(ts + 0.3, ts + 1.55, 0.2)):
        _mix(buf, st, thump(88, 0.16, 0.4, click=0.3), gain=0.10 + 0.02 * i, pan=(-0.15 if i % 2 else 0.15))
# snare build into the brand hit
roll = 19.6
step = 0.2
g = 0.14
while roll < 20.72:
    x = bandpass_fft(noise(0.06, rng), 700, 6800)
    _mix(buf, roll, x * env_adsr(len(x), attack=0.001, decay=0.03, release=0.02), gain=g, pan=0.05)
    roll += step
    step *= 0.86
    g += 0.05
_mix(buf, 19.55, whoosh(rng, dur=1.15, lo=180, hi=5600, updown="up"), gain=0.32)

# ---------------------------------------------------------------- B14–B15 brand
_mix(buf, 20.80, thump(46, 1.1, 1.0, click=0.8), gain=1.0)
_mix(buf, 20.82, noise(0.025, rng) * 0.6, gain=0.4)
_mix(buf, 20.90, swell([220.0, 261.63, 329.63, 440.0], dur=2.6, attack=0.5, strength=0.6), gain=0.5)
_mix(buf, 20.85, bell(880.0, 1.2, 0.5), gain=0.18, pan=0.2)
_mix(buf, 20.86, bell(1318.51, 0.9, 0.5), gain=0.14, pan=-0.2)
for b in [20.8, 21.2, 21.6, 22.0, 22.4]:
    _mix(buf, b, thump(52, 0.5, 0.8, click=0.35), gain=0.6 if b > 20.9 else 0.75)
for i, hb in enumerate([21.0, 21.4, 21.8, 22.2]):
    _mix(buf, hb, tick(rng), gain=0.14, pan=(0.25 if i % 2 else -0.25))
# the URL types
for i, tt in enumerate(np.arange(21.6, 22.7, 0.07)):
    _mix(buf, tt, tick(rng), gain=0.07, pan=0.18)
_mix(buf, 22.40, swell([174.61, 220.0, 261.63, 349.23], dur=1.5, attack=0.4, strength=0.4), gain=0.34)
_mix(buf, 23.00, bell(659.25, 1.1, 0.5), gain=0.12, pan=0.15)

# ---------------------------------------------------------------- global fade
fade_in = np.clip(t / 0.12, 0, 1) ** 1.2
fade_out = np.clip((23.92 - t) / 0.42, 0, 1) ** 1.2
buf *= np.minimum(fade_in, fade_out)[:, None]

# ---------------------------------------------------------------- loudness + encode
m4a_path = os.path.join(HERE, "launch-score.m4a")
TARGET = -14.0  # launch cut rides hotter — it's a trailer
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

buf *= 10 ** (gain / 20.0)
ceiling = 10 ** (-3.6 / 20.0)
knee = 0.7 * ceiling
mag = np.abs(buf)
over = mag > knee
buf[over] = np.sign(buf[over]) * (
    knee + (ceiling - knee) * np.tanh((mag[over] - knee) / (ceiling - knee))
)

subprocess.run(
    [
        "ffmpeg", "-v", "error", "-y",
        "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "pipe:0",
        "-c:a", "aac", "-b:a", "192k", m4a_path,
    ],
    input=buf.astype(np.float32).tobytes(),
    check=True,
)
# keep Remotion's copy in step — the render plays public/sound/launch-score.m4a
pub = os.path.join(HERE, "..", "public", "sound")
os.makedirs(pub, exist_ok=True)
shutil.copyfile(m4a_path, os.path.join(pub, "launch-score.m4a"))
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
