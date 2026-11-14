"""Original, upbeat score for the Clothesline promo — synthesised from scratch (no samples, no third-party audio).

A light, bouncy tune in C major at 112 BPM: a playful tick-tock while the screenshot waits, a slide whistle as it
drops onto the desktop, rising blips as the desktop fills up, a cartoon "uh-oh", then a sunny groove (kick, clap,
shaker, bass, ukulele-like chords, kalimba melody) once the clothesline appears. Every sound effect lands on the
matching on-screen moment.

Usage: python3 promo/music.py <out.wav> [seconds]
"""
import sys
import wave

import numpy as np

SR = 48000
DUR = float(sys.argv[2]) if len(sys.argv) > 2 else 31.5
N = int(SR * (DUR + 0.6))
rng = np.random.default_rng(14)
BPM = 112
BEAT = 60 / BPM
GROOVE = 11.9            # the clothesline appears: the band comes in
END_HIT = GROOVE + 32 * BEAT  # last downbeat, then ring out

L = np.zeros(N)
R = np.zeros(N)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def add(sig, start, gain=1.0, pan=0.0):
    i = int(round(start * SR))
    if i >= N or start < 0:
        return
    j = min(N, i + len(sig))
    a = (pan + 1) * np.pi / 4
    L[i:j] += sig[: j - i] * gain * np.cos(a)
    R[i:j] += sig[: j - i] * gain * np.sin(a)


def tt(d):
    return np.arange(int(d * SR)) / SR


# --- Instruments ---------------------------------------------------------------------------------------------

def marimba(m, d=0.7):
    t, f = tt(d), hz(m)
    s = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.28) + 0.35 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t / 0.05)
    return s * np.minimum(1, t / 0.003)


def kalimba(m, d=1.2):
    t, f = tt(d), hz(m)
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.45)
         + 0.28 * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t / 0.06)
         + 0.12 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.2))
    return s * np.minimum(1, t / 0.002)


def pluck_chord(notes, d=0.32):
    """Bright, short 'ukulele' strum: each string slightly late, quick decay."""
    out = np.zeros(int((d + 0.05) * SR))
    for k, m in enumerate(notes):
        t, f = tt(d), hz(m)
        s = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(4 * np.pi * f * t) + 0.25 * np.sin(6 * np.pi * f * t)) * np.exp(-t / 0.11)
        off = int(k * 0.012 * SR)
        out[off: off + len(s)] += s[: len(out) - off]
    return out * 0.5


def bass(m, d=0.42):
    t, f = tt(d), hz(m)
    s = np.tanh(1.6 * np.sin(2 * np.pi * f * t)) * np.exp(-t / 0.22)
    return s * np.minimum(1, t / 0.004)


def kick():
    t = tt(0.32)
    f = 48 + 90 * np.exp(-t / 0.035)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.11)


def noise(d):
    return rng.standard_normal(int(d * SR))


def hp(x):
    return np.diff(x, prepend=0)


def clap():
    t = tt(0.18)
    burst = hp(hp(noise(0.18)))
    env = np.exp(-t / 0.05) * (1 + 0.6 * (np.sin(2 * np.pi * 90 * t) > 0) * (t < 0.03))
    return burst * env * 0.35


def shaker():
    t = tt(0.07)
    return hp(hp(noise(0.07))) * np.exp(-t / 0.018) * 0.18


def woodblock(m):
    t, f = tt(0.12), hz(m)
    return (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * 2.7 * f * t)) * np.exp(-t / 0.025)


def glide(f0, f1, d, shape=1.0):
    t = tt(d)
    f = f0 + (f1 - f0) * (t / d) ** shape
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.minimum(1, t / 0.02) * np.minimum(1, (d - t) / 0.05)


def bell(m, d=2.0):
    t, f = tt(d), hz(m)
    return (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.9) + 0.3 * np.sin(2 * np.pi * 3.01 * f * t) * np.exp(-t / 0.3)) * np.minimum(1, t / 0.003)


def pad(notes, d):
    t = tt(d)
    s = np.zeros(len(t))
    for m in notes:
        for det in (-0.002, 0.002):
            s += np.sin(2 * np.pi * hz(m) * (1 + det) * t + rng.uniform(0, 6))
    env = np.minimum(1, t / 0.6) * np.minimum(1, (d - t) / 0.8)
    return s * env


# --- Scene 1 (0–6 s): a playful wait --------------------------------------------------------------------------
for k, m in enumerate([72, 76, 79, 84]):             # sunny opening arpeggio
    add(marimba(m), 0.15 + k * BEAT / 2, 0.22, -0.3 + 0.2 * k)
add(pad([60, 64, 67, 72], 6.2), 0.0, 0.035)
add(hp(noise(0.05)) * np.exp(-tt(0.05) / 0.01), 1.72, 0.25)   # shutter
add(marimba(88, 0.4), 1.74, 0.10, 0.3)
t0 = 2.25
k = 0
while t0 < 4.3:                                       # tick-tock while the few seconds run out
    add(woodblock(84 if k % 2 == 0 else 79), t0, 0.16, 0.35 if k % 2 == 0 else -0.35)
    t0 += BEAT / 1.15
    k += 1
add(glide(1300, 380, 0.7, 0.8), 4.3, 0.08, 0.2)       # slide whistle down to the desktop
add(marimba(60, 0.5), 5.0, 0.22)                       # plop

# --- Scene 2 (6–11.6 s): the desktop fills up, blip by blip ---------------------------------------------------
scale = [60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84, 86, 88, 91]
for i in range(1, 46):
    appear = 6.0 + 3.6 * (i / 45) ** 0.75
    m = scale[min(len(scale) - 1, i * len(scale) // 46)]
    add(marimba(m, 0.35), appear, 0.07, -0.6 if i % 2 else 0.6)
add(pad([57, 60, 64, 67], 5.4), 6.0, 0.03)
for k, m in enumerate([45, 47, 48, 50, 52, 53, 52, 50]):   # a curious walking bass while the cursor searches
    add(bass(m), 8.2 + k * BEAT / 1.6, 0.16)
add(glide(hz(76), hz(72), 0.22), 10.55, 0.10)           # "uh-"
add(glide(hz(71), hz(64), 0.38, 1.6), 10.8, 0.10)       # "-oh"
sweep = noise(0.9) * np.linspace(0, 1, int(0.9 * SR)) ** 2
add(hp(sweep) * 0.5, 11.0, 0.10)                         # whoosh: the clutter is swept away

# --- From 11.9 s: the clothesline groove --------------------------------------------------------------------
prog = [  # (chord tones for the strum, bass root)  — C  G  Am  F
    ([60, 64, 67, 72], 36), ([59, 62, 67, 71], 43), ([57, 60, 64, 69], 45), ([57, 60, 65, 69], 41),
]
bar = 4 * BEAT
nbars = 8
for b in range(nbars):
    chord, root = prog[b % 4]
    start = GROOVE + b * bar
    add(pad(chord, bar + 0.3), start, 0.022)
    for beat in range(4):
        tb = start + beat * BEAT
        if tb >= END_HIT:
            break
        if beat in (0, 2):
            add(kick(), tb, 0.55)
        if beat in (1, 3):
            add(clap(), tb, 0.5, 0.1)
        add(pluck_chord(chord), tb + BEAT / 2, 0.16, -0.25)           # off-beat strum
        add(shaker(), tb + BEAT / 2 + 0.02, 0.6, 0.45)
        add(shaker(), tb + 0.01, 0.35, 0.45)
        add(bass(root + (12 if beat == 3 else 0)), tb, 0.3)
# Kalimba melody: short, sunny phrases that leave room for the voice.
melody = [  # (beat offset from GROOVE, midi)
    (0, 76), (0.5, 79), (1, 81), (2, 79), (3.5, 76), (4, 74), (5, 76),
    (8, 72), (8.5, 74), (9, 76), (10, 79), (12, 81), (13, 79), (14, 76),
    (16, 76), (16.5, 79), (17, 84), (18, 83), (19, 81), (20, 79),
    (24, 72), (24.5, 76), (25, 79), (26, 81), (27, 79), (28, 84),
]
for off, m in melody:
    add(kalimba(m), GROOVE + off * BEAT, 0.12, 0.3)

# Pegs clipping onto the line: a click and a rising chime for each screenshot.
for j, m in enumerate([79, 81, 84, 86, 88, 91, 93]):
    tl = 12.7 + 0.38 * j + 0.92
    add(woodblock(96), tl, 0.07, -0.4 + 0.13 * j)
    add(bell(m, 1.0), tl, 0.06, -0.4 + 0.13 * j)

# Snip, swoosh into the river.
for off in (16.93, 16.99):
    add(np.sin(2 * np.pi * 3600 * tt(0.05)) * np.exp(-tt(0.05) / 0.01), off, 0.06, 0.4)
add(glide(900, 300, 0.6), 17.05, 0.05, -0.3)

# Recollection: a harp-like sparkle glissando.
for k, m in enumerate([72, 76, 79, 84, 88, 91, 96]):
    add(kalimba(m, 0.8), 19.85 + k * 0.045, 0.07, -0.5 + 0.16 * k)

# The latecomer arrives; Lethe: playful bubbles going down.
add(bell(91, 1.0), 23.25, 0.07, 0.3)
for k, m in enumerate([84, 79, 76, 72, 67]):
    b = glide(hz(m) * 0.8, hz(m) * 1.25, 0.09, 0.5) * 0.9
    add(b, 24.6 + k * 0.17, 0.09, 0.5 - 0.15 * k)

# --- Finale: bright resolve ----------------------------------------------------------------------------------
for k, m in enumerate([60, 64, 67, 72, 76, 79]):
    add(kalimba(m, 2.5), END_HIT + k * 0.03, 0.10, -0.3 + 0.12 * k)
add(bell(84, 3.0), END_HIT, 0.08)
add(bell(91, 3.0), END_HIT + 0.08, 0.05, 0.3)
add(kick(), END_HIT, 0.5)
add(bass(36, 1.2), END_HIT, 0.3)
add(pad([48, 55, 60, 64, 67, 72], DUR - END_HIT + 0.4), END_HIT, 0.03)
for k, m in enumerate([96, 100, 103]):                  # a little twinkle at the very end
    add(bell(m, 1.5), DUR - 2.4 + k * 0.12, 0.03, -0.3 + 0.3 * k)

# --- Small room reverb, master, write --------------------------------------------------------------------------
ir_t = tt(1.4)
irs = [rng.standard_normal(len(ir_t)) * np.exp(-ir_t / 0.35) for _ in range(2)]
irs = [ir / np.sqrt(np.sum(ir ** 2)) for ir in irs]


def conv(x, ir):
    size = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]


wet = 0.18
Lm = (1 - wet) * L + wet * conv(L, irs[0])
Rm = (1 - wet) * R + wet * conv(R, irs[1])
t_all = np.arange(N) / SR
fade = np.minimum(1, t_all / 0.08) * np.clip((DUR + 0.3 - t_all) / 1.8, 0, 1)
Lm, Rm = np.tanh(1.2 * Lm * fade) / 1.2, np.tanh(1.2 * Rm * fade) / 1.2   # gentle glue
peak = max(np.max(np.abs(Lm)), np.max(np.abs(Rm)))
Lm, Rm = Lm / peak * 0.85, Rm / peak * 0.85
pcm = (np.stack([Lm, Rm], axis=1) * 32767).astype(np.int16)
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print(f"wrote {sys.argv[1]} ({DUR:.1f}s, {BPM} BPM, groove from {GROOVE}s, final hit {END_HIT:.2f}s)")
