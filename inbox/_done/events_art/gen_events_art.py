# -*- coding: utf-8 -*-
# ЗАДАЧА 37: арт-пак циклических событий (live-ops D24). Процедурно, CC0.
# 6 баннеров 1920x640 (место под название СЛЕВА), 6 иконок 256, 9 тайлов
# Жатвы 128 (прозрачные), 2 виньетки 256.
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\events_art'

BW, BH = 1920, 640
GOLD = (232, 179, 57)
SWAMP = (110, 150, 90)
CREAM = (237, 230, 196)


def grain(img, amount=5, seed=1):
    a = np.array(img).astype(np.int16)
    n = np.random.default_rng(seed).integers(-amount, amount + 1, (a.shape[0], a.shape[1], 1))
    a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def vignette(img, strength=0.55):
    w, h = img.size
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / 1.42
    a = (np.clip(d, 0, 1) ** 2.0 * strength * 255).astype(np.uint8)
    dark = np.zeros((h, w, 4), dtype=np.uint8)
    dark[..., 3] = a
    out = img.convert('RGBA')
    out.alpha_composite(Image.fromarray(dark))
    return out.convert('RGB')


def bg_grad(w, h, top, bottom):
    yy = np.mgrid[0:h, 0:w][0].reshape(h, w, 1) / h
    top = np.array(top, dtype=np.float32) / 255.0
    bot = np.array(bottom, dtype=np.float32) / 255.0
    return np.clip(top + (bot - top) * (yy ** 1.4), 0, 1)


# ---------------- сцены баннеров ----------------

def scene_zharva(r):
    """Жатва: аномалии-тайлы, осенняя гамма (орех/охра/багрянец)."""
    img = Image.fromarray((bg_grad(BW, BH, (72, 44, 18), (26, 16, 8)) * 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(img, 'RGBA')
    # ряды парящих тайлов-аномалий справа
    rng = random.Random(11)
    keys = ['fire', 'bolt', 'drop', 'vortex', 'gas', 'radiation']
    for row in range(3):
        y = 130 + row * 170
        for col in range(7):
            x = 760 + col * 160 + rng.randint(-20, 20)
            s = rng.randint(72, 104)
            colr, glyph = TILE_COLS[keys[(row * 7 + col) % 6]]
            tile(d, x, y, s, colr, glyph)
    # стая листьев/искр
    for _ in range(70):
        x, y = rng.uniform(700, BW), rng.uniform(0, BH)
        s = rng.uniform(2, 6)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(255, rng.randint(140, 200), 60, rng.randint(60, 160)))
    # мягкий свет
    glow = radial(900, (255, 170, 60), 60, 2.4)
    img.alpha_composite(glow, (BW - 700, BH // 2 - 450))
    return img


def scene_uley(r):
    """Улей: химера в свете прожекторов, красно-чёрный."""
    img = Image.fromarray((bg_grad(BW, BH, (54, 12, 10), (14, 5, 6)) * 255).astype(np.uint8)).convert('RGBA')
    # прожекторные лучи
    beams = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
    bd = ImageDraw.Draw(beams)
    for x0, ang in ((1050, -0.35), (1350, 0.0), (1650, 0.35)):
        bx = x0 + math.sin(ang) * 400
        bd.polygon([(x0, 0), (x0 + 90, 0), (bx + 260, BH), (bx - 260, BH)], fill=(255, 90, 60, 26))
    beams = beams.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(beams)
    d = ImageDraw.Draw(img, 'RGBA')
    # силуэт химеры: массивный торс + две головы
    cx, cy = 1330, 420
    d.polygon([(cx - 210, cy + 180), (cx + 210, cy + 180), (cx + 150, cy - 60), (cx - 150, cy - 60)],
              fill=(24, 10, 10, 250))
    for dx in (-95, 95):
        d.ellipse([cx + dx - 62, cy - 168, cx + dx + 62, cy - 44], fill=(28, 12, 12, 250),
                  outline=(120, 30, 24, 255))
        # глаза
        d.ellipse([cx + dx - 30, cy - 130, cx + dx - 10, cy - 112], fill=(255, 70, 50, 255))
        d.ellipse([cx + dx + 10, cy - 130, cx + dx + 30, cy - 112], fill=(255, 70, 50, 255))
    # когти
    for dx in (-190, 190):
        d.polygon([(cx + dx, cy + 60), (cx + dx + 60 * (1 if dx > 0 else -1), cy + 120),
                   (cx + dx + 20 * (1 if dx > 0 else -1), cy + 180)], fill=(24, 10, 10, 250))
    # соты улья на фоне
    for _ in range(16):
        x, y = r.uniform(650, BW), r.uniform(0, BH * 0.5)
        s = r.uniform(14, 30)
        d.polygon([(x, y - s), (x + s * 0.87, y - s / 2), (x + s * 0.87, y + s / 2), (x, y + s),
                   (x - s * 0.87, y + s / 2), (x - s * 0.87, y - s / 2)],
                  outline=(180, 60, 40, 90), width=2)
    return img


def scene_labyrinth(r):
    """Лабиринт: каменные стены с синим туманом."""
    img = Image.fromarray((bg_grad(BW, BH, (16, 26, 44), (8, 12, 22)) * 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(img, 'RGBA')
    # лабиринт спереди: колонны-стены с проходами
    rng = random.Random(13)
    x = 700
    while x < BW - 40:
        w = rng.randint(60, 130)
        h = rng.randint(BH // 2, int(BH * 0.86))
        y1 = BH - rng.randint(20, 90)
        d.polygon([(x, y1), (x + w, y1), (x + w, y1 - h), (x, y1 - h)],
                  fill=(28, 40, 62, 255), outline=(60, 90, 130, 160))
        d.polygon([(x, y1), (x + w, y1), (x + w, y1 + 26), (x, y1 + 26)], fill=(16, 24, 38, 255))
        x += w + rng.randint(46, 110)
    # синий туман
    fog = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fog)
    for _ in range(40):
        x, y = rng.uniform(600, BW), rng.uniform(BH * 0.35, BH)
        rx, ry = rng.uniform(90, 260), rng.uniform(30, 80)
        fd.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(90, 140, 220, 22))
    fog = fog.filter(ImageFilter.GaussianBlur(16))
    img.alpha_composite(fog)
    # аномальная точка-цель в глубине
    glow = radial(300, (120, 180, 255), 120, 2.2)
    img.alpha_composite(glow, (BW - 420, BH // 2 - 150))
    return img


def scene_chain(r):
    """Цепь Электры: узлы-аномалии, соединённые молниями-схемой, электрик."""
    img = Image.fromarray((bg_grad(BW, BH, (10, 24, 40), (5, 10, 18)) * 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(img, 'RGBA')
    rng = random.Random(15)
    nodes = [(820, 320), (1080, 160), (1300, 400), (1520, 220), (1740, 430)]
    for (x, y) in nodes:
        rr = 26
        d.ellipse([x - rr, y - rr, x + rr, y + rr], outline=(120, 210, 255, 230), width=4)
        d.ellipse([x - rr // 2, y - rr // 2, x + rr // 2, y + rr // 2], fill=(160, 225, 255, 190))
    # молнии-схема: ломаные между узлами
    for i in range(len(nodes) - 1):
        x0, y0 = nodes[i]
        x1, y1 = nodes[i + 1]
        pts = [(x0, y0)]
        steps = 7
        for k in range(1, steps):
            tt = k / steps
            pts.append((x0 + (x1 - x0) * tt + rng.uniform(-16, 16),
                        y0 + (y1 - y0) * tt + rng.uniform(-16, 16)))
        pts.append((x1, y1))
        d.line(pts, fill=(140, 220, 255, 210), width=3)
        d.line([(p[0] + 3, p[1]) for p in pts], fill=(80, 160, 230, 90), width=6)
    # микроразряды
    for _ in range(40):
        x, y = r.uniform(700, BW), r.uniform(0, BH)
        d.point((x, y), fill=(180, 230, 255, rng.randint(80, 200)))
    return img


def scene_vault(r):
    """Взлом Котелка: сейфы, золото на графите."""
    img = Image.fromarray((bg_grad(BW, BH, (34, 34, 34), (16, 16, 16)) * 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(img, 'RGBA')
    rng = random.Random(17)
    # сейфы: три штуки разного размера
    for (x, y, s) in ((950, 120, 380), (1400, 260, 260), (1650, 90, 200)):
        d.rounded_rectangle([x, y, x + s, y + s], radius=s // 12, fill=(44, 44, 48, 255),
                            outline=(120, 120, 128, 255), width=5)
        d.rounded_rectangle([x + s * 0.12, y + s * 0.12, x + s * 0.88, y + s * 0.88], radius=s // 14,
                            outline=(90, 90, 96, 200), width=3)
        # диск-механизм
        cx, cy, rr = x + s * 0.42, y + s * 0.5, s * 0.17
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(30, 30, 34, 255), outline=(200, 170, 80, 255), width=4)
        d.line([cx, cy - rr, cx, cy + rr], fill=(200, 170, 80, 160), width=2)
        d.line([cx - rr, cy, cx + rr, cy], fill=(200, 170, 80, 160), width=2)
        d.line([cx, cy - rr * 0.5, cx + rr * 0.42, cy - rr * 0.2], fill=(255, 214, 110, 255), width=4)
        # ручка
        d.rectangle([x + s * 0.78, y + s * 0.4, x + s * 0.85, y + s * 0.6], fill=(160, 160, 168, 255))
    # россыпь монет
    for _ in range(60):
        x, y = rng.uniform(700, BW), rng.uniform(BH * 0.6, BH - 30)
        rr = rng.uniform(4, 11)
        d.ellipse([x - rr, y - rr * 0.7, x + rr, y + rr * 0.7], fill=(232, 179, 57, rng.randint(150, 255)),
                  outline=(120, 90, 20, 160))
    glow = radial(700, (255, 200, 90), 70, 2.4)
    img.alpha_composite(glow, (BW - 640, BH // 2 - 320))
    return img


def scene_bolts(r):
    """Болты Гравитона: дуги-траектории, фиолет."""
    img = Image.fromarray((bg_grad(BW, BH, (26, 14, 46), (10, 6, 20)) * 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(img, 'RGBA')
    rng = random.Random(19)
    # дугообразные траектории болтов
    for i in range(7):
        x0 = 760 + i * 40
        y0 = BH - 60 - i * 24
        amp = 90 + i * 26
        pts = [(x0 + math.sin(k / 9.0) * 30, y0 - k * (4.5 + i * 0.4) + math.sin(k / 5.0) * 6)
               for k in range(70)]
        w = 6 - i * 0.5
        d.line(pts, fill=(170, 120, 255, 190), width=max(2, int(w)))
        d.line([(p[0] + 4, p[1]) for p in pts], fill=(120, 80, 200, 90), width=max(3, int(w) + 3))
        # болт на конце
        ex, ey = pts[-1]
        d.polygon([(ex - 9, ey + 16), (ex + 9, ey + 16), (ex, ey - 10)], fill=(220, 190, 255, 230))
    # гравитационный колодец слева-снизу от траекторий
    for i in range(4):
        rr = 40 + i * 34
        d.arc([1250 - rr, 420 - rr // 2, 1250 + rr, 420 + rr // 2], 0, 360,
              fill=(150, 100, 230, 110 - i * 20), width=3)
    for _ in range(30):
        x, y = rng.uniform(700, BW), rng.uniform(0, BH)
        s = rng.uniform(1, 3)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(200, 170, 255, rng.randint(70, 170)))
    return img


def radial(size, color, max_alpha, power):
    yy, xx = np.mgrid[0:size, 0:size]
    c = size / 2
    dd = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
    a = np.clip(1 - dd, 0, 1) ** power * max_alpha
    m = np.zeros((size, size, 4), dtype=np.uint8)
    m[..., 0], m[..., 1], m[..., 2] = color
    m[..., 3] = a.astype(np.uint8)
    return Image.fromarray(m)


# ---------------- тайлы аномалий (128, прозрачные) ----------------

def tile(d, x, y, s, col, glyph):
    """Плитка-аномалия: скруглённый квадрат с глифом."""
    pad = int(s * 0.12)
    d.rounded_rectangle([x - s / 2 + pad, y - s / 2 + pad, x + s / 2 - pad, y + s / 2 - pad],
                        radius=int(s * 0.14), fill=(24, 27, 22, 220), outline=col + (255,),
                        width=max(3, int(s * 0.045)))
    g = glyph
    if g == 'fire':
        d.polygon([(x, y - s * 0.26), (x + s * 0.16, y + s * 0.02), (x + s * 0.09, y + s * 0.22),
                   (x - s * 0.09, y + s * 0.22), (x - s * 0.16, y + s * 0.02)], fill=col + (255,))
        d.polygon([(x, y - s * 0.1), (x + s * 0.07, y + s * 0.14), (x, y + s * 0.2), (x - s * 0.07, y + s * 0.14)],
                  fill=(255, 220, 140, 255))
    elif g == 'bolt':
        d.polygon([(x + s * 0.08, y - s * 0.24), (x - s * 0.1, y + s * 0.04), (x, y + s * 0.04),
                   (x - s * 0.06, y + s * 0.24), (x + s * 0.14, y - s * 0.04), (x + s * 0.02, y - s * 0.04)],
                  fill=col + (255,))
    elif g == 'drop':
        d.polygon([(x, y - s * 0.24), (x + s * 0.14, y + s * 0.06), (x + s * 0.09, y + s * 0.2),
                   (x - s * 0.09, y + s * 0.2), (x - s * 0.14, y + s * 0.06)], fill=col + (235,))
        d.ellipse([x - s * 0.06, y + s * 0.04, x + s * 0.06, y + s * 0.16], fill=(30, 50, 20, 255))
    elif g == 'vortex':
        for i in range(3):
            rr = s * (0.1 + i * 0.08)
            d.arc([x - rr, y - rr, x + rr, y + rr], math.degrees(i * 2.1), math.degrees(i * 2.1 + 4.4),
                  fill=col + (255 - i * 55,), width=max(2, int(s * 0.05) - i))
        d.ellipse([x - s * 0.05, y - s * 0.05, x + s * 0.05, y + s * 0.05], fill=(240, 230, 255, 255))
    elif g == 'gas':
        for (dx, dy, rr) in ((-s * 0.16, s * 0.06, s * 0.14), (s * 0.02, -s * 0.04, s * 0.17),
                             (s * 0.18, s * 0.08, s * 0.12)):
            d.ellipse([x + dx - rr, y + dy - rr, x + dx + rr, y + dy + rr], fill=col + (200,))
    elif g == 'radiation':
        for i in range(3):
            a0 = 90 + i * 120 - 26
            d.pieslice([x - s * 0.24, y - s * 0.24, x + s * 0.24, y + s * 0.24], a0, a0 + 52, fill=col + (245,))
        d.ellipse([x - s * 0.08, y - s * 0.08, x + s * 0.08, y + s * 0.08], fill=(20, 22, 16, 255))
    elif g == 'funnel':  # воронка
        d.polygon([(x - s * 0.26, y - s * 0.22), (x + s * 0.26, y - s * 0.22), (x + s * 0.05, y + s * 0.1),
                   (x + s * 0.05, y + s * 0.26), (x - s * 0.05, y + s * 0.26), (x - s * 0.05, y + s * 0.1)],
                  fill=col + (255,), outline=(255, 255, 255, 120))
    elif g == 'sarcophagus':  # саркофаг
        d.polygon([(x - s * 0.14, y - s * 0.26), (x + s * 0.14, y - s * 0.26), (x + s * 0.18, y + s * 0.26),
                   (x - s * 0.18, y + s * 0.26)], fill=col + (255,), outline=(255, 255, 255, 130))
        for yy in (y - s * 0.1, y + s * 0.02):
            d.line([x - s * 0.12, yy, x + s * 0.12, yy], fill=(255, 214, 110, 180), width=2)
    elif g == 'electra':  # электра
        d.polygon([(x + s * 0.1, y - s * 0.24), (x - s * 0.12, y + s * 0.02), (x - s * 0.01, y + s * 0.02),
                   (x - s * 0.09, y + s * 0.24), (x + s * 0.13, y - s * 0.04), (x + s * 0.0, y - s * 0.04)],
                  fill=col + (255,))
        d.ellipse([x - s * 0.24, y - s * 0.24, x + s * 0.24, y + s * 0.24], outline=col + (140,), width=2)


TILE_COLS = {
    'fire': ((255, 122, 30), 'fire'),
    'bolt': ((90, 184, 255), 'bolt'),
    'drop': ((126, 200, 80), 'drop'),
    'vortex': ((160, 108, 232), 'vortex'),
    'gas': ((170, 220, 90), 'gas'),
    'radiation': ((220, 230, 90), 'radiation'),
    'funnel': ((200, 120, 255), 'funnel'),
    'sarcophagus': ((150, 130, 220), 'sarcophagus'),
    'electra': ((140, 225, 255), 'electra'),
}

TILE_ANOMALIES = ['fire', 'bolt', 'drop', 'vortex', 'gas', 'radiation']
TILE_SPECIAL = ['funnel', 'sarcophagus', 'electra']


# ---------------- глифы иконок 256 ----------------

def icon_plate(glyph_scene, accent):
    S = 256
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cut = 22
    pts = [(cut, 4), (S - cut, 4), (S - 4, cut), (S - 4, S - cut), (S - cut, S - 4),
           (cut, S - 4), (4, S - cut), (4, cut), (cut, 4)]
    d.polygon(pts, fill=(24, 27, 22, 246))
    d.line(pts, fill=accent + (255,), width=5)
    glyph_scene(d, img, S)
    a = np.array(img).astype(np.int16)
    n = np.random.default_rng(hash(glyph_scene.__name__) % (1 << 30)).integers(-3, 4, (S, S, 1))
    a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


# ---------------- виньетки ----------------

def shard_vignette():
    S = 256
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, 'RGBA')
    # осколок Зоны: светящийся кристалл-осколок
    pts = [(128, 26), (176, 96), (160, 196), (128, 232), (96, 196), (80, 96)]
    d.polygon(pts, fill=(70, 50, 110, 240), outline=(200, 160, 255, 255))
    d.polygon([(128, 26), (176, 96), (128, 196)], fill=(110, 80, 170, 255))
    d.polygon([(128, 26), (80, 96), (128, 196)], fill=(150, 110, 220, 255))
    d.line([(128, 26), (128, 232)], fill=(220, 190, 255, 160), width=2)
    glow = radial(256, (180, 140, 255), 110, 2.2)
    img.alpha_composite(glow)
    # искры
    r = random.Random(21)
    d = ImageDraw.Draw(img, 'RGBA')
    for _ in range(18):
        x, y = r.uniform(30, 226), r.uniform(30, 226)
        s = r.uniform(1, 3)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(220, 190, 255, r.randint(90, 200)))
    return img


def chest_vignette():
    S = 256
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, 'RGBA')
    # веха: сундук с золотом
    d.rounded_rectangle([52, 120, 204, 216], radius=14, fill=(64, 48, 30, 255), outline=(232, 179, 57, 255))
    d.rounded_rectangle([52, 88, 204, 132], radius=16, fill=(84, 64, 38, 255), outline=(232, 179, 57, 255))
    d.rectangle([116, 130, 140, 156], fill=(232, 179, 57, 255))
    d.ellipse([122, 136, 134, 150], fill=(40, 30, 12, 255))
    # золото из сундука
    r = random.Random(23)
    for _ in range(22):
        x, y = r.uniform(66, 190), r.uniform(140, 200)
        rr = r.uniform(4, 9)
        d.ellipse([x - rr, y - rr * 0.7, x + rr, y + rr * 0.7], fill=(255, 214, 110, r.randint(160, 250)),
                  outline=(120, 90, 20, 160))
    glow = radial(256, (255, 200, 90), 90, 2.3)
    img.alpha_composite(glow)
    return img


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    scenes = {
        'ev_zharva': (scene_zharva, (255, 170, 60)),
        'ev_uley': (scene_uley, (255, 90, 60)),
        'ev_labyrinth': (scene_labyrinth, (110, 170, 250)),
        'ev_chain': (scene_chain, (120, 210, 255)),
        'ev_vault': (scene_vault, (255, 200, 90)),
        'ev_bolts': (scene_bolts, (180, 130, 255)),
    }
    # баннеры
    for name, (scene, accent) in scenes.items():
        img = scene(random.Random(hash(name) % (1 << 30)))
        # зона под название слева: мягкое затемнение
        grad = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
        gd = ImageDraw.Draw(grad)
        for x in range(760):
            a = int(170 * (1 - x / 760) ** 1.2)
            gd.line([(760 - x, 0), (760 - x, BH)], fill=(8, 10, 6, a))
        img.alpha_composite(grad)
        img = vignette(img, 0.42)
        img = grain(img, 5, seed=hash(name) % (1 << 30))
        img.save(os.path.join(OUT, f'{name}.png'))
        print(name + '.png (баннер)')
    # иконки
    def g_zharva(d, img, S):
        tile(d, S / 2, S / 2 - 10, S * 0.62, TILE_COLS['fire'][0], 'fire')
        tile(d, S / 2 + S * 0.22, S / 2 + S * 0.24, S * 0.4, TILE_COLS['drop'][0], 'drop')

    def g_uley(d, img, S):
        d.polygon([(S / 2 - 70, S - 40), (S / 2 + 70, S - 40), (S / 2 + 50, S / 2 - 10), (S / 2 - 50, S / 2 - 10)],
                  fill=(24, 10, 10, 255))
        for dx in (-34, 34):
            d.ellipse([S / 2 + dx - 24, S / 2 - 78, S / 2 + dx + 24, S / 2 - 30],
                      fill=(28, 12, 12, 255), outline=(120, 30, 24, 255))
            d.ellipse([S / 2 + dx - 12, S / 2 - 66, S / 2 + dx - 2, S / 2 - 54], fill=(255, 70, 50, 255))
            d.ellipse([S / 2 + dx + 2, S / 2 - 66, S / 2 + dx + 12, S / 2 - 54], fill=(255, 70, 50, 255))

    def g_labyrinth(d, img, S):
        d.rectangle([40, 40, 90, S - 40], fill=(28, 40, 62, 255), outline=(60, 90, 130, 200))
        d.rectangle([S - 90, 40, S - 40, S - 40], fill=(28, 40, 62, 255), outline=(60, 90, 130, 200))
        d.rectangle([108, 40, S - 108, 96], fill=(28, 40, 62, 255), outline=(60, 90, 130, 200))
        tile(d, S / 2, S / 2 + 30, 120, (110, 170, 250), 'vortex')

    def g_chain(d, img, S):
        for dx, dy in ((-52, -34), (52, -34), (0, 44)):
            d.ellipse([S / 2 - 20 + dx, S / 2 - 20 + dy, S / 2 + 20 + dx, S / 2 + 20 + dy],
                      outline=(120, 210, 255, 230), width=4)
            d.ellipse([S / 2 - 10 + dx, S / 2 - 10 + dy, S / 2 + 10 + dx, S / 2 + 10 + dy],
                      fill=(160, 225, 255, 190))
        d.line([S / 2 + 12, S / 2 - 8, S / 2 + 44, S / 2 - 36], fill=(140, 220, 255, 200), width=3)
        d.line([S / 2 - 12, S / 2 + 30, S / 2 + 8, S / 2 + 44], fill=(140, 220, 255, 200), width=3)

    def g_vault(d, img, S):
        d.rounded_rectangle([52, 60, S - 52, S - 56], radius=24, fill=(44, 44, 48, 255),
                            outline=(120, 120, 128, 255), width=5)
        d.ellipse([S / 2 - 40, 120, S / 2 + 40, 200], fill=(30, 30, 34, 255),
                  outline=(200, 170, 80, 255), width=4)
        d.line([S / 2, 120, S / 2, 200], fill=(200, 170, 80, 160), width=2)
        d.line([S / 2 - 40, 160, S / 2 + 40, 160], fill=(200, 170, 80, 160), width=2)
        d.line([S / 2, 140, S / 2 + 18, 158], fill=(255, 214, 110, 255), width=4)

    def g_bolts(d, img, S):
        d.arc([30, 60, S - 30, S + 60], 200, 340, fill=(170, 120, 255, 220), width=6)
        d.arc([70, 110, S - 70, S + 110], 200, 340, fill=(140, 100, 220, 160), width=4)
        d.polygon([(S / 2 - 10, 92), (S / 2 + 10, 92), (S / 2, 66)], fill=(220, 190, 255, 230))

    icon_glyphs = {
        'ev_zharva': g_zharva, 'ev_uley': g_uley, 'ev_labyrinth': g_labyrinth,
        'ev_chain': g_chain, 'ev_vault': g_vault, 'ev_bolts': g_bolts,
    }
    accents = {n: a for n, (s_, a) in scenes.items()}
    for name, glyph in icon_glyphs.items():
        icon_plate(glyph, accents[name]).save(os.path.join(OUT, f'{name}_icon.png'))
        print(name + '_icon.png')
    # тайлы Жатвы 128
    for t in TILE_ANOMALIES + TILE_SPECIAL:
        col, glyph = TILE_COLS[t]
        img = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
        d = ImageDraw.Draw(img, 'RGBA')
        tile(d, 64, 64, 116, col, glyph)
        img = grain(img, 3, seed=hash(t) % (1 << 30))
        img.save(os.path.join(OUT, f'tile_{t}.png'))
        print('tile_' + t + '.png')
    # виньетки
    shard_vignette().save(os.path.join(OUT, 'shard_zone.png'))
    print('shard_zone.png')
    chest_vignette().save(os.path.join(OUT, 'milestone_chest.png'))
    print('milestone_chest.png')
    print('готово')
