# -*- coding: utf-8 -*-
# ЗАДАЧА 24: стингеры событий (record_new / gates_open / keeper_awake).
# Процедурный синтез, пики < 0.7, OGG порциями.
import numpy as np
import soundfile as sf

SR = 44100
rng = np.random.default_rng(2026102824)


def lp(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / (1.0 + (f / cutoff) ** 2.0)
    return np.fft.irfft(X, len(x))


def ogg(path, x, peak=0.65):
    import os
    x = x - x.mean()
    p = np.abs(x).max() + 1e-9
    x = (x * (peak / p)).astype(np.float32)
    with sf.SoundFile(path, 'w', samplerate=SR, channels=1, format='OGG', subtype='VORBIS') as f:
        for i in range(0, len(x), SR):
            f.write(x[i:i + SR])
    print(os.path.basename(path), round(len(x) / SR, 2), 'с')


def organ(freq, ln, detune=0.35):
    t = np.arange(ln) / SR
    x = np.zeros(ln)
    for h, amp in ((1, 1.0), (2, 0.5), (3, 0.3), (4, 0.14)):
        for dt in (-detune, detune):
            x += np.sin(2 * np.pi * freq * h * (1 + dt / 100) * t) * amp * 0.5
    return lp(x, 3600)


def record_new():
    ln = int(SR * 1.1)
    x = np.zeros(ln)
    for i, f in enumerate((587.33, 739.99, 880.0, 1174.66)):
        p0 = int(i * 0.09 * SR)
        t = np.arange(ln - p0) / SR
        tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2 * t)
        x[p0:] += tone * np.exp(-t * 3.2) * 0.5
    org = organ(293.66, ln) * np.exp(-np.arange(ln) / SR * 2.2) * 0.4
    shimmer = lp(rng.standard_normal(ln), 5200) * np.exp(-np.linspace(0, 7, ln)) * 0.12
    return x + org + shimmer


def gates_open():
    ln = int(SR * 1.2)
    t = np.arange(ln) / SR
    x = np.zeros(ln)
    for f, st, amp in ((392.0, 0.0, 0.5), (587.33, 0.12, 0.45), (784.0, 0.24, 0.4)):
        p0 = int(st * SR)
        seg = t[:ln - p0]
        bell = (np.sin(2 * np.pi * f * seg) + 0.3 * np.sin(2 * np.pi * f * 2.76 * seg))
        x[p0:] += bell * np.exp(-seg * 3.0) * amp
    thump = np.sin(2 * np.pi * 70 * t) * np.exp(-t * 9) * 0.6
    stone = lp(rng.standard_normal(ln), 500) * np.exp(-t * 7) * 0.3
    return x + thump + stone


def keeper_awake():
    ln = int(SR * 1.2)
    t = np.arange(ln) / SR
    x = np.zeros(ln)
    for f, amp in ((65, 1.0), (69, 0.9), (130, 0.4), (196, 0.2)):
        x += np.sin(2 * np.pi * f * t + np.sin(2 * np.pi * 2.4 * t) * 0.3) * amp
    x = lp(x, 900)
    env = np.ones(ln)
    a = int(SR * 0.2)
    env[:a] = np.linspace(0, 1, a) ** 1.6
    env[-int(SR * 0.35):] *= np.linspace(1, 0, int(SR * 0.35)) ** 1.2
    scrape = lp(rng.standard_normal(ln), 1600) * (0.4 + 0.6 * np.abs(np.sin(t * 9))) * 0.25
    return x * env + scrape * env


if __name__ == '__main__':
    import os
    os.makedirs(os.path.dirname(os.path.abspath(__file__)), exist_ok=True)
    ogg(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'record_new.ogg'), record_new())
    ogg(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'gates_open.ogg'), gates_open())
    ogg(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'keeper_awake.ogg'), keeper_awake(), peak=0.6)
