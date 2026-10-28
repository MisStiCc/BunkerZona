# -*- coding: utf-8 -*-
# ЗАДАЧА 23: иконки способностей HUD 96px (16 аномалий + 10 мутантов).
# Стиль: тёмная плашка со срезанными углами + цветной глиф стихии/семейства.
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\ability_icons'
S = 96
C = 48  # центр

# цвета стихий (сверены с _style_el_button hud.gd по духу)
FIRE = (255, 122, 30)
ELEC = (90, 184, 255)
ACID = (126, 200, 80)
GRAV = (160, 108, 232)
THERM = (255, 160, 70)
CHEM = (170, 220, 90)
RAD = (220, 230, 90)
TIME = (90, 220, 230)
TELE = (140, 120, 255)
BIO = (255, 140, 60)
BONE = (200, 195, 170)
BLOOD = (220, 70, 55)
OLIVE = (150, 160, 100)
ASHC = (170, 175, 165)


def plate(glyph_fn, accent):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cut = 16
    pts = [(cut, 3), (S - cut, 3), (S - 3, cut), (S - 3, S - cut), (S - cut, S - 3),
           (cut, S - 3), (3, S - cut), (3, cut), (cut, 3)]
    d.polygon(pts, fill=(24, 27, 22, 246))
    d.line(pts, fill=accent + (200,), width=3)
    glyph_fn(d, img)
    a = np.array(img).astype(np.int16)
    n = np.random.default_rng(hash(glyph_fn.__name__) % (1 << 30)).integers(-3, 4, (S, S, 1))
    a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def glow(d, cx, cy, r, color, alpha):
    for k, rr in enumerate((r, r * 0.7, r * 0.45)):
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (int(alpha * (0.3, 0.5, 0.8)[k]),))


def L(d, x0, y0, x1, y1, col, w):
    d.line([x0, y0, x1, y1], fill=col, width=w)


# ---------------- аномалии ----------------
def heat(d, img):
    glow(d, C, 54, 34, FIRE, 70)
    for (dx, sc, a) in [(0, 1.0, 255), (-16, 0.7, 160), (16, 0.7, 160)]:
        cx = C + dx
        d.polygon([(cx - 15 * sc, 78), (cx + 15 * sc, 78), (cx + 4 * sc, 46 * sc + 12), (cx, 26), (cx - 4 * sc, 46 * sc + 12)],
                  fill=FIRE + (a,))
    d.polygon([(C - 7, 74), (C + 7, 74), (C, 46)], fill=(255, 210, 120, 235))


def electric(d, img):
    glow(d, C, 48, 34, ELEC, 70)
    d.polygon([(52, 18), (34, 50), (46, 50), (40, 78), (62, 44), (49, 44), (58, 18)],
              fill=ELEC + (255,), outline=(200, 235, 255, 200))


def acid(d, img):
    glow(d, C, 52, 32, ACID, 60)
    d.polygon([(C, 20), (C + 17, 48), (C + 11, 66), (C - 11, 66), (C - 17, 48)], fill=ACID + (235,))
    d.ellipse([C - 7, 48, C + 7, 62], fill=(40, 70, 24, 255))
    d.ellipse([C - 4, 51, C + 4, 59], fill=(190, 255, 140, 255))


def vortex(d, img):
    glow(d, C, 48, 34, GRAV, 70)
    for i in range(3):
        r = 12 + i * 11
        a0 = i * 2.1
        d.arc([C - r, 48 - r, C + r, 48 + r], math.degrees(a0), math.degrees(a0 + 4.4),
              fill=GRAV + (255 - i * 55,), width=6 - i)
    d.ellipse([C - 5, 43, C + 5, 53], fill=(240, 225, 255, 255))


def lift(d, img):
    glow(d, C, 48, 32, GRAV, 60)
    for i, y in enumerate((58, 42, 26)):
        w = 26 - i * 4
        d.line([C - w, y + 12, C, y], fill=GRAV + (255 - i * 60,), width=7)
        d.line([C, y, C + w, y + 12], fill=GRAV + (255 - i * 60,), width=7)


def whirlwind(d, img):
    glow(d, C, 50, 32, (150, 150, 200), 55)
    for i in range(5):
        y = 24 + i * 12
        w = 10 + i * 8
        a = 255 - i * 38
        d.arc([C - w, y - 9, C + w, y + 9], 200, 340, fill=(150, 150, 210, a), width=5)
    d.ellipse([C - 7, 66, C + 7, 80], fill=(150, 150, 210, 120))


def steam(d, img):
    glow(d, C, 48, 30, THERM, 50)
    for dx in (-20, 0, 20):
        for k, y in enumerate((70, 54, 38)):
            r = 9 - k * 1.5
            d.arc([C + dx - r, y - r, C + dx + r, y + r], 180, 380,
                  fill=THERM + (230 - k * 60,), width=4)
    d.rectangle([C - 30, 74, C + 30, 80], fill=THERM + (140,))


def comet(d, img):
    glow(d, C, 52, 32, (255, 120, 60), 60)
    for i in range(4):
        d.line([20 + i * 6, 24 + i * 4, 56, 70 - i * 3], fill=(255, 170 - i * 25, 60, 200 - i * 35), width=5 - i)
    d.ellipse([C - 14, 40, C + 14, 68], fill=(255, 190, 90, 255), outline=(200, 80, 20, 255))
    d.ellipse([C - 7, 47, C + 5, 59], fill=(255, 240, 170, 255))


def jelly(d, img):
    glow(d, C, 54, 32, CHEM, 60)
    d.ellipse([C - 24, 34, C + 24, 78], fill=(120, 170, 60, 200))
    d.ellipse([C - 24, 34, C + 24, 78], outline=(190, 230, 120, 255), width=3)
    d.ellipse([C - 13, 40, C + 2, 52], fill=(220, 250, 160, 190))
    d.ellipse([C - 10, 62, C - 2, 70], fill=(70, 110, 36, 255))
    d.ellipse([C + 6, 58, C + 14, 66], fill=(70, 110, 36, 255))


def gas(d, img):
    glow(d, C, 50, 30, (170, 185, 150), 45)
    for (dx, dy, r, a) in [(-20, 52, 16, 200), (2, 42, 20, 220), (22, 54, 15, 190), (-4, 62, 14, 170)]:
        d.ellipse([C + dx - r, 48 + dy - r - 14, C + dx + r, 48 + dy - r + r], fill=(150, 165, 135, a))
    for (ex, ey) in [(C - 14, 40), (C + 12, 46)]:
        d.ellipse([ex - 4, ey - 4, ex + 4, ey + 4], fill=(190, 205, 165, 255))


def acid_cloud(d, img):
    glow(d, C, 44, 30, ACID, 50)
    d.ellipse([C - 30, 26, C + 8, 56], fill=(120, 140, 100, 235))
    d.ellipse([C - 8, 20, C + 30, 52], fill=(134, 154, 112, 235))
    for i in range(4):
        x = C - 20 + i * 13
        d.polygon([(x - 4, 58), (x + 4, 58), (x, 72)], fill=ACID + (235,))
    d.rectangle([C - 26, 52, C + 26, 58], fill=(104, 124, 86, 235))


def radiation(d, img):
    glow(d, C, 48, 34, RAD, 65)
    cx, cy = C, 48
    for i in range(3):
        a0 = 90 + i * 120 - 26
        d.pieslice([cx - 30, cy - 30, cx + 30, cy + 30], a0, a0 + 52, fill=RAD + (245,))
    d.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(30, 34, 24, 255))
    d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=RAD + (255,))


def time_dil(d, img):
    glow(d, C, 48, 32, TIME, 60)
    d.ellipse([C - 26, 22, C + 26, 74], outline=TIME + (255,), width=5)
    d.ellipse([C - 20, 28, C + 20, 68], outline=TIME + (110,), width=2)
    L(d, C, 48, C, 32, TIME + (255,), 4)
    L(d, C, 48, C + 13, 54, TIME + (255,), 4)
    d.ellipse([C - 3, 45, C + 3, 51], fill=TIME + (255,))


def teleport(d, img):
    glow(d, C, 48, 34, TELE, 70)
    for i, (rx, ry, a) in enumerate([(26, 34, 235), (18, 24, 190), (10, 14, 150)]):
        d.ellipse([C - rx, 48 - ry, C + rx, 48 + ry], outline=TELE + (a,), width=4)
    d.ellipse([C - 5, 43, C + 5, 53], fill=(235, 225, 255, 255))


def tesla(d, img):
    glow(d, C, 48, 34, ELEC, 70)
    d.rounded_rectangle([C - 9, 22, C + 9, 78], radius=4, fill=(46, 54, 38, 255),
                        outline=ELEC + (255,))
    for y in (34, 50, 66):
        d.polygon([(C + 9, y - 5), (C + 24, y - 12), (C + 16, y - 2), (C + 26, y + 2)],
                  fill=ELEC + (235,))
        d.polygon([(C - 9, y + 3), (C - 24, y - 4), (C - 16, y + 6), (C - 26, y + 10)],
                  fill=ELEC + (200,))
    d.ellipse([C - 4, 14, C + 4, 22], fill=(220, 240, 255, 255))


def fluff(d, img):
    glow(d, C, 46, 32, BIO, 60)
    cx, cy = C, 44
    r = 22
    for i in range(14):
        a = i * math.tau / 14
        d.line([cx, cy, cx + math.cos(a) * r, cy + math.sin(a) * r], fill=(255, 160, 70, 220), width=2)
        d.ellipse([cx + math.cos(a) * r - 3, cy + math.sin(a) * r - 3,
                   cx + math.cos(a) * r + 3, cy + math.sin(a) * r + 3], fill=(255, 200, 90, 235))
    d.line([cx, cy, cx, 80], fill=(120, 90, 40, 255), width=3)


ANOMALIES = {
    'heat_anomaly': heat, 'electric_anomaly': electric, 'acid_anomaly': acid,
    'gravity_vortex': vortex, 'gravity_lift': lift, 'gravity_whirlwind': whirlwind,
    'thermal_steam': steam, 'thermal_comet': comet, 'chemical_jelly': jelly,
    'chemical_gas': gas, 'chemical_acid_cloud': acid_cloud, 'radiation_hotspot': radiation,
    'time_dilation': time_dil, 'teleport': teleport, 'electric_tesla': tesla,
    'bio_burning_fluff': fluff,
}


# ---------------- мутанты ----------------
def eye(d, x, y, r, col):
    d.ellipse([x - r, y - r, x + r, y + r], fill=(20, 22, 16, 255), outline=col + (255,))
    d.ellipse([x - r * 0.4, y - r * 0.4, x + r * 0.4, y + r * 0.4], fill=col + (255,))


def zombie(d, img):
    glow(d, C, 48, 32, (140, 200, 110), 45)
    d.ellipse([C - 22, 20, C + 22, 66], fill=(90, 110, 78, 255), outline=(50, 64, 40, 255))
    d.ellipse([C - 15, 30, C - 5, 44], fill=(18, 20, 14, 255))
    d.ellipse([C + 5, 30, C + 15, 44], fill=(18, 20, 14, 255))
    eye(d, C - 10, 37, 3, (170, 230, 120))
    eye(d, C + 10, 37, 3, (170, 230, 120))
    for i in range(4):
        d.line([C - 12 + i * 8, 52, C - 12 + i * 8, 62], fill=(40, 52, 32, 255), width=2)
    d.line([C - 12, 57, C + 12, 57], fill=(40, 52, 32, 255), width=2)


def dog(d, img):
    glow(d, C, 48, 32, (200, 130, 90), 45)
    d.polygon([(C - 26, 30), (C - 10, 22), (C - 12, 44)], fill=(110, 80, 58, 255))
    d.polygon([(C + 26, 30), (C + 10, 22), (C + 12, 44)], fill=(110, 80, 58, 255))
    d.ellipse([C - 18, 28, C + 18, 68], fill=(128, 94, 66, 255), outline=(70, 50, 34, 255))
    eye(d, C - 9, 40, 4, (255, 180, 80))
    eye(d, C + 9, 40, 4, (255, 180, 80))
    d.polygon([(C - 8, 58), (C + 8, 58), (C, 68)], fill=(40, 28, 20, 255))
    for i in range(4):
        d.polygon([(C - 7 + i * 4.6, 58), (C - 5 + i * 4.6, 58), (C - 6 + i * 4.6, 64)],
                  fill=(230, 220, 190, 255))


def flesh(d, img):
    glow(d, C, 50, 32, (230, 120, 110), 50)
    d.ellipse([C - 28, 26, C + 28, 76], fill=(196, 96, 92, 255), outline=(120, 48, 46, 255))
    d.ellipse([C - 18, 34, C + 6, 58], fill=(226, 140, 130, 220))
    eye(d, C + 8, 50, 9, (240, 220, 190))
    eye(d, C + 8, 50, 4, (60, 20, 18))
    for (bx, by, br) in [(C - 16, 66, 4), (C + 0, 70, 3), (C - 4, 32, 3)]:
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=(140, 58, 54, 255))


def snork(d, img):
    glow(d, C, 48, 32, (150, 170, 90), 45)
    d.ellipse([C - 22, 24, C + 22, 70], fill=(96, 110, 62, 255), outline=(52, 62, 34, 255))
    # противогаз: два круглых глаза + фильтр
    d.ellipse([C - 16, 34, C - 2, 48], fill=(30, 34, 24, 255), outline=(150, 165, 110, 255))
    d.ellipse([C + 2, 34, C + 16, 48], fill=(30, 34, 24, 255), outline=(150, 165, 110, 255))
    eye(d, C - 9, 41, 3, (220, 255, 150))
    eye(d, C + 9, 41, 3, (220, 255, 150))
    d.ellipse([C - 7, 52, C + 7, 68], fill=(58, 66, 40, 255), outline=(150, 165, 110, 200))


def pseudodog(d, img):
    glow(d, C, 48, 32, ASHC, 45)
    d.polygon([(C - 26, 30), (C - 10, 20), (C - 13, 42)], fill=(90, 95, 90, 255))
    d.polygon([(C + 26, 30), (C + 10, 20), (C + 13, 42)], fill=(90, 95, 90, 255))
    d.ellipse([C - 18, 26, C + 18, 68], fill=(112, 118, 110, 255), outline=(56, 60, 56, 255))
    eye(d, C - 9, 40, 4, (230, 240, 220))
    eye(d, C + 9, 40, 4, (230, 240, 220))
    d.polygon([(C - 8, 58), (C + 8, 58), (C, 70)], fill=(26, 28, 26, 255))


def poltergeist(d, img):
    glow(d, C, 48, 34, (120, 220, 200), 55)
    d.polygon([(C - 20, 22), (C + 20, 22), (C + 16, 60), (C + 8, 50), (C, 64), (C - 8, 50), (C - 16, 60)],
              fill=(150, 230, 205, 210))
    eye(d, C - 8, 38, 3.5, (20, 40, 34))
    eye(d, C + 8, 38, 3.5, (20, 40, 34))
    d.ellipse([C - 4, 46, C + 4, 52], fill=(20, 40, 34, 200))


def controller(d, img):
    glow(d, C, 48, 36, (190, 120, 240), 60)
    eye(d, C, 46, 20, (210, 160, 250))
    eye(d, C, 46, 9, (30, 16, 40))
    for i in range(8):
        a = i * math.tau / 8 + 0.4
        x0 = C + math.cos(a) * 22
        y0 = 46 + math.sin(a) * 22
        d.line([x0, y0, C + math.cos(a) * 36, 46 + math.sin(a) * 34], fill=(170, 110, 220, 255), width=3)
        d.ellipse([C + math.cos(a) * 36 - 3, 46 + math.sin(a) * 34 - 3,
                   C + math.cos(a) * 36 + 3, 46 + math.sin(a) * 34 + 3], fill=(210, 160, 250, 255))


def bloodsucker(d, img):
    glow(d, C, 50, 32, BLOOD, 50)
    d.ellipse([C - 20, 22, C + 20, 72], fill=(64, 84, 62, 255), outline=(34, 46, 34, 255))
    d.polygon([(C - 12, 52), (C + 12, 52), (C, 74)], fill=(28, 38, 28, 255))
    for i in range(5):
        x = C - 10 + i * 5
        d.polygon([(x, 53), (x + 4, 53), (x + 2, 63)], fill=(235, 230, 205, 255))
    eye(d, C - 9, 38, 4, (240, 120, 90))
    eye(d, C + 9, 38, 4, (240, 120, 90))


def chimera(d, img):
    glow(d, C, 48, 34, (255, 100, 60), 55)
    # две головы
    for dx in (-14, 14):
        d.ellipse([C + dx - 13, 24, C + dx + 13, 56], fill=(70, 44, 38, 255), outline=(40, 24, 20, 255))
        eye(d, C + dx, 36, 4, (255, 90, 60))
        d.polygon([(C + dx - 6, 50), (C + dx + 6, 50), (C + dx, 60)], fill=(26, 16, 14, 255))
    d.ellipse([C - 8, 58, C + 8, 74], fill=(56, 36, 30, 255))


def pseudogiant(d, img):
    glow(d, C, 50, 34, (180, 170, 150), 50)
    d.ellipse([C - 20, 18, C + 20, 50], fill=(140, 132, 116, 255), outline=(80, 76, 66, 255))
    eye(d, C - 8, 34, 3.5, (255, 190, 90))
    eye(d, C + 8, 34, 3.5, (255, 190, 90))
    # кулак
    d.rounded_rectangle([C + 12, 52, C + 42, 82], radius=10, fill=(128, 120, 104, 255),
                        outline=(80, 76, 66, 255))
    for i in range(3):
        d.line([C + 20 + i * 8, 54, C + 20 + i * 8, 62], fill=(80, 76, 66, 255), width=2)


MUTANTS = {
    'zombie': zombie, 'dog_mutant': dog, 'flesh': flesh, 'snork_mutant': snork,
    'pseudodog': pseudodog, 'poltergeist': poltergeist, 'controller_mutant': controller,
    'bloodsucker': bloodsucker, 'chimera': chimera, 'pseudogiant': pseudogiant,
}


if __name__ == '__main__':
    import os
    os.makedirs(f'{OUT}\\anomaly', exist_ok=True)
    os.makedirs(f'{OUT}\\mutant', exist_ok=True)
    for name, fn in ANOMALIES.items():
        col = {'heat_anomaly': FIRE, 'electric_anomaly': ELEC, 'acid_anomaly': ACID}.get(name)
        if col is None:
            col = {'gravity_vortex': GRAV, 'gravity_lift': GRAV, 'gravity_whirlwind': (150, 150, 210),
                   'thermal_steam': THERM, 'thermal_comet': (255, 120, 60), 'chemical_jelly': CHEM,
                   'chemical_gas': (150, 165, 135), 'chemical_acid_cloud': ACID,
                   'radiation_hotspot': RAD, 'time_dilation': TIME, 'teleport': TELE,
                   'electric_tesla': ELEC, 'bio_burning_fluff': BIO}[name]
        plate(fn, col).save(f'{OUT}\\anomaly\\{name}.png')
        print('anomaly/' + name)
    for name, fn in MUTANTS.items():
        plate(fn, (140, 130, 110)).save(f'{OUT}\\mutant\\{name}.png')
        print('mutant/' + name)
