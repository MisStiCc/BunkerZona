# -*- coding: utf-8 -*-
# ЗАДАЧА 22: музыкальные лупы босс-боёв (~45 с, бесшовные). Процедурный синтез.
import numpy as np
import soundfile as sf

SR = 44100
BPM = 100
BEAT = 60.0 / BPM
OUT = r'E:\StalkerRevert\StalkerRevert\inbox\boss_music'
rng = np.random.default_rng(2026102822)


def lp(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / (1.0 + (f / cutoff) ** 2.0)
    return np.fft.irfft(X, len(x))


def note(freq, dur, vol=1.0, harmonics=((1, 1.0), (2, 0.4), (3, 0.2)), cutoff=3000, detune=0.3):
    ln = int(SR * dur)
    t = np.arange(ln) / SR
    x = np.zeros(ln)
    for h, amp in harmonics:
        for dt in (-detune, detune):
            x += np.sin(2 * np.pi * freq * h * (1 + dt / 100) * t) * amp * (0.55 if dt else 1.0)
    x = lp(x * vol / 3.0, cutoff)
    return x


def put(buf, x, at):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    if j > i:
        buf[i:j] += x[:j - i]


def make_loop_beats(gen_bar, bars, tail_x=0.0):
    """Луп из тактов: хвост такта кроссфейдится в голову (бесшовность)."""
    bar_ln = int(SR * 4 * BEAT)
    ln = bar_ln * bars
    buf = np.zeros(ln + int(SR * tail_x))
    for b in range(bars):
        gen_bar(buf, b * 4 * BEAT, b)
    head, tail = buf[:ln], buf[ln:]
    k = len(tail)
    if k > 0:
        w = np.linspace(0, 1, k)
        buf[ln - k:ln] = buf[ln - k:ln] * (1 - w) + tail * w
    return buf[:ln]


def norm_loop(x, rms=0.11, peak=0.62):
    x = x - x.mean()
    r = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (rms / r)
    p = np.abs(x).max() + 1e-9
    if p > peak:
        x *= peak / p
    return x


def wrap_fade(x, sec=0.35):
    """Гарантия бесшовности: хвост микса кроссфейдится в голову, хвост обрезается."""
    k = int(SR * sec)
    w = np.linspace(0, 1, k)
    head = x[:k].copy()
    x[:k] = head * w + x[-k:] * (1 - w)
    return x[:-k]


def ogg(path, x):
    import os
    x = x.astype(np.float32)
    with sf.SoundFile(path, 'w', samplerate=SR, channels=1, format='OGG', subtype='VORBIS') as f:
        for i in range(0, len(x), SR):
            f.write(x[i:i + SR])
    print(f"{os.path.basename(path):26} {len(x)/SR:5.1f} с, {os.path.getsize(path)//1024} КБ")


# ------------------------------------------------- Хранитель: пульс страха
NMIN = [220.0, 233.08, 261.63, 293.66]   # A3 Bb3 C4 D4 — тревожно


def keeper_bar(buf, at, b):
    # пульс-бас на каждую долю (сердцебиение)
    for beat in range(4):
        f = NMIN[(b * 4 + beat) % 4] / 2.0
        ln = int(SR * BEAT * 0.9)
        t = np.arange(ln) / SR
        thump = np.sin(2 * np.pi * f * t) * np.exp(-t * 18) * 0.9
        put(buf, thump, at + beat * BEAT)
    # тревожный верх-пульс на полудолях
    for beat in range(4):
        f = NMIN[(b * 4 + beat + 2) % 4] * 2.0
        put(buf, note(f, 0.22, 0.30, ((1, 1.0), (2, 0.3)), 2600), at + beat * BEAT + BEAT / 2)
    # стук перкуссии на 2 и 4
    for beat in (1, 3):
        ln = int(SR * 0.18)
        hit = lp(rng.standard_normal(ln), 700) * np.exp(-np.linspace(0, 14, ln))
        put(buf, hit, at + beat * BEAT)
    # каждые 2 такта — гул-пульс
    if b % 2 == 0:
        ln = int(SR * 4 * BEAT)
        t = np.arange(ln) / SR
        drone = np.sin(2 * np.pi * 55 * t) * (0.4 + 0.3 * np.sin(2 * np.pi * 0.5 * t))
        put(buf, lp(drone, 200) * 0.8, at)


# ------------------------------------------------- Монолит: органный глас
NFIN = [110.0, 164.81, 220.0, 246.94, 329.63]  # A2 E3 A3 B3 E4 — зависший диссонанс


def monolith_bar(buf, at, b):
    # держащийся органный слой (меняется каждый такт)
    for f in NFIN:
        dur = 4 * BEAT + 0.4
        tone = note(f, dur, 0.32, ((1, 1.0), (2, 0.5), (3, 0.28), (4, 0.14), (6, 0.06)), 2200, 0.5)
        env = np.ones(len(tone))
        a = int(SR * 0.6)
        env[:a] = np.linspace(0, 1, a) ** 1.4
        put(buf, tone * env, at)
    # колокол-предупреждение на первой доле каждого такта
    f = [880.0, 659.26, 587.33, 493.88][b % 4]
    ln = int(SR * 1.2)
    t = np.arange(ln) / SR
    bell = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.76 * t)) * np.exp(-t * 4)
    put(buf, bell * 0.4, at)
    # низкий свип-шум раз в 2 такта
    if b % 2 == 1:
        ln = int(SR * 3 * BEAT)
        sw = lp(rng.standard_normal(ln), 500) * np.linspace(0, 1, ln) ** 2
        put(buf, sw * 0.5, at + BEAT)


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    BARS = 45  # 4*100BPM -> 9.6 c/такт-группа... 45 тактов * 2.4 c = 108 c — многовато
    # 45 секунд = ~18.75 тактов по 2.4 с; берём 18 тактов (43.2 с) — ближайший бесшовный
    keeper = make_loop_beats(keeper_bar, 18, tail_x=1.0)
    ogg(f'{OUT}\\keeper_loop.ogg', wrap_fade(norm_loop(keeper, rms=0.10)))
    mono = make_loop_beats(monolith_bar, 18, tail_x=1.0)
    ogg(f'{OUT}\\monolith_finale.ogg', wrap_fade(norm_loop(mono, rms=0.10)))
