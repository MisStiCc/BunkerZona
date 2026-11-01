# -*- coding: utf-8 -*-
# ЗАДАЧА 34: 8 портретов новых видов D20. Живописный реколор арта базы
# (метод задач 11/19) + процедурные акценты стихии поверх, чтобы каждый вид
# отличался от простой перекраски.
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

CARDS = r'E:\StalkerRevert\StalkerRevert\ui\cards'
OUT = r'E:\StalkerRevert\StalkerRevert\inbox\species_cards_d20'

# тип -> (база, tint из NEW_SPECIES, [цвет акцента RGBA])
SPECIES = {
    'mohovik':  ('mut_flesh',           [0.55, 0.85, 0.45], ((90, 140, 60, 220), (140, 190, 90, 180))),
    'tsveten':  ('mut_poltergeist',     [0.85, 0.65, 1.0],  ((200, 150, 255, 200), (240, 200, 255, 170))),
    'zhivitsa': ('mut_bloodsucker',     [0.5, 0.95, 0.5],   ((255, 190, 60, 220), (120, 220, 120, 190))),
    'zaveden':  ('mut_controller_mutant', [1.0, 0.8, 0.55], ((255, 150, 50, 230), (255, 210, 110, 200))),
    'vikhor':   ('mut_pseudodog',       [0.9, 0.93, 1.0],   ((225, 232, 245, 180), (255, 255, 255, 150))),
    'shorokh':  ('mut_snork_mutant',    [0.72, 0.74, 0.7],  ((165, 168, 160, 200), (200, 202, 192, 160))),
    'leden':    ('mut_dog_mutant',      [0.6, 0.85, 1.0],   ((170, 225, 255, 210), (230, 250, 255, 190))),
    'guden':    ('mut_zombie',          [0.35, 0.38, 0.55], ((90, 90, 160, 210), (150, 150, 230, 170))),
}


def smoothstep(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def recolor(img, tint):
    """Колорайз: замена ОТТЕНКА с сохранением светимости и фактуры.
    Мультипликативный тинт не умеет green->lilac, поэтому здесь:
    цвет = tint * luma, фактура = высокочастотный остаток исходника."""
    a = np.asarray(img.convert('RGB')).astype(np.float32) / 255.0
    luma = (a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114)[..., None]
    t = np.asarray(tint, dtype=np.float32) / max(tint)   # нормируем к 1 по максимуму
    tinted = np.clip(t * luma * 1.5, 0, 1)               # цвет стихии * яркость
    detail = a - luma                                     # высокочастотная фактура
    out = np.clip(tinted + detail * 0.55, 0, 1)
    # рамка/глубокие тени остаются тёмными (не красятся в блеск)
    dark_w = (1.0 - smoothstep(luma, 0.02, 0.16)) * 0.55
    out = out * (1 - dark_w) + (luma * 0.9) * dark_w
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))


def accents_moss(d, w, h, cols):
    for _ in range(46):
        x, y = rng.uniform(0, w), rng.uniform(h * 0.25, h)
        r = rng.uniform(3, 12)
        col = cols[rng.randint(0, 1)]
        d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=col)


def accents_petals(d, w, h, cols):
    for _ in range(60):
        x, y = rng.uniform(0, w), rng.uniform(0, h * 0.95)
        r = rng.uniform(2, 6)
        ang = rng.uniform(0, math.tau)
        dx, dy = abs(math.cos(ang)) * r, abs(math.sin(ang)) * r * 0.55
        col = cols[rng.randint(0, 1)]
        d.ellipse([x - dx, y - dy, x + dx, y + dy], fill=col)


def accents_resin(d, w, h, cols):
    for _ in range(9):
        x = rng.uniform(w * 0.1, w * 0.9)
        y = rng.uniform(h * 0.2, h * 0.75)
        ln = rng.uniform(40, 130)
        for k in range(int(ln / 8)):
            yy = y + k * 8
            rr = 5 * (1 - k / (ln / 8)) + 2
            d.ellipse([x - rr, yy - rr, x + rr, yy + rr], fill=cols[0])
    for _ in range(22):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(1.5, 4)
        d.ellipse([x - r, y - r, x + r, y + r], fill=cols[1])


def accents_embers(d, w, h, cols):
    for _ in range(50):
        x, y = rng.uniform(0, w), rng.uniform(h * 0.35, h)
        r = rng.uniform(1.5, 4.5)
        col = cols[rng.randint(0, 1)]
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)


def accents_wind(d, w, h, cols):
    for _ in range(26):
        x0, y0 = rng.uniform(-40, w), rng.uniform(0, h)
        ln = rng.uniform(60, 180)
        ang = rng.uniform(-0.4, 0.25)
        pts = [(x0 + k * 7, y0 + math.sin(k / 3.0) * 9 + ang * k * 7) for k in range(int(ln / 7))]
        d.line(pts, fill=cols[rng.randint(0, 1)], width=rng.randint(2, 4))


def accents_dust(d, w, h, cols):
    for _ in range(90):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(1, 3.2)
        d.ellipse([x - r, y - r, x + r, y + r], fill=cols[rng.randint(0, 1)])


def accents_frost(d, w, h, cols):
    for _ in range(16):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(10, 30)
        for i in range(6):
            a = i * math.tau / 6 + rng.uniform(-0.2, 0.2)
            d.line([cx, cy, cx + math.cos(a) * r, cy + math.sin(a) * r],
                   fill=cols[0], width=2)
            for k in (0.45, 0.75):
                bx, by = cx + math.cos(a) * r * k, cy + math.sin(a) * r * k
                ba = a + rng.choice([-1, 1]) * 0.7
                d.line([bx, by, bx + math.cos(ba) * r * 0.3, by + math.sin(ba) * r * 0.3],
                       fill=cols[0], width=2)
    for _ in range(30):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(1, 2.6)
        d.ellipse([x - r, y - r, x + r, y + r], fill=cols[1])


def accents_aura(d, w, h, cols):
    rings = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rings)
    cx, cy = w * 0.5, h * 0.46
    for i in range(4):
        r = 30 + i * 26
        rd.arc([cx - r, cy - r, cx + r, cy + r], 0, 360,
               fill=cols[i % 2] if isinstance(cols, tuple) else cols[0], width=3)
    rings = rings.filter(ImageFilter.GaussianBlur(4))
    d._image.alpha_composite(rings) if hasattr(d, '_image') else None


ACCENT_FN = {
    'mohovik': accents_moss, 'tsveten': accents_petals, 'zhivitsa': accents_resin,
    'zaveden': accents_embers, 'vikhor': accents_wind, 'shorokh': accents_dust,
    'leden': accents_frost, 'guden': accents_aura,
}


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    for stype, (base, tint, cols) in SPECIES.items():
        src = Image.open(os.path.join(CARDS, base + '.png'))
        art = recolor(src, tint).convert('RGBA')
        rng = random.Random(hash(stype) % (1 << 30))
        d = ImageDraw.Draw(art, 'RGBA')
        if stype == 'guden':
            # аура: полупрозрачные кольца композитом
            w, h = art.size
            rings = Image.new('RGBA', (w, h), (0, 0, 0, 0))
            rd = ImageDraw.Draw(rings)
            cx, cy = w * 0.5, h * 0.46
            for i in range(4):
                r = 26 + i * 24
                rd.arc([cx - r, cy - r, cx + r, cy + r], 0, 360,
                       fill=cols[i % 2], width=3)
            art.alpha_composite(rings.filter(ImageFilter.GaussianBlur(4)))
            d = ImageDraw.Draw(art, 'RGBA')
            accents_dust(d, art.width, art.height, cols)
        else:
            ACCENT_FN[stype](d, art.width, art.height, cols)
        # лёгкое зерно единое для серии
        a = np.array(art).astype(np.int16)
        n = np.random.default_rng(hash(stype) % (1 << 30)).integers(-3, 4, (art.height, art.width, 1))
        a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
        out = Image.fromarray(a.astype(np.uint8)).convert('RGB')
        out.save(os.path.join(OUT, f'{stype}.png'))
        print(stype, '<-', base, art.size)
    print('готово: 8')
