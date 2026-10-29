# -*- coding: utf-8 -*-
# ЗАДАЧА 23: UI-звуки лабы (deny / build / research / gacha_spin).
import numpy as np
import soundfile as sf

SR = 44100
rng = np.random.default_rng(2026102823)


def lp(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / (1.0 + (f / cutoff) ** 2.0)
    return np.fft.irfft(X, len(x))


def ogg(path, x, peak=0.6):
    import os
    x = x - x.mean()
    p = np.abs(x).max() + 1e-9
    x = (x * (peak / p)).astype(np.float32)
    with sf.SoundFile(path, 'w', samplerate=SR, channels=1, format='OGG', subtype='VORBIS') as f:
        for i in range(0, len(x), SR):
            f.write(x[i:i + SR])
    print(f"{os.path.basename(path):22} {len(x)/SR:5.2f} с")


def deny():
    """0.3 с: глухой двойной тук + короткий бузз-отказ."""
    ln = int(SR * 0.3)
    x = np.zeros(ln)
    for p0 in (0, int(SR * 0.11)):
        n = int(SR * 0.09)
        t = np.arange(n) / SR
        x[p0:p0 + n] += np.sin(2 * np.pi * 110 * t) * np.exp(-t * 26) * 0.8
    t = np.arange(int(SR * 0.14)) / SR
    buzz = np.sign(np.sin(2 * np.pi * 90 * t)) * np.exp(-t * 18) * 0.25
    x[int(SR * 0.04):int(SR * 0.04) + len(buzz)] += lp(buzz, 800) * 0.5
    return x


def build():
    """0.6 с: тяжёлый металлический кланг + оседающий шип."""
    ln = int(SR * 0.6)
    t = np.arange(ln) / SR
    x = np.zeros(ln)
    for f, amp in ((220, 0.8), (587, 0.4), (880, 0.25)):
        x += np.sin(2 * np.pi * f * t) * np.exp(-t * 9) * amp
    clank = lp(rng.standard_normal(ln), 3400) * np.exp(-np.linspace(0, 18, ln)) * 0.6
    hiss = lp(rng.standard_normal(ln), 900) * np.exp(-np.linspace(0, 5, ln)) * 0.3
    thump = np.sin(2 * np.pi * 65 * t) * np.exp(-np.linspace(0, 11, ln)) * 0.9
    return x * 0.5 + clank + hiss + thump


def research():
    """0.9 с: восходящие бипы (3 шт) + подтверждающий аккорд."""
    ln = int(SR * 0.9)
    x = np.zeros(ln)
    for i, f in enumerate((660, 880, 1174.66)):
        p0 = int(i * 0.14 * SR)
        n = int(SR * 0.11)
        t = np.arange(n) / SR
        x[p0:p0 + n] += np.sin(2 * np.pi * f * t) * np.sin(np.linspace(0, np.pi, n)) * 0.6
    p0 = int(0.48 * SR)
    t = np.arange(ln - p0) / SR
    for f in (523.25, 659.25, 783.99):
        x[p0:] += np.sin(2 * np.pi * f * t) * np.exp(-t * 4) * 0.3
    return x


def gacha_spin():
    """1.6 с: тики рулетки ускоряются, питч тиков ползёт вверх."""
    ln = int(SR * 1.6)
    x = np.zeros(ln)
    N = 14
    for i in range(N):
        pos = 0.10 + 1.35 * (i / N) ** 0.55   # тики учащаются к концу
        p0 = int(pos * SR)
        n = int(SR * 0.035)
        t = np.arange(n) / SR
        f = 900 + 900 * (pos / 1.6)
        x[p0:p0 + n] += np.sin(2 * np.pi * f * t) * np.exp(-t * 90) * 0.7
    sheen = lp(rng.standard_normal(ln), 4200) * np.linspace(0, 1, ln) ** 2 * 0.15
    return x + sheen


if __name__ == '__main__':
    import os
    os.makedirs(os.path.dirname(os.path.abspath(__file__)), exist_ok=True)
    base = os.path.dirname(os.path.abspath(__file__))
    ogg(os.path.join(base, 'ui_deny.ogg'), deny(), peak=0.5)
    ogg(os.path.join(base, 'ui_build.ogg'), build())
    ogg(os.path.join(base, 'ui_research.ogg'), research(), peak=0.55)
    ogg(os.path.join(base, 'gacha_spin.ogg'), gacha_spin(), peak=0.55)
