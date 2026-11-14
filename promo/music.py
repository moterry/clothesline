"""Original ambient score for the Clothesline promo, synthesised from scratch (no samples, no third-party audio).

Usage: python3 promo/music.py <out.wav> [seconds]
"""
import sys
import wave

import numpy as np

SR = 48000
DUR = float(sys.argv[2]) if len(sys.argv) > 2 else 31.5
N = int(SR * (DUR + 0.5))
t_all = np.arange(N) / SR
rng = np.random.default_rng(14)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def env_adsr(n, attack, release, total):
    e = np.ones(n)
    a = int(attack * SR)
    r = int(release * SR)
    if a:
        e[:a] = np.linspace(0, 1, a) ** 2
    if r:
        e[-r:] *= np.linspace(1, 0, r) ** 1.5
    return e[: int(total * SR)] if total else e


left = np.zeros(N)
right = np.zeros(N)


def add(sig, start, gain=1.0, pan=0.0):
    i = int(start * SR)
    j = min(N, i + len(sig))
    if j <= i:
        return
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    left[i:j] += sig[: j - i] * gain * l
    right[i:j] += sig[: j - i] * gain * r


# --- Pad: slow, soft chords that follow the six scenes --------------------------------------------
# (start, end, midi notes)
chords = [
    (0.0, 6.6, [45, 52, 57, 60, 64, 71]),        # Am9   — the few seconds, slipping away
    (5.8, 12.2, [38, 45, 53, 57, 60, 64]),       # Dm9   — the desktop piles up
    (11.4, 17.6, [36, 43, 52, 55, 62, 64]),      # Cadd9 — the line appears
    (16.8, 23.2, [40, 47, 55, 59, 62, 66]),      # Em9   — the river, recollection
    (22.4, 27.0, [41, 48, 57, 60, 64, 67]),      # Fmaj9 — letting go
    (26.2, DUR + 0.5, [36, 43, 52, 55, 60, 62, 67]),  # Cadd9 — rest
]
for start, end, notes in chords:
    n = int((end - start) * SR)
    tt = np.arange(n) / SR
    e = env_adsr(n, 1.6, 1.8, 0)
    for k, m in enumerate(notes):
        f = hz(m)
        trem = 1 + 0.12 * np.sin(2 * np.pi * (0.11 + 0.03 * k) * tt + k)
        for det, pan in [(-0.0018, -0.6), (0.0, 0.0), (0.0021, 0.6)]:
            ff = f * (1 + det)
            ph = rng.uniform(0, 2 * np.pi)
            s = np.sin(2 * np.pi * ff * tt + ph) + 0.22 * np.sin(4 * np.pi * ff * tt + ph) + 0.06 * np.sin(6 * np.pi * ff * tt)
            gain = 0.05 if m < 48 else 0.032
            add(s * e * trem, start, gain, pan)


# --- Bell / soft piano notes ----------------------------------------------------------------------
def bell(midi, dur=3.2, bright=1.0):
    f = hz(midi)
    n = int(dur * SR)
    tt = np.arange(n) / SR
    s = (np.sin(2 * np.pi * f * tt) * np.exp(-tt / 1.6)
         + 0.35 * bright * np.sin(2 * np.pi * 2 * f * tt) * np.exp(-tt / 0.7)
         + 0.12 * bright * np.sin(2 * np.pi * 3.01 * f * tt) * np.exp(-tt / 0.35)
         + 0.05 * bright * np.sin(2 * np.pi * 4.2 * f * tt) * np.exp(-tt / 0.2))
    s *= np.minimum(1, tt / 0.006)
    return s


melody = [
    (0.6, 76, 0.16, -0.2), (2.1, 72, 0.13, 0.2), (3.6, 69, 0.14, -0.1),
    (6.3, 74, 0.13, 0.1), (8.1, 72, 0.11, -0.2), (9.7, 69, 0.11, 0.2),
    (11.9, 76, 0.16, 0.0),
    (17.1, 71, 0.13, -0.1), (19.9, 83, 0.07, 0.3), (20.05, 88, 0.05, 0.35), (20.8, 79, 0.10, -0.2),
    (22.9, 69, 0.13, 0.0),
    (26.6, 72, 0.15, -0.2), (26.62, 79, 0.10, 0.2), (26.66, 88, 0.05, 0.0), (28.6, 76, 0.10, 0.1),
]
for start, m, g, pan in melody:
    add(bell(m), start, g, pan)

# Pegs clipping the screenshots onto the line: a rising pentatonic chime, one per arrival.
for j, m in enumerate([67, 69, 72, 74, 76, 79, 81]):
    add(bell(m, 1.6, 0.6), 12.7 + 0.38 * j + 0.92, 0.07, -0.5 + j * 0.16)
add(bell(79, 1.6, 0.6), 23.25, 0.07, 0.3)  # the latecomer


# --- Sound effects ---------------------------------------------------------------------------------
def noise(dur):
    return rng.standard_normal(int(dur * SR))


def lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


# Shutter: a soft click as the screenshot is taken.
click = noise(0.05) * np.exp(-np.arange(int(0.05 * SR)) / SR / 0.008)
add(lowpass(click, 0.35), 1.72, 0.18)
add(lowpass(noise(0.03) * np.exp(-np.arange(int(0.03 * SR)) / SR / 0.006), 0.5), 1.80, 0.10)

# Snip: two small metallic ticks.
for k, off in enumerate([16.93, 16.99]):
    n = int(0.06 * SR)
    tt = np.arange(n) / SR
    tick = (np.sin(2 * np.pi * 3400 * tt) + 0.6 * np.sin(2 * np.pi * 5200 * tt)) * np.exp(-tt / 0.012)
    add(tick, off, 0.05, 0.4)

# Sinking into Lethe: a low, dark swell.
n = int(1.6 * SR)
tt = np.arange(n) / SR
swell = lowpass(noise(1.6), 0.02) * np.sin(np.pi * np.minimum(tt / 1.6, 1)) * 2.2
glide = np.sin(2 * np.pi * np.cumsum(110 - 45 * (tt / 1.6)) / SR) * np.exp(-tt / 0.9) * 0.6
add(swell + glide, 24.6, 0.09)

# --- Reverb: convolution with a decaying noise tail -------------------------------------------------
ir_len = int(3.0 * SR)
ir_t = np.arange(ir_len) / SR
ir_l = rng.standard_normal(ir_len) * np.exp(-ir_t / 0.85)
ir_r = rng.standard_normal(ir_len) * np.exp(-ir_t / 0.85)
ir_l /= np.sqrt(np.sum(ir_l ** 2))
ir_r /= np.sqrt(np.sum(ir_r ** 2))


def conv(x, ir):
    size = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    return y[: len(x)]


wet = 0.32
L = (1 - wet) * left + wet * conv(left, ir_l)
R = (1 - wet) * right + wet * conv(right, ir_r)

# Fades, normalise, write.
fade_in = np.minimum(1, t_all / 1.0)
fade_out = np.clip((DUR + 0.3 - t_all) / 2.6, 0, 1)
L *= fade_in * fade_out
R *= fade_in * fade_out
peak = max(np.max(np.abs(L)), np.max(np.abs(R)))
L, R = L / peak * 0.85, R / peak * 0.85
pcm = (np.stack([L, R], axis=1) * 32767).astype(np.int16)
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print(f"wrote {sys.argv[1]} ({DUR:.1f}s)")
