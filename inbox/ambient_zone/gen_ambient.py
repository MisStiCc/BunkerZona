# -*- coding: utf-8 -*-
# ЗАДАЧА 15: эмбиент-пак Зоны. Процедурный синтез (прецедент sound_pack):
# бесшовные лупы (кроссфейд хвоста в голову), тихий эмбиент, OGG.
import numpy as np
import soundfile as sf

SR = 44100
OUT = r'E:\StalkerRevert\StalkerRevert\inbox\ambient_zone'
rng = np.random.default_rng(20261027)


def lowpass(x, alpha):
    """Однополюсный ФНЧ."""
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def lowpass_fft(x, cutoff_hz):
    """Мягкий ФНЧ через спектр (быстрый для длинных лупов)."""
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / (1.0 + (freqs / cutoff_hz) ** 2.2)
    return np.fft.irfft(X, len(x))


def make_loop(n, gen, fade=2.0):
    """Сгенерировать с запасом и скрестить хвост с головой = бесшовный луп."""
    k = int(SR * fade)
    x = gen(int(n + k))
    head, tail = x[:n], x[n:n + k]
    w = np.linspace(0, 1, k)
    head[-k:] = head[-k:] * (1 - w) + tail * w
    return head


def normalize(x, rms_target, peak=0.6):
    x = x - x.mean()
    r = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (rms_target / r)
    p = np.abs(x).max() + 1e-9
    if p > peak:
        x *= peak / p
    return x


def periodic_lfo(n, freq_hz, phase=0.0):
    """LFO, период которого укладывается в длину лупа (бесшовность)."""
    cycles = max(1, round(freq_hz * n / SR))
    t = np.arange(n) / SR
    return 0.5 + 0.5 * np.sin(2 * np.pi * cycles * t / (n / SR) + phase)


# ---------------------------------------------------------------- ветер
def wind_open(n):
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    body = lowpass_fft(noise, 340)
    # медленное дыхание из двух периодических LFO
    breath = 0.45 + 0.4 * periodic_lfo(n, 1 / 23.0) * periodic_lfo(n, 1 / 7.3, 1.7)
    # редкий тонкий свист: узкая полоса, качается по частоте периодически
    whistle = np.sin(2 * np.pi * (620 + 240 * periodic_lfo(n, 1 / 11.0)) * t)
    whistle = lowpass_fft(whistle * rng.standard_normal(n) * 0.5, 900) * 0.12
    return body * breath + whistle * breath


def wind_forest(n):
    noise = rng.standard_normal(n)
    body = lowpass_fft(noise, 500) * 0.7
    # шелест сухостоя: короткие всплески середины спектра, редкие
    rustle = np.zeros(n)
    n_bursts = max(1, round(n / SR / 3.2))
    for c in range(n_bursts):
        start = int(c * n / n_bursts + rng.integers(0, int(SR * 2)))
        ln = int(SR * rng.uniform(0.5, 1.4))
        if start + ln > n:
            continue
        env = np.exp(-np.linspace(0, 6, ln)) * rng.uniform(0.3, 0.9)
        rustle[start:start + ln] += env * rng.standard_normal(ln) * 0.55
    rustle = lowpass_fft(rustle, 2600)
    sway = 0.6 + 0.4 * periodic_lfo(n, 1 / 15.0, 0.6)
    return body * sway + rustle * sway


# ---------------------------------------------------------------- гейгер
def geiger(n):
    x = np.zeros(n)
    # пуассоновский поток щелчков ~7/с, мягкие, с дребезгом
    n_clicks = int(n / SR * 7)
    for _ in range(n_clicks):
        p = rng.integers(0, n - 60)
        amp = rng.uniform(0.25, 1.0)
        ln = rng.integers(30, 90)
        tick = rng.standard_normal(ln) * np.exp(-np.linspace(0, 9, ln))
        x[p:p + ln] += tick * amp
    x = lowpass_fft(x, 3200) * 0.8
    hum = np.sin(2 * np.pi * 50 * np.arange(n) / SR) * 0.015  # фон сети
    return x + hum


# ---------------------------------------------------------------- ночь
def night_insects(n):
    t = np.arange(n) / SR
    x = np.zeros(n)
    # стрекот: пачки чирпов 4.2-4.8 кГц, ритмические периоды
    n_broods = max(1, round(n / SR / 4.5))
    for c in range(n_broods):
        base = int(c * n / n_broods)
        f = rng.uniform(4100, 4900)
        for k in range(rng.integers(5, 9)):
            p = base + int(k * SR * rng.uniform(0.08, 0.14))
            ln = int(SR * 0.045)
            if p + ln > n:
                break
            env = np.sin(np.linspace(0, np.pi, ln)) ** 1.6
            x[p:p + ln] += np.sin(2 * np.pi * f * t[p:p + ln]) * env * rng.uniform(0.25, 0.5)
    # второй вид, тише и выше, офсет
    f2 = 5600.0
    chirp2 = np.sin(2 * np.pi * f2 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 2.2 * t)) ** 8
    x += chirp2 * 0.05
    bed = lowpass_fft(rng.standard_normal(n), 300) * 0.05  # тёплый ночной фон
    return x + bed


# ---------------------------------------------------------------- дождь
def rain_medium(n):
    # плотный шум капель: высокочастотный плотный + широкополосная подушка
    drops = rng.standard_normal(n)
    drops = lowpass_fft(drops, 5200)
    hiss = lowpass_fft(rng.standard_normal(n), 1400) * 0.8
    bed = lowpass_fft(rng.standard_normal(n), 220) * 0.9
    swell = 0.75 + 0.25 * periodic_lfo(n, 1 / 19.0, 1.1)
    return drops * 0.5 + hiss * 0.35 * swell + bed * 0.5


# ------------------------------------------------------- не-лупы: гром, вой
def thunder_far():
    ln = int(SR * 7.5)
    x = rng.standard_normal(ln)
    x = lowpass_fft(x, 120)
    env = np.zeros(ln)
    a = int(SR * 1.5)
    env[:a] = np.linspace(0, 1, a) ** 2.2          # нарастание
    env[a:] = np.exp(-np.linspace(0, 6.5, ln - a))  # длинный спад
    # второй раскат через 2.2 с, тише
    p = int(SR * 2.2)
    e2 = np.exp(-np.linspace(0, 7.0, ln - p))
    env[p:] += e2 * 0.55
    return x * env


def howl_distant():
    ln = int(SR * 4.0)
    t = np.arange(ln) / SR
    f0 = 340
    # вой: подъём, вибрато, спад; мочим далью
    freq = f0 + 90 * np.sin(np.linspace(0, np.pi, ln)) + 14 * np.sin(2 * np.pi * 5.3 * t)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    x = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
    env = np.zeros(ln)
    a = int(SR * 0.9)
    env[:a] = np.linspace(0, 1, a) ** 1.6
    env[a:] = np.exp(-np.linspace(0, 3.2, ln - a))
    x *= env
    x = lowpass_fft(x, 900) + lowpass_fft(rng.standard_normal(ln), 500) * 0.06 * env
    return x


def ogg(path, x, sr=SR):
    # порционная запись: один большой буфер валит libsndfile (exit 127)
    import os
    x = x.astype(np.float32)
    with sf.SoundFile(path, 'w', samplerate=sr, channels=1,
                      format='OGG', subtype='VORBIS') as f:
        for i in range(0, len(x), sr):
            f.write(x[i:i + sr])
    print(f"{os.path.basename(path):24} {len(x)/sr:5.1f} с, {os.path.getsize(path)//1024} КБ")


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    loops = {
        'wind_open_01.ogg':    (wind_open, 22.0, 0.030),
        'wind_forest_01.ogg':  (wind_forest, 16.0, 0.028),
        'geiger_loop.ogg':     (geiger, 10.0, 0.016),
        'night_insects_01.ogg': (night_insects, 16.0, 0.026),
        'rain_medium_01.ogg':  (rain_medium, 20.0, 0.034),
    }
    for name, (gen, sec, rms) in loops.items():
        n = int(SR * sec)
        ogg(f'{OUT}\\{name}', normalize(make_loop(n, gen), rms))
    ogg(f'{OUT}\\thunder_far_01.ogg', normalize(thunder_far(), 0.075, peak=0.75))
    ogg(f'{OUT}\\howl_distant_01.ogg', normalize(howl_distant(), 0.065, peak=0.6))
    print('готово')
