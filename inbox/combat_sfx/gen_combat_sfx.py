# -*- coding: utf-8 -*-
# ЗАДАЧА 21: боевые SFX. Процедурный синтез.
import numpy as np
import soundfile as sf

SR = 44100
OUT = r'E:\StalkerRevert\StalkerRevert\inbox\combat_sfx'
rng = np.random.default_rng(2026102821)


def lp(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / (1.0 + (f / cutoff) ** 2.0)
    return np.fft.irfft(X, len(x))


def hp(x, cutoff):
    return x - lp(x, cutoff)


def norm(x, peak=0.65):
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


def formant_voice(freq, ln, formants, breath=0.25):
    """Голосоподобный тон: пила с формантными резонансами + дыхательный шум."""
    t = np.arange(ln) / SR
    saw = 2.0 * ((freq * t) % 1.0) - 1.0
    x = saw
    out = np.zeros(ln)
    for fc, amp in formants:
        out += lp(x, fc) * amp
    out += lp(rng.standard_normal(ln), formants[0][0] * 2.0) * breath
    return out


def stalker_death(seed):
    """0.9 с: крик с падением высоты -> хрип -> обрыв."""
    r = np.random.default_rng(seed)
    ln = int(SR * 0.9)
    x = np.zeros(ln)
    # крик: высота съезжает 320 -> 140 Гц
    f0 = np.linspace(320, 140, ln) * r.uniform(0.92, 1.08)
    ph = 2 * np.pi * np.cumsum(f0) / SR
    vibr = 1.0 + 0.06 * np.sin(ph * 0.11)
    voice = formant_voice(0, ln, [(700, 1.0), (1220, 0.7), (2400, 0.4)], 0.3)
    voice = lp(voice * vibr, 3600)
    env = np.ones(ln)
    a = int(SR * 0.03)
    env[:a] = np.linspace(0, 1, a)
    cut = int(ln * r.uniform(0.68, 0.82))
    env[cut:] = np.exp(-np.linspace(0, 12, ln - cut))   # резкий обрыв (хрип)
    x += voice * env
    # финальный хрип-выдох
    gasp = hp(rng.standard_normal(ln), 500) * np.exp(-np.linspace(0, 9, ln)) * 0.5
    x += gasp * env
    return x


def anomaly_hit():
    """0.45 с: разряд (шумовой треск) + электрический звон + низкий тук."""
    ln = int(SR * 0.45)
    x = np.zeros(ln)
    crack = hp(rng.standard_normal(ln), 2600) * np.exp(-np.linspace(0, 20, ln))
    x += crack * 0.9
    t = np.arange(ln) / SR
    for f in (2100, 3350):
        x += np.sin(2 * np.pi * f * t) * np.exp(-t * 26) * 0.3
    thump = np.sin(2 * np.pi * 85 * t) * np.exp(-np.linspace(0, 16, ln)) * 0.7
    return x + thump


def wave_horn():
    """1.5 с: зловещий рог призыва волны — два тона с биениями, нарастание."""
    ln = int(SR * 1.5)
    t = np.arange(ln) / SR
    x = np.zeros(ln)
    for f, amp in ((98, 1.0), (103.5, 0.85), (196, 0.35), (147, 0.3)):
        x += np.sin(2 * np.pi * f * t + np.sin(2 * np.pi * 3.1 * t) * 0.15) * amp
    x = lp(x, 1200)
    env = np.ones(ln)
    a = int(SR * 0.25)
    env[:a] = np.linspace(0, 1, a) ** 1.4
    env[-int(SR * 0.4):] *= np.linspace(1, 0, int(SR * 0.4)) ** 1.2
    # рык-подложка
    growl = lp(rng.standard_normal(ln), 180) * 0.7
    return x * env + growl * env * 0.5


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    for i, seed in enumerate((11, 23, 37)):
        ogg(f'{OUT}\\stalker_death_0{i+1}.ogg', norm(stalker_death(seed)))
    ogg(f'{OUT}\\anomaly_hit.ogg', norm(anomaly_hit()))
    ogg(f'{OUT}\\wave_horn.ogg', norm(wave_horn(), peak=0.6))
