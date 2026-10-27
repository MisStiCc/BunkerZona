# -*- coding: utf-8 -*-
# ЗАДАЧА 17: звук Выброса. Процедурный синтез (прецедент sound_pack/ambient).
import numpy as np
import soundfile as sf

SR = 44100
OUT = r'E:\StalkerRevert\StalkerRevert\inbox\emission_sound'
rng = np.random.default_rng(2026102717)


def lowpass_fft(x, cutoff_hz):
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / (1.0 + (freqs / cutoff_hz) ** 2.0)
    return np.fft.irfft(X, len(x))


def normalize(x, peak=0.9):
    x = x - x.mean()
    p = np.abs(x).max() + 1e-9
    return x * (peak / p)


def ogg(path, x):
    import os
    x = x.astype(np.float32)
    with sf.SoundFile(path, 'w', samplerate=SR, channels=1, format='OGG', subtype='VORBIS') as f:
        for i in range(0, len(x), SR):
            f.write(x[i:i + SR])
    print(f"{os.path.basename(path):26} {len(x)/SR:5.1f} с, {os.path.getsize(path)//1024} КБ")


def rumble():
    """7 с гула катастрофы: нарастание 1.5 с, плато, спад 2 с (форма set_intensity)."""
    ln = int(SR * 7.0)
    t = np.arange(ln) / SR
    # три слоя низкого рокота
    layer1 = lowpass_fft(rng.standard_normal(ln), 90)
    layer2 = lowpass_fft(rng.standard_normal(ln), 45) * 1.3
    # подрагивающий тон 38 Гц с биениями
    beat = np.sin(2 * np.pi * 38 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 2.7 * t))
    x = layer1 + layer2 + beat * 0.5
    # огибающая: рост 1.5с -> плато -> спад 2с (хвост общий)
    a = int(SR * 1.5)
    env = np.ones(ln)
    env[:a] = np.linspace(0, 1, a) ** 1.8
    d = int(SR * 2.0)
    env[-d:] = np.linspace(1, 0, d) ** 1.5
    # рябь на плато (дрожь земли)
    env *= 0.82 + 0.18 * np.abs(lowpass_fft(rng.standard_normal(ln), 6)) / 0.02
    x *= env
    # ст интересно: добавить «воздух» верхами на пике
    air = lowpass_fft(rng.standard_normal(ln), 900) * (env ** 2) * 0.25
    return x + air


def burst():
    """0.8 с удара-всплеска на старт волны: щелчок + шумовой хвост."""
    ln = int(SR * 0.8)
    x = rng.standard_normal(ln)
    x = lowpass_fft(x, 1400)
    env = np.exp(-np.linspace(0, 9, ln))
    thump = np.sin(2 * np.pi * 55 * np.arange(ln) / SR) * np.exp(-np.linspace(0, 14, ln)) * 1.2
    return x * env + thump * env


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    ogg(f'{OUT}\\emission_rumble.ogg', normalize(rumble(), peak=0.85))
    ogg(f'{OUT}\\emission_burst.ogg', normalize(burst(), peak=0.9))
