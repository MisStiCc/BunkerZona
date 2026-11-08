# -*- coding: utf-8 -*-
# Фон панели гильд-магазина (D21): тёмно-фиолетовый градиент + туман +
# рваные верх/низ как у баннеров серии, виньетка. 980x840, для TextureRect.
import os
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\guild_shop_art'
os.makedirs(OUT, exist_ok=True)
W, H = 980, 840

# базовый вертикальный градиент: почти чёрный верх -> тёмно-фиолетовый низ
img = Image.new('RGB', (W, H))
px = img.load()
top = (10, 9, 14)
mid = (26, 18, 40)
bot = (38, 26, 58)
rng = np.random.default_rng(46)
noise = rng.normal(0, 2.2, (H, W, 1))
for y in range(H):
    t = y / (H - 1)
    if t < 0.55:
        k = t / 0.55
        r = top[0] + (mid[0] - top[0]) * k
        g = top[1] + (mid[1] - top[1]) * k
        b = top[2] + (mid[2] - top[2]) * k
    else:
        k = (t - 0.55) / 0.45
        r = mid[0] + (bot[0] - mid[0]) * k
        g = mid[1] + (bot[1] - mid[1]) * k
        b = mid[2] + (bot[2] - mid[2]) * k
    for x in range(W):
        n = noise[y, x, 0]
        px[x, y] = (max(0, min(255, int(r + n))), max(0, min(255, int(g + n))),
                    max(0, min(255, int(b + n))))
img = img.convert('RGBA')

# туманные пятна (мягкие эллипсы, фиолетовые и янтарный отсвет сверху)
def blob(layer_draw, cx, cy, rx, ry, color, alpha):
    steps = 14
    for i in range(steps, 0, -1):
        k = i / steps
        a = int(alpha * (1 - k) ** 1.5)
        layer_draw.ellipse([cx - rx * k, cy - ry * k, cx + rx * k, cy + ry * k],
                           fill=color + (a,))

fog = Image.new('RGBA', (W, H), (0, 0, 0, 0))
fd = ImageDraw.Draw(fog)
blob(fd, 180, 210, 320, 180, (90, 60, 140), 70)
blob(fd, 760, 340, 300, 170, (70, 50, 110), 60)
blob(fd, 490, 700, 380, 190, (120, 70, 150), 55)
blob(fd, 490, 90, 430, 110, (190, 130, 60), 38)
fog = fog.filter(ImageFilter.GaussianBlur(60))
img.alpha_composite(fog)

# силуэт Монолита-обелиска в watermark по центру (серия гильд-арта)
wm = Image.new('RGBA', (W, H), (0, 0, 0, 0))
wd = ImageDraw.Draw(wm)
cx, base_y = W // 2, H // 2 + 40
# ступенчатый постамент + игла
for i, (w2, h2) in enumerate([(340, 26), (260, 26), (190, 26)]):
    y0 = base_y - i * 26
    wd.polygon([(cx - w2 // 2, y0), (cx + w2 // 2, y0),
                (cx + w2 // 2 - 14, y0 - h2), (cx - w2 // 2 + 14, y0 - h2)],
               fill=(255, 255, 255, 9))
needle_top = base_y - 3 * 26 - 300
wd.polygon([(cx - 62, base_y - 78), (cx + 62, base_y - 78),
            (cx + 26, needle_top), (cx, needle_top - 40), (cx - 26, needle_top)],
           fill=(255, 255, 255, 12))
# руны-чёрточки на игле
for k in range(6):
    yy = base_y - 110 - k * 42
    ww = 30 - k * 3
    wd.rectangle([cx - ww // 2, yy, cx + ww // 2, yy + 5], fill=(255, 255, 255, 8))
wm = wm.filter(ImageFilter.GaussianBlur(5))
img.alpha_composite(wm)

# виньетка
vig = Image.new('L', (W, H), 0)
dv = ImageDraw.Draw(vig)
dv.rectangle([0, 0, W, H], fill=110)
dv.ellipse([-W * 0.3, -H * 0.3, W * 1.3, H * 1.3], fill=0)
vig = vig.filter(ImageFilter.GaussianBlur(70))
dark = Image.new('RGBA', (W, H), (0, 0, 0, 255))
dark.putalpha(vig)
img.alpha_composite(dark)

# рваные кромки сверху/снизу (как у баннеров ceremony): чёрные треугольники
edge = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ed = ImageDraw.Draw(edge)
r2 = np.random.default_rng(77)
x = 0
while x < W:
    w2 = int(r2.integers(28, 70))
    h2 = int(r2.integers(8, 26))
    ed.polygon([(x, 0), (x + w2, 0), (x + w2 // 2, h2)], fill=(6, 5, 8, 255))
    hb = int(r2.integers(10, 30))
    ed.polygon([(x, H), (x + w2, H), (x + w2 // 2, H - hb)], fill=(6, 5, 8, 255))
    x += w2
img.alpha_composite(edge)

img.convert('RGB').save(os.path.join(OUT, 'guild_shop_bg.png'))
print('BG OK', os.path.join(OUT, 'guild_shop_bg.png'))
