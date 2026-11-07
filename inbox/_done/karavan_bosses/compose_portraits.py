# -*- coding: utf-8 -*-
# ЗАДАЧА 46а: композ портретов 612px (тёплый градиент + виньетка + рамка)
# и 46б: 10 иконок ярусов башни 128px (плита pack_icons + глиф + римская цифра).
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, 'portrait_raw')
OUT = HERE
TIERS_DIR = r'E:\StalkerRevert\StalkerRevert\inbox\tier_icons'
os.makedirs(TIERS_DIR, exist_ok=True)

S = 612
KARAVANS = [
    ('karavan_gruz', (46, 30, 16), (120, 78, 36)),
    ('karavan_bronekolonna', (44, 24, 16), (122, 62, 34)),
    ('karavan_tsar', (40, 36, 20), (128, 96, 46)),
]


def radial_glow(size, color, alpha):
    g = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(g)
    steps = 26
    for i in range(steps, 0, -1):
        r = int(size * 0.52 * i / steps)
        a = int(alpha * (1 - i / steps) ** 1.7)
        d.ellipse([size // 2 - r, size // 2 - r, size // 2 + r, size // 2 + r], fill=a)
    layer = Image.new('RGBA', (size, size), color + (0,))
    layer.putalpha(g)
    return layer


def compose_portrait(name, top, bot):
    bg = Image.new('RGB', (S, S))
    px = bg.load()
    for y in range(S):
        t = y / (S - 1)
        row = (int(top[0] + (bot[0] - top[0]) * t),
               int(top[1] + (bot[1] - top[1]) * t),
               int(top[2] + (bot[2] - top[2]) * t))
        for x in range(S):
            px[x, y] = row
    img = bg.convert('RGBA')
    img.alpha_composite(radial_glow(S, (255, 170, 70), 120))
    fg = Image.open(os.path.join(RAW, name + '.png')).convert('RGBA')
    fg.thumbnail((S - 30, S - 30), Image.LANCZOS)
    # тень
    sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    a = fg.split()[3]
    foot = a.crop((0, max(0, a.height - 50), a.width, a.height))
    fw = int(fg.width * 1.25)
    foot = foot.resize((fw, max(8, foot.height // 3)))
    sh.paste(foot, ((S - fw) // 2, S - 50 - foot.height))
    r_, g_, b_, a_ = sh.split()
    a_ = a_.point(lambda v: v * 50 // 100)
    sh = Image.merge('RGBA', (r_, g_, b_, a_)).filter(ImageFilter.GaussianBlur(12))
    img.alpha_composite(sh)
    img.alpha_composite(fg, ((S - fg.width) // 2, S - 22 - fg.height))
    # виньетка + тёмная рамка серии
    vig = Image.new('L', (S, S), 0)
    dv = ImageDraw.Draw(vig)
    dv.rectangle([0, 0, S, S], fill=100)
    dv.ellipse([-S * 0.3, -S * 0.3, S * 1.3, S * 1.3], fill=0)
    vig = vig.filter(ImageFilter.GaussianBlur(46))
    dark = Image.new('RGBA', (S, S), (0, 0, 0, 255))
    dark.putalpha(vig)
    img.alpha_composite(dark)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, S - 1, S - 1], outline=(12, 12, 10, 255), width=14)
    img.convert('RGB').save(os.path.join(OUT, name + '.png'))
    print('PORTRAIT OK', name)


# ==================== 46б: иконки ярусов 128px ====================
TS = 128
TC = 64


def plate_base(rim):
    img = Image.new('RGBA', (TS, TS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cut = 18
    pts = [(cut, 4), (TS - cut, 4), (TS - 4, cut), (TS - 4, TS - cut),
           (TS - cut, TS - 4), (cut, TS - 4), (4, TS - cut), (4, cut), (cut, 4)]
    d.polygon(pts, fill=(22, 25, 20, 248))
    d.line(pts, fill=rim + (220,), width=4)
    for bx, by in [(cut - 4, cut - 4), (TS - cut + 4, cut - 4),
                   (cut - 4, TS - cut + 4), (TS - cut + 4, TS - cut + 4)]:
        d.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=rim + (190,))
    return img, d


ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X']


def num_strip(d, i, rim):
    d.rectangle([20, TS - 26, TS - 20, TS - 8], fill=(30, 33, 27, 255),
                outline=rim + (160,), width=2)
    w = len(ROMAN[i]) * 9 + 4
    # римские — простым PIL-шрифтом нет; рисуем палочками
    x0 = TC - w // 2
    y0 = TS - 24
    x = x0
    for ch in ROMAN[i]:
        if ch == 'I':
            d.rectangle([x, y0, x + 4, y0 + 14], fill=(232, 226, 190, 255))
            x += 9
        elif ch == 'V':
            d.polygon([(x, y0), (x + 5, y0 + 14), (x + 10, y0)], fill=(232, 226, 190, 255))
            x += 14
        elif ch == 'X':
            d.line([x, y0, x + 10, y0 + 14], fill=(232, 226, 190, 255), width=4)
            d.line([x + 10, y0, x, y0 + 14], fill=(232, 226, 190, 255), width=4)
            x += 14


def g_roots(d):
    # ветвистые корни
    d.line([TC, 26, TC, 52], fill=(160, 175, 110, 255), width=5)
    for dx, dy, ex, ey in [(0, 40, -20, 56), (0, 40, 20, 56), (0, 48, -8, 60), (0, 48, 10, 62)]:
        d.line([TC + dx, dy, TC + ex, ey], fill=(140, 155, 95, 235), width=4)
        d.ellipse([TC + ex - 3, ey - 3, TC + ex + 3, ey + 3], fill=(180, 195, 120, 255))


def g_pipes(d):
    # колено трубы с фланцами
    d.line([TC - 18, 36, TC + 8, 36], fill=(150, 165, 175, 255), width=10)
    d.line([TC + 8, 36, TC + 8, 58], fill=(150, 165, 175, 255), width=10)
    for (fx, fy) in [(TC - 22, 36), (TC + 8, 62)]:
        d.ellipse([fx - 7, fy - 7, fx + 7, fy + 7], outline=(190, 205, 215, 255), width=4)
    d.arc([TC - 6, 24, TC + 22, 52], 270, 90, fill=(150, 165, 175, 255), width=10)


def g_dump(d):
    # куча хлама: скошенные плиты
    d.polygon([(TC - 24, 58), (TC - 8, 34), (TC + 2, 58)], fill=(150, 110, 70, 255))
    d.polygon([(TC - 6, 58), (TC + 10, 30), (TC + 26, 58)], fill=(120, 88, 56, 255))
    d.rectangle([TC - 26, 58, TC + 26, 62], fill=(96, 70, 44, 255))
    d.line([TC + 2, 44, TC + 16, 38], fill=(180, 140, 90, 255), width=3)


def g_hollow(d):
    # глухая падь: впадина между холмами, туман
    d.polygon([(18, 58), (34, 34), (46, 58)], fill=(95, 80, 115, 255))
    d.polygon([(TC + 2, 58), (TC + 18, 30), (TC + 34, 58)], fill=(95, 80, 115, 255))
    d.arc([TC - 16, 42, TC + 16, 66], 180, 360, fill=(140, 120, 165, 200), width=5)
    d.arc([TC - 24, 50, TC + 24, 74], 180, 360, fill=(120, 100, 145, 160), width=4)


def g_rust_forest(d):
    # ржавое дерево из балок
    d.line([TC, 58, TC, 30], fill=(165, 110, 55, 255), width=8)
    d.line([TC, 42, TC - 16, 30], fill=(140, 92, 46, 255), width=5)
    d.line([TC, 36, TC + 15, 24], fill=(140, 92, 46, 255), width=5)
    d.line([TC, 52, TC + 20, 46], fill=(120, 78, 38, 255), width=4)
    d.line([TC, 52, TC - 20, 48], fill=(120, 78, 38, 255), width=4)
    d.rectangle([TC - 22, 58, TC + 22, 62], fill=(100, 66, 32, 255))


def g_ravine(d):
    # буерак: зигзаг-овраг
    d.line([24, 30, 44, 40, 34, 50, 56, 60], fill=(190, 165, 80, 255), width=5, joint='curve')
    d.line([104, 30, 84, 40, 94, 50, 72, 60], fill=(160, 138, 66, 255), width=5, joint='curve')
    d.line([TC - 10, 34, TC - 2, 44, TC - 8, 54], fill=(230, 205, 120, 255), width=4)


def g_sarcophagus(d):
    # саркофаг
    d.polygon([(TC - 16, 34), (TC + 16, 34), (TC + 20, 62), (TC - 20, 62)],
              fill=(120, 135, 120, 255), outline=(190, 205, 190, 255))
    d.line([TC - 16, 40, TC + 16, 40], fill=(190, 205, 190, 255), width=3)
    d.ellipse([TC - 5, 44, TC + 5, 54], outline=(190, 205, 190, 255), width=3)


def g_polygon(d):
    # полигон: мишень
    for r, a in ((22, 255), (14, 220), (7, 255)):
        d.ellipse([TC - r, 44 - r, TC + r, 44 + r], outline=(130, 165, 100, a), width=4)
    d.line([TC - 26, 44, TC - 18, 44], fill=(160, 200, 120, 255), width=3)
    d.line([TC + 18, 44, TC + 26, 44], fill=(160, 200, 120, 255), width=3)
    d.line([TC, 18, TC, 26], fill=(160, 200, 120, 255), width=3)


def g_rubezh(d):
    # рубеж: тройной шеврон коменданта
    for i, y in enumerate((26, 40, 54)):
        w = 20 - i * 3
        d.line([TC - w, y, TC, y + 9], fill=(200, 90, 70, 255 - i * 20), width=6)
        d.line([TC, y + 9, TC + w, y], fill=(200, 90, 70, 255 - i * 20), width=6)


def g_heart(d):
    # сердце Зоны: сердце + пульс
    d.polygon([(TC, 34), (TC + 18, 44), (TC + 18, 50), (TC, 62), (TC - 18, 50),
               (TC - 18, 44)], fill=(225, 185, 65, 255), outline=(255, 225, 120, 255))
    d.polygon([(TC, 44), (TC + 10, 49), (TC, 54), (TC - 10, 49)], fill=(255, 235, 150, 255))
    d.line([TC - 26, 49, TC - 14, 49], fill=(255, 225, 120, 220), width=3)
    d.line([TC + 14, 49, TC + 26, 49], fill=(255, 225, 120, 220), width=3)


GLYPHS = [g_roots, g_pipes, g_dump, g_hollow, g_rust_forest,
          g_ravine, g_sarcophagus, g_polygon, g_rubezh, g_heart]
# палитра TowerData.TIER_COLORS (согласована с игрой)
RIMS = [(115, 128, 77), (115, 133, 140), (140, 107, 64), (107, 89, 128),
        (153, 102, 51), (140, 122, 64), (128, 140, 128), (89, 115, 77),
        (140, 64, 51), (217, 179, 64)]


def tier_icon(i, glyph, rim):
    img, d = plate_base(rim)
    glyph(d)
    num_strip(d, i, rim)
    a = np.array(img).astype(np.int16)
    n = np.random.default_rng(1000 + i).integers(-3, 4, (TS, TS, 1))
    a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
    Image.fromarray(a.astype(np.uint8)).save(os.path.join(TIERS_DIR, f'tier_{i + 1}.png'))
    print('TIER OK', i + 1)


if __name__ == '__main__':
    for name, top, bot in KARAVANS:
        compose_portrait(name, top, bot)
    for i in range(10):
        tier_icon(i, GLYPHS[i], RIMS[i])
    print('TASK46 DONE')
