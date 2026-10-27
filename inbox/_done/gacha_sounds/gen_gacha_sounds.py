# -*- coding: utf-8 -*-
# ЗАДАЧА 18: звуки гачи и вскрытия карт. Процедурный синтез.
import numpy as np
import soundfile as sf

SR = 44100
OUT = r'E:\StalkerRevert\StalkerRevert\inbox\gacha_sounds'
rng = np.random.default_rng(2026102718)


def lp(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / (1.0 + (f / cutoff) ** 2.0)
    return np.fft.irfft(X, len(x))


def hp(x, cutoff):
    return x - lp(x, cutoff)


def norm(x, peak=0.8):
    x = x - x.mean()
    p = np.abs(x).max() + 1e-9
    return x * (peak / p)


def ogg(path, x):
    import os
    x = x.astype(np.float32)
    with sf.SoundFile(path, 'w', samplerate=SR, channels=1, format='OGG', subtype='VORBIS') as f:
        for i in range(0, len(x), SR):
            f.write(x[i:i + SR])
    print(f"{os.path.basename(path):24} {len(x)/SR:5.2f} с, {os.path.getsize(path)//1024} КБ")


def whoosh():
    """0.6 с взмах карты: шум с формантой, скользящей вверх."""
    ln = int(SR * 0.6)
    n = rng.standard_normal(ln)
    n = lp(n, 2600)
    env = np.sin(np.linspace(0, np.pi, ln)) ** 1.6
    # «свист»: частота среза полосы ползёт 600->2400
    t = np.arange(ln) / SR
    band = hp(lp(n, 2400), 600)
    return n * env * 0.6 + band * env * 0.5


def flip():
    """0.25 с шорох переворота: два коротких шершавых касания."""
    ln = int(SR * 0.25)
    x = np.zeros(ln)
    for p0 in (int(SR * 0.02), int(SR * 0.11)):
        seg = rng.standard_normal(int(SR * 0.07)) * np.exp(-np.linspace(0, 7, int(SR * 0.07)))
        x[p0:p0 + len(seg)] += hp(seg, 1800) * 0.8
    return x


def reveal(rarity):
    """Звон вскрытия: аккорд из 2-3 синусов + блеск, богатство растёт с редкостью."""
    dur = {'common': 0.7, 'rare': 1.0, 'epic': 1.3, 'legendary': 1.8}[rarity]
    ln = int(SR * dur)
    t = np.arange(ln) / SR
    notes = {
        'common':    [523.25, 659.25],                     # C5 E5
        'rare':      [523.25, 659.25, 783.99],             # C5 E5 G5
        'epic':      [587.33, 739.99, 880.0],              # D5 F#5 A5
        'legendary': [523.25, 659.25, 783.99, 1046.5],     # мажорный октавный
    }[rarity]
    x = np.zeros(ln)
    for i, f in enumerate(notes):
        start = int(i * SR * {'common': 0.05, 'rare': 0.07, 'epic': 0.09, 'legendary': 0.12}[rarity])
        seg = t[:ln - start]
        tone = (np.sin(2 * np.pi * f * seg) + 0.35 * np.sin(2 * np.pi * f * 2 * seg)
                + 0.12 * np.sin(2 * np.pi * f * 3 * seg))
        env = np.exp(-np.linspace(0, 4.5, len(seg)))
        # лёгкое вибрато-дрожание для высоких редкостей
        if rarity in ('epic', 'legendary'):
            tone *= 0.9 + 0.1 * np.sin(2 * np.pi * 6.5 * seg)
        x[start:] += tone * env * (1.0 - i * 0.12)
    # блеск: колокольчики на легендарке
    if rarity == 'legendary':
        for k, st in enumerate((0.5, 0.8, 1.1, 1.45)):
            p0 = int(st * SR)
            f = 1568 * (2 ** (k % 2 / 12))
            seg = t[:ln - p0]
            bell = np.sin(2 * np.pi * f * seg) * np.exp(-np.linspace(0, 6, len(seg)))
            x[p0:] += bell * 0.3
    return x


def ribbon_pop():
    """0.3 с плашки: короткий «поп» + щелчок."""
    ln = int(SR * 0.3)
    x = np.zeros(ln)
    body = np.sin(2 * np.pi * 240 * np.arange(ln) / SR) * np.exp(-np.linspace(0, 16, ln))
    click = hp(rng.standard_normal(ln), 2400) * np.exp(-np.linspace(0, 30, ln))
    return body * 0.8 + click * 0.5


def burst_sparks():
    """1.2 с взрыва искр: россыпь высоких звонких тиков + шумовой хвост."""
    ln = int(SR * 1.2)
    x = np.zeros(ln)
    for _ in range(34):
        p0 = int(rng.uniform(0, 0.7) * SR)
        f = rng.uniform(2200, 5200)
        seg = np.arange(ln - p0) / SR
        tick = np.sin(2 * np.pi * f * seg) * np.exp(-seg * rng.uniform(18, 42))
        x[p0:] += tick * rng.uniform(0.1, 0.32)
    tail = hp(rng.standard_normal(ln), 3000) * np.exp(-np.linspace(0, 6, ln)) * 0.35
    boom = np.sin(2 * np.pi * 90 * np.arange(ln) / SR) * np.exp(-np.linspace(0, 12, ln)) * 0.7
    return x + tail + boom


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    ogg(f'{OUT}\\card_whoosh.ogg', norm(whoosh()))
    ogg(f'{OUT}\\card_flip.ogg', norm(flip()))
    for r in ('common', 'rare', 'epic', 'legendary'):
        ogg(f'{OUT}\\reveal_{r}.ogg', norm(reveal(r), peak=0.75))
    ogg(f'{OUT}\\ribbon_pop.ogg', norm(ribbon_pop()))
    ogg(f'{OUT}\\burst_sparks.ogg', norm(burst_sparks(), peak=0.85))
