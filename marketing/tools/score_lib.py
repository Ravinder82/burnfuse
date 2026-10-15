"""
score_lib — minimal, deterministic sound-design toolkit for BurnFuse launch
videos. Pure numpy synthesis: drones, thumps, ticks, bells, whooshes.

Everything is mixed into one stereo float buffer at 48 kHz; each video's
sound/build.py pipes it to ffmpeg and writes score.m4a.
"""

import numpy as np

SR = 48000


def make_buffer(duration):
    """Stereo float buffer, shape (n, 2)."""
    n = int(round(duration * SR))
    return np.zeros((n, 2), dtype=np.float64)


def _at(buf, t):
    return int(round(t * SR))


def _mix(buf, t, signal, gain=1.0, pan=0.0):
    """Add `signal` (mono float array) into the buffer at time t.

    pan: -1 left … +1 right, using equal-power law.
    """
    i = _at(buf, t)
    if i < 0:
        signal = signal[-i:]
        i = 0
    n = min(len(signal), len(buf) - i)
    if n <= 0:
        return
    seg = signal[:n] * gain
    l = np.sqrt((1.0 - pan) / 2.0)
    r = np.sqrt((1.0 + pan) / 2.0)
    buf[i : i + n, 0] += seg * l
    buf[i : i + n, 1] += seg * r


def env_adsr(n, attack=0.005, decay=0.1, sustain=0.0, release=0.2, curve="exp"):
    """Simple envelope of length n: attack -> decay -> sustain -> release."""
    e = np.zeros(n)
    a = min(int(attack * SR), n)
    d = min(int(decay * SR), n - a)
    r = min(int(release * SR), n - a - d)
    s = n - a - d - r
    if a > 0:
        e[:a] = np.linspace(0, 1, a, endpoint=False)
    if d > 0:
        e[a : a + d] = np.linspace(1, sustain, d, endpoint=False)
    if s > 0:
        e[a + d : a + d + s] = sustain
    if r > 0:
        e[a + d + s :] = np.linspace(sustain, 0, r)
    if curve == "exp":
        e = e**1.6
    return e


def sine(freq, dur, phase=0.0, detune=0.0):
    t = np.arange(int(round(dur * SR))) / SR
    f = freq + detune
    return np.sin(2 * np.pi * f * t + phase)


def noise(dur, rng):
    return rng.uniform(-1, 1, int(round(dur * SR)))


def one_pole_lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):  # short buffers only — fine at build time
        acc = a * acc + (1 - a) * x[i]
        y[i] = acc
    return y


def bandpass_fft(x, lo, hi):
    """Zero-phase band-pass by FFT mask — deterministic, no ringing issues."""
    n = len(x)
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, d=1 / SR)
    mask = np.ones_like(freqs)
    mask[freqs < lo] = 0
    mask[freqs > hi] = 0
    # soft edges
    lo_fade = (freqs >= lo) & (freqs < lo * 1.5)
    hi_fade = (freqs > hi / 1.5) & (freqs <= hi)
    mask[lo_fade] = (freqs[lo_fade] - lo) / (lo * 0.5)
    mask[hi_fade] = (hi - freqs[hi_fade]) / (hi / 3)
    return np.fft.irfft(X * mask, n=n)


# ---------------------------------------------------------------- one-shots


def tick(rng, strength=1.0):
    """A small precise click — like a syslog line landing."""
    d = 0.06
    n = int(d * SR)
    nz = noise(d, rng) * env_adsr(n, attack=0.0005, decay=0.01, release=0.03, curve="exp")
    tone = sine(1900, d) * env_adsr(n, attack=0.0005, decay=0.012, release=0.03)
    return (nz * 0.25 + tone * 0.75) * strength


def thump(freq=58.0, dur=0.5, strength=1.0, click=0.4):
    """A low, felt-not-heard impact."""
    tone = sine(freq, dur)
    e = env_adsr(len(tone), attack=0.002, decay=dur * 0.55, release=dur * 0.4)
    out = tone * e
    if click > 0:
        c = noise(0.012, np.random.default_rng(1)) * click * 0.4
        out[: len(c)] += c
    return out * strength


def bell(freq, dur=1.1, strength=1.0):
    """A clean chime: fundamental + soft inharmonic partials."""
    out = np.zeros(int(dur * SR))
    for ratio, g, decay in ((1.0, 1.0, dur), (2.0, 0.35, dur * 0.55), (2.76, 0.18, dur * 0.4), (5.4, 0.07, dur * 0.25)):
        partial = sine(freq * ratio, dur)
        e = env_adsr(len(partial), attack=0.001, decay=decay * 0.7, release=decay * 0.3)
        out += partial * e * g
    out /= 1.6
    return out * strength


def whoosh(rng, dur=0.7, lo=120, hi=4000, updown="down", strength=1.0):
    """Filtered noise swell — a camera move you can hear."""
    x = noise(dur, rng)
    x = bandpass_fft(x, lo, hi)
    t = np.linspace(0, 1, len(x))
    shape = np.sin(np.pi * t) if updown == "swell" else (1 - t) ** 2
    if updown == "up":
        shape = np.linspace(0, 1, len(x)) ** 2
    if updown == "down":
        shape = np.linspace(1, 0, len(x)) ** 1.5
    e = shape * (0.9 - 0.4 * np.sin(np.pi * t))
    return x * e * strength


def swell(freqs, dur=1.6, attack=0.5, strength=1.0):
    """A slow warm chord bloom — the reveal sound."""
    out = np.zeros(int(dur * SR))
    for i, f in enumerate(freqs):
        v = sine(f, dur, detune=(0.6 if i % 2 else -0.5))
        e = env_adsr(len(v), attack=attack, decay=dur - attack - 0.4, sustain=0.5, release=0.4, curve="lin")
        out += v * e * (1.0 / (1 + i * 0.6))
    out /= len(freqs) * 0.9
    return out * strength


def drone(duration, strength=0.16):
    """The room tone: A1 + fifth + a whisper of detune beating."""
    n = int(duration * SR)
    t = np.arange(n) / SR
    lfo = 0.82 + 0.18 * np.sin(2 * np.pi * 0.07 * t)
    sig = (
        np.sin(2 * np.pi * 55.0 * t)
        + 0.55 * np.sin(2 * np.pi * 82.5 * t + 0.4)
        + 0.3 * np.sin(2 * np.pi * 110.4 * t)
        + 0.22 * np.sin(2 * np.pi * 55.35 * t)
    )
    sig *= lfo
    return sig * strength



