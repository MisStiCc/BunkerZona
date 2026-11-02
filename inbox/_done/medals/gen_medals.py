# -*- coding: utf-8 -*-
# ЗАДАЧА 40: 18 медалей Зоны — латунная штамповка с лентой, глиф подвига.
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 256
C = S / 2
BRASS = (196, 156, 76)
BRASS_HI = (240, 204, 120)
BRASS_DK = (132, 100, 46)


def medal(name, glyph_fn):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, 'RGBA')
    for sx, col in ((C - 52, (110, 40, 32)), (C + 8, (70, 58, 34))):
        d.polygon([(sx, 6), (sx + 44, 6), (sx + 44, 84), (sx + 22, 108), (sx, 84)], fill=col + (255,))
        d.line([(sx + 6, 10), (sx + 6, 84)], fill=(0, 0, 0, 70), width=3)
    R = 88
    d.ellipse([C - R, C - R + 10, C + R, C + R + 10], fill=(40, 30, 16, 255))
    d.ellipse([C - R, C - R, C + R, C + R], fill=BRASS + (255,), outline=BRASS_DK + (255,), width=5)
    d.ellipse([C - R + 10, C - R + 10, C + R - 10, C + R - 10], outline=BRASS_DK + (180,), width=3)
    d.ellipse([C - R + 16, C - R + 14, C + R - 20, C + R - 24], outline=(255, 230, 160, 110), width=2)
    g = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    glyph_fn(gd)
    emboss = g.filter(ImageFilter.GaussianBlur(2))
    a = np.array(emboss).astype(np.int16)
    a[..., :3] = np.clip(a[..., :3] * 0.35, 0, 255)
    img.alpha_composite(Image.fromarray(a.astype(np.uint8)), (-2, 3))
    img.alpha_composite(g, (-2, -2))
    arr = np.array(img).astype(np.int16)
    rr = np.random.default_rng(hash(name) % (1 << 30))
    m = rr.random((S, S)) < 0.09
    spot = np.random.default_rng(7).integers(10, 40, (S, S, 1))
    arr[..., 0] = np.where(m & (arr[..., 3] > 100), np.clip(arr[..., 0] - spot[..., 0] * 0.7, 0, 255), arr[..., 0])
    arr[..., 1] = np.where(m & (arr[..., 3] > 100), np.clip(arr[..., 1] - spot[..., 0], 0, 255), arr[..., 1])
    n = rr.integers(-4, 5, (S, S, 1))
    arr[..., :3] = np.clip(arr[..., :3] + n, 0, 255)
    Image.fromarray(arr.astype(np.uint8)).save(name + '.png')


def g_first_run(d):
    d.ellipse([C - 30, C - 34, C + 30, C + 30], fill=BRASS_DK + (255,))
    d.ellipse([C - 22, C - 26, C + 22, C + 22], fill=BRASS + (255,))
    for i in range(3):
        d.ellipse([C - 10 + i * 9, C + 34 + i * 4, C - 2 + i * 9, C + 44 + i * 4], fill=BRASS_DK + (255,))


def g_first_win(d):
    d.line([C, C - 26, C, C + 26], fill=BRASS_DK + (255,), width=9)
    d.line([C - 26, C, C + 26, C], fill=BRASS_DK + (255,), width=9)
    d.line([C, C - 24, C, C + 24], fill=BRASS_HI + (255,), width=5)
    d.line([C - 24, C, C + 24, C], fill=BRASS_HI + (255,), width=5)


def g_veteran(d):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 30 if i % 2 == 0 else 13
        pts.append((C + math.cos(a) * r, C + math.sin(a) * r))
    d.polygon(pts, fill=BRASS_DK + (255,))
    d.polygon([(x - 2, y - 2) for x, y in pts], fill=BRASS_HI + (255,))


def g_champion(d):
    d.ellipse([C - 28, C - 32, C + 28, C + 10], fill=BRASS_DK + (255,))
    d.rectangle([C - 18, C + 6, C + 18, C + 30], fill=BRASS_DK + (255,))
    for ex in (-15, 15):
        d.ellipse([C + ex - 8, C - 18, C + ex + 8, C - 2], fill=(30, 20, 8, 255))
    pts = [(C + 30, C - 30), (C + 12, C - 4), (C + 22, C - 4), (C + 6, C + 26)]
    d.line(pts, fill=(255, 230, 150, 255), width=4)


def g_centurion(d):
    d.ellipse([C - 26, C - 30, C + 26, C + 6], fill=BRASS_DK + (255,))
    for dx in (-14, 0, 14):
        d.ellipse([C + dx - 8, C - 14, C + dx + 8, C + 2], fill=(30, 20, 8, 255))
    for dx in (-9, 9):
        d.polygon([(C + dx - 6, C + 8), (C + dx + 6, C + 8), (C + dx, C + 22)], fill=BRASS_DK + (255,))


def g_floor10(d):
    d.polygon([(C, C - 30), (C + 26, C + 6), (C + 12, C + 6), (C + 12, C + 28),
               (C - 12, C + 28), (C - 12, C + 6), (C - 26, C + 6)], fill=BRASS_DK + (255,))


def g_floor50(d):
    d.rectangle([C - 20, C - 30, C + 20, C + 28], fill=BRASS_DK + (255,))
    d.rectangle([C - 12, C - 20, C + 12, C + 20], fill=BRASS + (255,))
    for y in range(int(C - 24), int(C + 26), 10):
        d.line([C - 18, y, C + 18, y], fill=BRASS_DK + (255,), width=2)


def g_sarcofag(d):
    d.polygon([(C - 16, C - 32), (C + 16, C - 32), (C + 22, C + 30), (C - 22, C + 30)],
              fill=BRASS_DK + (255,))
    for y in (C - 14, C - 2, C + 10):
        d.line([C - 12, y, C + 12, y], fill=BRASS_HI + (255,), width=3)


def g_waves10(d):
    for i in range(2):
        y = C - 8 + i * 18
        d.arc([C - 30, y - 12, C + 6, y + 12], 190, 350, fill=BRASS_DK + (255,), width=5)
        d.arc([C - 6, y - 12, C + 30, y + 12], 190, 350, fill=BRASS_DK + (255,), width=5)


def g_waves30(d):
    for i in range(3):
        y = C - 16 + i * 14
        d.arc([C - 30, y - 10, C + 6, y + 10], 190, 350, fill=BRASS_DK + (255,), width=4)
        d.arc([C - 6, y - 10, C + 30, y + 10], 190, 350, fill=BRASS_DK + (255,), width=4)


def g_chimera(d):
    for dx in (-16, 16):
        d.ellipse([C + dx - 15, C - 26, C + dx + 15, C + 6], fill=BRASS_DK + (255,))
        d.ellipse([C + dx - 7, C - 16, C + dx + 7, C - 2], fill=(30, 20, 8, 255))
    d.polygon([(C - 20, C + 4), (C + 20, C + 4), (C + 10, C + 30), (C - 10, C + 30)],
              fill=BRASS_DK + (255,))


def g_collector(d):
    d.rounded_rectangle([C - 26, C - 20, C + 26, C + 26], radius=4, fill=BRASS_DK + (255,))
    d.rectangle([C - 26, C - 28, C + 26, C - 14], fill=BRASS + (255,))
    d.rectangle([C - 5, C - 8, C + 5, C + 6], fill=(30, 20, 8, 255))


def g_collector34(d):
    k = 0
    for r_ in range(3):
        for c_ in range(3):
            x, y = C - 26 + c_ * 19, C - 24 + r_ * 19
            d.rectangle([x, y, x + 14, y + 14], fill=BRASS_DK + (255,))
            if k < 8:
                d.ellipse([x + 4, y + 4, x + 10, y + 10], fill=BRASS_HI + (255,))
            k += 1


def g_maxstar(d):
    for i, (sx, sy, sr) in enumerate(((C - 24, C + 14, 9), (C, C + 6, 9), (C + 24, C + 14, 9),
                                      (C - 12, C - 8, 9), (C + 12, C - 8, 9))):
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            rr = sr if k % 2 == 0 else sr * 0.45
            pts.append((sx + math.cos(a) * rr, sy + math.sin(a) * rr))
        col = BRASS_HI if i == 4 else BRASS_DK
        d.polygon(pts, fill=col + (255,))


def g_bio100k(d):
    d.ellipse([C - 26, C - 24, C + 26, C + 26], fill=BRASS_DK + (255,))
    d.ellipse([C - 16, C - 14, C + 16, C + 18], fill=BRASS + (255,))
    for (bx, by, br) in ((C - 10, C - 4, 4), (C + 6, C + 2, 3), (C - 2, C + 10, 3)):
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=(30, 20, 8, 255))


def g_arena(d):
    for s in (-1, 1):
        d.line([C - s * 24, C - 24, C + s * 24, C + 24], fill=BRASS_DK + (255,), width=8)
        d.line([C - s * 24, C - 24, C + s * 24, C + 24], fill=BRASS_HI + (255,), width=3)
    d.ellipse([C - 8, C - 8, C + 8, C + 8], fill=BRASS + (255,), outline=BRASS_DK + (255,))


def g_kills(d):
    for s in (-1, 1):
        d.line([C - 22 * s, C - 22, C + 22 * s, C + 22], fill=BRASS_DK + (255,), width=7)
    d.ellipse([C - 9, C - 9, C + 9, C + 9], fill=BRASS + (255,), outline=BRASS_DK + (255,))
    d.ellipse([C - 3, C - 3, C + 3, C + 3], fill=(30, 20, 8, 255))


def g_calendar(d):
    d.rectangle([C - 24, C - 26, C + 24, C + 28], fill=BRASS_DK + (255,))
    d.rectangle([C - 24, C - 26, C + 24, C - 12], fill=BRASS + (255,))
    d.rectangle([C - 6, C + 2, C + 10, C + 16], fill=(30, 20, 8, 255))
    for k in range(2):
        d.line([C - 14 + k * 24, C - 30, C - 14 + k * 24, C - 18], fill=BRASS_DK + (255,), width=4)


MEDALS = [
    ('first_run', g_first_run), ('first_win', g_first_win), ('veteran25', g_veteran),
    ('champion25', g_champion), ('centurion100', g_centurion), ('floor10', g_floor10),
    ('floor50', g_floor50), ('sarcofag', g_sarcofag), ('waves10', g_waves10),
    ('waves30', g_waves30), ('chimera', g_chimera), ('collector20', g_collector),
    ('collector34', g_collector34), ('maxstar', g_maxstar), ('bio100k', g_bio100k),
    ('arena5', g_arena), ('kills100', g_kills), ('week_calendar', g_calendar),
]

if __name__ == '__main__':
    for name, fn in MEDALS:
        medal(name, fn)
        print(name + '.png')
