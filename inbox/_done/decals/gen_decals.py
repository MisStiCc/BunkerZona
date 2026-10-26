# -*- coding: utf-8 -*-
# ЗАДАЧА 12: настоящие декали грязи для стен, assets/decals/ (создаётся).
# 256x256 RGBA, прозрачный фон, мягкие края, зерно, приглушённая гамма.
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r'E:\StalkerRevert\StalkerRevert\assets\decals'
S = 256
rng = random.Random(2026102621)

RUST = (138, 74, 38)
RUST_DK = (92, 47, 24)
DARK = (20, 20, 16)
MOSS = (74, 92, 51)
MOSS_L = (93, 112, 64)
PAINT_W = (207, 202, 187)
PAINT_Y = (217, 177, 59)
SCRATCH_L = (150, 146, 136)


def canvas():
    return Image.new('RGBA', (S, S), (0, 0, 0, 0))


def grain(img, amount=5):
    arr = np.array(img).astype(np.int16)
    n = np.random.default_rng(rng.randrange(1 << 30)).integers(
        -amount, amount + 1, (S, S, 1))
    arr[..., :3] = np.clip(arr[..., :3] + n, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


def soft_edges(img, margin=14, power=1.6):
    """Альфа затухает к краям, чтобы декаль не резалась об рамку."""
    a = np.array(img.getchannel('A')).astype(np.float32)
    yy, xx = np.mgrid[0:S, 0:S]
    d = np.minimum.reduce([xx, yy, S - 1 - xx, S - 1 - yy]).astype(np.float32)
    f = np.clip(d / margin, 0, 1) ** power
    a *= f
    img.putalpha(Image.fromarray(a.astype(np.uint8)))
    return img


def blob(d, cx, cy, r, color, alpha):
    """Клякса: круг + мелкие спутники."""
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (alpha,))
    for _ in range(9):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(r * 0.6, r * 1.25)
        sr = rng.uniform(r * 0.12, r * 0.3)
        sx, sy = cx + math.cos(a) * rr, cy + math.sin(a) * rr
        d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=color + (int(alpha * rng.uniform(0.5, 0.9)),))


def crack(seed):
    rng = random.Random(seed)
    img = canvas()
    d = ImageDraw.Draw(img)
    # главный разлом сверху вниз с ветвлением
    def walk(x, y, ang, length, width, depth):
        steps = int(length / 6)
        for i in range(steps):
            nx = x + math.cos(ang) * 6
            ny = y + math.sin(ang) * 6
            w = max(1, int(width * (1 - i / steps)))
            d.line([x, y, nx, ny], fill=DARK + (235,), width=w)
            if w > 1:  # светлый скол вдоль
                d.line([x + 1, y, nx + 1, ny], fill=SCRATCH_L + (70,), width=1)
            x, y = nx, ny
            ang += rng.uniform(-0.35, 0.35)
            if depth > 0 and rng.random() < 0.05:
                walk(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1),
                     length * rng.uniform(0.25, 0.5), width * 0.6, depth - 1)
    walk(rng.randint(80, 176), 10, math.pi / 2 + rng.uniform(-0.3, 0.3),
         rng.randint(150, 220), rng.randint(5, 8), 2)
    return img


def rust_streak(seed, wide):
    rng = random.Random(seed)
    img = canvas()
    d = ImageDraw.Draw(img)
    n = 3 if wide else 5
    for i in range(n):
        x = 30 + i * (S - 60) / max(1, n - 1) + rng.uniform(-10, 10)
        length = rng.uniform(0.88, 0.98) * S
        w = rng.uniform(7, 18 if wide else 10)
        col = RUST if rng.random() < 0.5 else RUST_DK
        for y in range(int(length)):
            k = y / length
            ww = w * (0.55 + 0.5 * k)
            a = int(210 * (1 - k * 0.8))
            xx = x + math.sin(y * 0.05 + i) * 2
            d.ellipse([xx - ww / 2, y, xx + ww / 2, y + 6], fill=col + (a,))
        # капля-натёк на конце
        d.ellipse([x - w * 0.45, length - 6, x + w * 0.45, length + w * 0.9], fill=col + (150,))
        # боковые короткие потёчки от точки старта
        for _ in range(3):
            bx = x + rng.uniform(-14, 14)
            bl = rng.uniform(30, 90)
            d.line([bx, 8, bx + rng.uniform(-2, 2), 8 + bl], fill=col + (110,), width=3)
    return img.filter(ImageFilter.GaussianBlur(1.2))


def stain(seed, color, alpha, oil=False):
    rng = random.Random(seed)
    img = canvas()
    d = ImageDraw.Draw(img)
    cx, cy = rng.randint(90, 166), rng.randint(90, 166)
    blob(d, cx, cy, rng.randint(52, 74), color, alpha)
    if oil:  # радужный отлив по кромке
        d = ImageDraw.Draw(img, 'RGBA')
        for a0 in range(0, 360, 24):
            a = math.radians(a0)
            rr = rng.randint(58, 76)
            d.arc([cx - rr, cy - rr, cx + rr, cy + rr], a0, a0 + 14,
                  fill=(90, 130, 120, 90), width=3)
    return img.filter(ImageFilter.GaussianBlur(3))


def moss(seed):
    rng = random.Random(seed)
    img = canvas()
    d = ImageDraw.Draw(img)
    cx, cy = S // 2, S // 2
    for _ in range(rng.randint(240, 330)):
        a = rng.uniform(0, math.tau)
        rr = abs(rng.gauss(0, 42))
        x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.8
        sr = rng.uniform(2, 7)
        col = MOSS if rng.random() < 0.7 else MOSS_L
        d.ellipse([x - sr, y - sr, x + sr, y + sr],
                  fill=col + (rng.randint(90, 190),))
    return img.filter(ImageFilter.GaussianBlur(1.4))


def sign_radiation():
    img = canvas()
    d = ImageDraw.Draw(img)
    cx, cy = S // 2, S // 2 - 4
    R = 86
    for i in range(3):
        a0 = 90 + i * 120 - 22
        d.pieslice([cx - R, cy - R, cx + R, cy + R], a0, a0 + 44, fill=PAINT_Y + (215,))
    d.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=PAINT_Y + (215,))
    # обводка-трафарат и потёртости
    d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=DARK + (120,), width=3)
    arr = np.array(img)
    m = np.random.default_rng(5).random((S, S)) < 0.10
    arr[m, 3] = (arr[m, 3] * 0.25).astype(np.uint8)
    return Image.fromarray(arr).rotate(4, center=(cx, cy), resample=Image.BICUBIC)


def paint_mark(kind):
    img = canvas()
    d = ImageDraw.Draw(img)
    col = PAINT_W if kind == 'x' else PAINT_Y
    wdt = 34
    if kind == 'x':
        d.line([46, 46, 210, 210], fill=col + (215,), width=wdt)
        d.line([46, 210, 210, 46], fill=col + (215,), width=wdt)
    else:
        d.line([36, 128, 190, 128], fill=col + (220,), width=wdt)
        d.polygon([(190, 96), (226, 128), (190, 160)], fill=col + (220,))
    # потёки от краёв
    for _ in range(6):
        x = rng.randint(50, 200)
        y = rng.randint(60, 190)
        ln = rng.randint(20, 70)
        d.line([x, y, x, y + ln], fill=col + (110,), width=rng.randint(3, 6))
    # неровности: выедаем шумом
    arr = np.array(img)
    m = np.random.default_rng(9).random((S, S)) < 0.14
    arr[m, 3] = (arr[m, 3] * 0.3).astype(np.uint8)
    return Image.fromarray(arr).filter(ImageFilter.GaussianBlur(0.8))


def bullet_holes(seed):
    rng = random.Random(seed)
    img = canvas()
    d = ImageDraw.Draw(img)
    for _ in range(rng.randint(2, 3)):
        cx, cy = rng.randint(60, 196), rng.randint(60, 196)
        r = rng.randint(9, 15)
        # сколы
        blob(d, cx, cy, r * 2.1, (120, 116, 106), 70)
        # воронка
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(16, 15, 13, 245))
        d.ellipse([cx - r + 3, cy - r + 3, cx + r - 2, cy + r - 2], fill=(5, 5, 4, 255))
        # светлый верхний ободок
        d.arc([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], 200, 340,
              fill=(170, 165, 150, 160), width=2)
    return img.filter(ImageFilter.GaussianBlur(0.7))


def hazard():
    img = canvas()
    d = ImageDraw.Draw(img)
    step = 46
    for x in range(-S, S * 2, step):
        d.polygon([(x, S), (x + step // 2, S), (x + step // 2 + S, 0), (x + S, 0)],
                  fill=PAINT_Y + (165,))
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    arr = np.array(img)
    m = np.random.default_rng(3).random((S, S)) < 0.08  # лёгкая потёртость, полосы читаются
    arr[m, 3] = (arr[m, 3] * 0.4).astype(np.uint8)
    return Image.fromarray(arr)


def make(name, img):
    img = grain(img)
    img = soft_edges(img)
    img.save(f'{OUT}\\{name}.png')
    print(name)


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    make('crack_01', crack(11))
    make('crack_02', crack(22))
    make('crack_03', crack(33))
    make('rust_streak_01', rust_streak(1, wide=False))
    make('rust_streak_02', rust_streak(2, wide=True))
    make('stain_dark_01', stain(4, DARK, 175))
    make('stain_dark_02', stain(5, (26, 24, 18), 160))
    make('stain_oil_01', stain(6, (12, 12, 14), 205, oil=True))
    make('moss_patch_01', moss(7))
    make('moss_patch_02', moss(8))
    make('sign_radiation', sign_radiation())
    make('paint_x_white', paint_mark('x'))
    make('paint_arrow_yellow', paint_mark('arrow'))
    make('bullet_holes_01', bullet_holes(12))
    make('bullet_holes_02', bullet_holes(13))
    make('hazard_stripes', hazard())
    print('готово')
