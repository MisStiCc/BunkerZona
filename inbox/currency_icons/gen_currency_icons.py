# -*- coding: utf-8 -*-
# ЗАДАЧА 22: иконки валют и ресурсов 64px, стиль mode_ui (графит/золото/болото).
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\currency_icons'
S = 64
rng = np.random.default_rng(22)

GOLD = (232, 179, 57)
GOLD_HI = (255, 208, 97)
SWAMP = (110, 150, 90)
CREAM = (237, 230, 196)
DARK = (18, 20, 16)


def plate(glyph_fn):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # тёмная плашка со срезанными углами
    cut = 12
    pts = [(cut, 2), (S - cut, 2), (S - 2, cut), (S - 2, S - cut), (S - cut, S - 2),
           (cut, S - 2), (2, S - cut), (2, cut), (cut, 2)]
    d.polygon(pts, fill=(26, 29, 24, 245))
    d.line(pts, fill=(87, 107, 79, 220), width=2)
    glyph_fn(d, img)
    # лёгкое зерно
    a = np.array(img).astype(np.int16)
    n = np.random.default_rng(rng.integers(1 << 30)).integers(-3, 4, (S, S, 1))
    a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def glow(d, cx, cy, r, color, alpha):
    for k, rr in enumerate((r, r * 0.7, r * 0.45)):
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (int(alpha * (0.3, 0.5, 0.8)[k]),))


def g_biomass(d, img):
    """Биомасса: комок с пузырями и свечением трещин."""
    glow(d, 32, 34, 26, (110, 190, 80), 60)
    d.ellipse([14, 18, 50, 52], fill=(66, 92, 48, 255), outline=(30, 44, 24, 255))
    d.ellipse([20, 24, 44, 44], fill=(88, 122, 62, 255))
    for (bx, by, br) in [(26, 30, 4), (38, 28, 3), (34, 40, 5), (24, 42, 3)]:
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=(46, 66, 34, 255))
        d.ellipse([bx - br + 1, by - br + 1, bx + 1, by + 1], fill=(150, 210, 110, 255))
    d.line([22, 34, 30, 30], fill=(160, 220, 120, 200), width=2)


def g_pull(d, img):
    """Крутка: рубашка карты с золотым трефойлом."""
    glow(d, 32, 32, 24, GOLD, 50)
    d.polygon([(22, 10), (42, 10), (46, 14), (46, 52), (42, 56), (22, 56), (18, 52), (18, 14)],
              fill=(30, 34, 28, 255), outline=GOLD + (255,))
    d.arc([24, 20, 40, 36], 0, 360, fill=SWAMP + (200,), width=2)
    cx, cy = 32, 30
    for i in range(3):
        a0 = 90 + i * 120 - 22
        d.pieslice([cx - 9, cy - 9, cx + 9, cy + 9], a0, a0 + 44, fill=GOLD + (240,))
    d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=GOLD_HI + (255,))
    d.line([22, 48, 42, 48], fill=GOLD + (140,), width=2)


def g_energy(d, img):
    """Энергия Монолита: кристалл с молнией."""
    glow(d, 32, 32, 26, (255, 200, 90), 60)
    d.polygon([(32, 8), (46, 24), (42, 54), (22, 54), (18, 24)],
              fill=(52, 58, 40, 255), outline=GOLD + (255,))
    d.polygon([(32, 8), (46, 24), (32, 28)], fill=(80, 88, 60, 255))
    d.line([34, 18, 26, 34], fill=GOLD_HI + (255,), width=3)
    d.line([26, 34, 34, 34], fill=GOLD_HI + (255,), width=3)
    d.line([34, 34, 28, 46], fill=GOLD_HI + (220,), width=3)


def g_star(d, img):
    """Звезда башни."""
    glow(d, 32, 32, 26, GOLD, 70)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 24 if i % 2 == 0 else 10.5
        pts.append((32 + math.cos(a) * r, 33 + math.sin(a) * r))
    d.polygon(pts, fill=GOLD + (255,), outline=(120, 88, 20, 255))
    d.polygon([(32, 33), (pts[1][0], pts[1][1]), (pts[3][0], pts[3][1])], fill=GOLD_HI + (230,))


def g_sp(d, img):
    """СП сезона: лавровая медаль."""
    glow(d, 32, 34, 24, GOLD, 55)
    d.ellipse([16, 12, 48, 44], fill=(58, 52, 24, 255), outline=GOLD + (255,))
    d.ellipse([21, 17, 43, 39], outline=GOLD + (160,), width=2)
    d.text((32, 28), 'СП', fill=CREAM + (255,), anchor='mm')
    for dx in (-1, 1):
        for i in range(4):
            x = 32 + dx * (16 - i * 3)
            y = 44 + i * 4
            d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=SWAMP + (230,))


def g_ring(d, img):
    """Кольцо кампании."""
    glow(d, 32, 32, 24, (255, 170, 60), 55)
    d.ellipse([14, 14, 50, 50], outline=(212, 140, 60, 255), width=7)
    d.ellipse([14, 14, 50, 50], outline=(255, 210, 130, 200), width=2)
    d.arc([14, 14, 50, 50], 200, 320, fill=(255, 235, 180, 230), width=3)
    for a in (110, 290):
        ax = 32 + math.cos(math.radians(a)) * 18
        ay = 32 + math.sin(math.radians(a)) * 18
        d.ellipse([ax - 2, ay - 2, ax + 2, ay + 2], fill=GOLD_HI + (255,))


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [('icon_biomass', g_biomass), ('icon_pull', g_pull), ('icon_energy', g_energy),
                     ('icon_star', g_star), ('icon_sp', g_sp), ('icon_ring', g_ring)]:
        plate(fn).save(f'{OUT}\\{name}.png')
        print(name + '.png')
