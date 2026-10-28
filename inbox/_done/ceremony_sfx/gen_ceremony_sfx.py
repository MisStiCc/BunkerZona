# -*- coding: utf-8 -*-
# ЗАДАЧА 20: звуки церемоний финала. Процедурный синтез (прецедент
# sound_pack/gen_ambient). Пики < 0.7. OGG порциями (libsndfile не любит
# цельные большие буферы).
import numpy as np
import soundfile as sf

SR = 44100
OUT = r'E:\StalkerRevert\StalkerRevert\inbox\ceremony_sfx'
rng = np.random.default_rng(2026102820)


def lp(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / (1.0 + (f / cutoff) ** 2.0)
    return np.fft.irfft(X, len(x))


def ogg(path, x, peak=0.65):
    import os
    x = x - x.mean()
    p = np.abs(x).max() + 1e-9
    x = x * (peak / p)
    x = x.astype(np.float32)
    with sf.SoundFile(path, 'w', samplerate=SR, channels=1, format='OGG', subtype='VORBIS') as f:
        for i in range(0, len(x), SR):
            f.write(x[i:i + SR])
    print(f"{os.path.basename(path):24} {len(x)/SR:5.2f} с, пик {np.abs(x).max():.2f}, {os.path.getsize(path)//1024} КБ")


def organ_tone(freq, ln, detune=0.4, brightness=1.0):
    """Тёмный органный/хоровой тон: сумма гармоник с лёгким расстроем."""
    t = np.arange(ln) / SR
    x = np.zeros(ln)
    for h, amp in ((1, 1.0), (2, 0.55), (3, 0.34), (4, 0.16), (6, 0.07), (8, 0.045)):
        for dt in (-detune, 0.0, detune):
            f = freq * h * (1.0 + dt / 100.0)
            x += np.sin(2 * np.pi * f * t) * amp * (0.6 if dt else 1.0)
    x *= brightness / 3.4
    return lp(x, 3400)


def ceremony_win():
    """1.9 с стингер: удар (слэм баннера) -> мажорный органный аккорд D
    с переходом на A, тёмный «хор Зоны», хвост."""
    ln = int(SR * 1.9)
    x = np.zeros(ln)
    # слэм: глухой удар в нулевой точке
    thump = np.sin(2 * np.pi * 58 * np.arange(int(SR * 0.4)) / SR) * np.exp(-np.linspace(0, 10, int(SR * 0.4)))
    x[:len(thump)] += thump * 0.9
    # аккорд 1: D (D3 A3 D4 F#4), аккорд 2 (с 0.55 с): A (A3 D4 F#4 A4)
    ch1 = [146.83, 220.0, 293.66, 369.99]
    ch2 = [220.0, 293.66, 369.99, 440.0]
    t2 = int(SR * 0.55)
    seg = ln - t2
    env = np.ones(ln)
    a = int(SR * 0.12)
    env[:a] = np.linspace(0, 1, a) ** 1.5
    rel = int(SR * 0.55)
    env[-rel:] *= np.linspace(1, 0, rel) ** 1.4
    for f in ch1:
        x += organ_tone(f, ln) * env * 0.55
    env2 = np.ones(seg)
    env2[:int(SR * 0.08)] = np.linspace(0, 1, int(SR * 0.08)) ** 1.5
    env2[-rel:] *= np.linspace(1, 0, rel if rel < seg else seg) ** 1.4
    for f in ch2:
        x[t2:] += organ_tone(f, seg) * env2 * 0.6
    # воздушный верх на втором аккорде
    air = lp(rng.standard_normal(ln), 2600) * np.exp(-np.linspace(0, 5, ln)) * 0.05
    return x + air


def ceremony_star():
    """0.3 с «дзынь»: чистый синус с МЯГКОЙ атакой (без щелчка — сэмпл
    будет питчиться 1.00/1.15/1.30) + слабая октава."""
    ln = int(SR * 0.3)
    t = np.arange(ln) / SR
    f = 1568.0  # G6
    x = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(2 * np.pi * f * 2 * t)
    env = np.ones(ln)
    atk = int(SR * 0.012)                    # мягкая атака 12 мс
    env[:atk] = np.linspace(0, 1, atk)
    env *= np.exp(-t * 14.0)
    return x * env


def portal_woosh():
    """2.0 с перехода: нарастание гула (открывающийся фильтр + свип 80→160 Гц)
    до 1.2 с, затем спад в «хлопок» тишины."""
    ln = int(SR * 2.0)
    t = np.arange(ln) / SR
    noise = rng.standard_normal(ln)
    # фильтр открывается до 1.2 с и закрывается
    swell = np.clip(t / 1.2, 0, 1) ** 1.6
    fall = np.where(t < 1.2, 1.0, np.exp(-(t - 1.2) * 5.0))
    parts = []
    for cutoff, amp in ((300, 0.8), (900, 0.5), (1900, 0.3)):
        parts.append(lp(noise, cutoff) * amp)
    x = sum(p * swell * fall for p in parts)
    # низкий свип
    f0 = 80 + (160 - 80) * np.clip(t / 1.2, 0, 1)
    ph = 2 * np.pi * np.cumsum(f0) / SR
    x += np.sin(ph) * swell * fall * 0.8
    # «хлопок» на спаде
    p1 = int(1.25 * SR)
    cl = rng.standard_normal(ln - p1) * np.exp(-np.linspace(0, 22, ln - p1))
    x[p1:] += lp(cl, 900) * 0.5
    return x


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    ogg(f'{OUT}\\ceremony_win.ogg', ceremony_win())
    ogg(f'{OUT}\\ceremony_star.ogg', ceremony_star(), peak=0.5)
    ogg(f'{OUT}\\portal_woosh.ogg', portal_woosh())
